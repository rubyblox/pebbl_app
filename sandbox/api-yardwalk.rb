
gem 'yard'
require 'yard'

module ApiDb

  ## see subsq: api-db.rb

  class YardWalk

    class << self

      def filename_contains?(basedir, other)
        ## assuming each path is an absolute filename, for purpose of brevity
        base_ary = (Array === basedir) ?
          basedir : basedir.split(File::SEPARATOR)
        other_ary = (Array === other) ?
          other : other.split(File::SEPARATOR)
        base_len = base_ary.length
        other_len = other_ary.length
        return (other_len >= base_len) && (base_ary == other_ary[...base_len])
      end


      def guess_top_features(spec)
        basedir = spec.full_gem_path
        include = spec.require_paths.map {
          |p| File.expand_path(p, basedir).split(File::SEPARATOR)
        }
        lib_files = Array.new
        spec.files.each do |f|
          path = File.expand_path(f, basedir)
          path_ary = path.split(File::SEPARATOR)
          catch(:found) do |tag|
            include.each do |inc_ary|
              if filename_contains?(inc_ary, path_ary)
                lib_files.push(path_ary)
                throw tag, inc_ary
              end
            end
          end
        end
        lib_files.sort! { |a, b| a.length <=> b.length }
        features = Array.new
        if (head = lib_files.first)
          maxlen = head.length
          catch(:map) do |tag|
            lib_files.each do |f_ary|
              if f_ary.length > maxlen
                throw tag, f_ary
              else
                features.push(f_ary.join(File::SEPARATOR))
              end
            end
          end
        end
        return features
      end ## guess_top_features


      def module_method(name, ns)
        ## a bit of a hack, used in traversal for module code objects
        ##
        ##
        ## This does not dispatch on visibility (public, protected, private)
        ## such that would have been addressed when each yardoc file was
        ## created
        ##
        if ns.instance_methods.include?(name) ||
            ns.protected_instance_methods.include?(name) ||
            ns.private_instance_methods.include?(name)
          ns.instance_method(name)
        elsif ns.singleton_methods.include?(name)
          ## FIXME not only a difference in where the method is stored ...
          ns.singleton_method(name)
        elsif ns.methods.include?(name) ||
            ns.protected_methods.include?(name) ||
            ns.private_methods.include?(name)
          ## reached sometimes
          ns.method(name)
        else
          $DEBUG ? -1 : false
        end
      end

      def traverse_gem(name, &block)
        spec = Gem::Specification.find_by_name(name)
        inst = new
        inst.traverse_spec(spec, &block)
        return inst
      end
    end ## class << self

    attr_reader :files_defs, :load_hist, :other_hist

    def initialize()
      ## FIXME at the cmd level, accept a repeatable "top features" option (filenames)
      ## then avoiding the call to guess_*

      @files_defs = {}
      @load_hist = []
      @other_hist = []
    end

    ## @param path [String] an absolute filename
    def load_once(path)
      if  ! (other_hist.include?(path) ||
             load_hist.include?(path) ||
             $LOADED_FEATURES.include?(path))
        if File.extname(path) == ".rb".freeze
          if File.basename(path).match(/mkmf/)
            ## - FIXME generalize to use a 'skip_files' match list
            ##   provided by some higher-order caller
            ## - designed for avoiding calls to the C compiler, as when
            ##   loading a mkmf file at runtime. The mkmf file might be
            ##   reached here if it provided a definition visible to yard.
            ## - this may need to check for more patterns than "mkmf"
            ## - this convention is known applicable with Ruby-GNOME gems,
            ##   presently untested with other extensions (debug gem, ...)
            ## - could be handled externally via a mapped block or method
            ## - needs testing with other gems defining extensions (e.g debug gem)
            ##
            STDERR.puts("[DEBUG] Not loading mkmf file #{path}") if $DEBUG
            other_hist << path
          else
            STDERR.puts("[DEBUG] Loading file #{path}") if $DEBUG
            load path
            load_hist << path
          end
        else
          STDERR.puts("[DEBUG] Not loading non-rb file #{path}") if $DEBUG
          other_hist << path
        end
      end ## ! loaded
    end ## load_once

    ## Add an object to the set of definitions recorded for a provided
    ## pathname
    ##
    ## @param obj [YARD::CodeObjects::Base] a YARD code object
    ## @param path [String] an absolute filename
    def add_def_file(obj, path)
      ## FIXME this will use absolute pathnames, but should use
      ## context-relative pathnames when possible, for classes of
      ## context:
      ## - gemspec
      ## - ... and other types of rdoc store (even though this is using yard)

      ##
      ## FIXME before passing to load_once, parse on obj.source, obj.source_type
      ##

      STDERR.puts("[DEBUG] adding definition file for #{obj.path} (#{obj.source_type}) => #{path}") if $DEBUG
      ## ^ obj.source_type => :ruby also for *.c files

      if ! (defs = files_defs[path])
        defs = (files_defs[path] = Array.new)
        load_once(path)
      end
      if ! defs.include?(obj)
        ## FIXME store this file => obj mapping in a groonga table,
        ## encoding the YARD code object (obj) in some way...
        defs.push(obj)
        load_once(path)
      end
    end


    ## @param spec [Gem::Specification]
    def traverse_spec(spec, &block)
      gem_name = spec.name

      ## FIXME some environments e.g submodules of Ruby-GNOME glib2
      ## may require that a call form is evaluated, in order for
      ## constants in that module to become available.
      ##
      ## This method accepts only one block, for yielding each
      ## currently-defined Ruby object and the original yardoc code
      ## object by which the Ruby object was located

      if (file = YARD::Registry.yardoc_file_for_gem(gem_name))
        YARD::Registry.load!(file)
      else
        Kernel.warn(
          "[DEBUG] No yardoc found for #{gem_name} @ #{spec.loaded_from}"
        ) if $DEBUG
        return false
      end

      ## activate the gem
      gem gem_name
      ## guess files to load for dynamic definitions
      lib_top = YardWalk.guess_top_features(spec)
      ## FIXME This should allow for a pre_load adapter for each project
      ## - gio2 e.g can just use 'require glib2'
      ## - glib2 defines some Ruby modules that are dynamically loaded
      ## - gtk3 can use 'Gtk.init' to expose more symbols via
      ##   gobject-introspection metadata,
      ##   ... or this can simply use direct analysis for
      ##   gobject-introspection metadata similar to the glib2 instance
      ##
      ### for now, analyze what was loaded from Ruby sources,
      ### starting at each module parsed by yard ... assuming
      ### that each module can be reached after loading the set
      ### of "feature libraries returned form guess_top_features
      lib_top.each do |f|
        load_once f
      end

      ## starting at the root, iterate on root.childen => typically modules
      ## - FIXME in caller, traverse the runtime definitions within the
      ##   namespace of each Ruby thing (class, module, constant, callable ...)
      ##    - caching each map of a YARD CodeObject to the
      ##      corresponding runtime object in the Ruby environment
      ##    - finally transforming each def to a YARD code object, addding to
      ##      some persistent file under the registry (if not
      ##      already defined in the registry)
      walk_root(YARD::Registry.root, spec, &block)
    end ## # traverse_spec

    ## @param root [YARD::CodeObjects::RootObject]
    ## @param spec [Gem::Specification]
    def walk_root(root, spec, &block)
      ## iterating without transformation on the RootObject
      root.children.each do |obj|
        walk_obj(obj, spec, &block)
      end
    end


    ## @param obj [YARD::CodeObjects::Base]
    ## @param spec [Gem::Specification]
    def walk_obj(obj, spec, root = Object, &block)
      basedir = spec.full_gem_path
      ## load any definition files for this object,
      ## before traversing downwards
      obj.files.each do |decl|
        ## decl[0]=> file pathname; decl[1] => file line number
        f = decl[0]
        path = File.expand_path(f, basedir)
        ## loading each file only once
        add_def_file(obj, path)
      end

      ## pass any existing ruby object to the block
      rb_obj = false
      begin
        case obj
        when YARD::CodeObjects::NamespaceObject, YARD::CodeObjects::ConstantObject
          # STDERR.puts("[DEBUG] const files: #{obj.files}") if $DEBUG
          ## ^ this can be reached for constants in YARD mapped to a C
          ## file in src. Albeit, the shared object file may not be
          ## visible outside of the src, given how Gem specs are defined...
          ##
          ## The C file would certainly be mapped to an external
          ## shared object file or statically linked, if the gem
          ## installation has succeeded
          ##
          if  root && root.const_defined?(obj.name)
            rb_obj = root.const_get(obj.name)
          end
          ## NB uninitialized constants found here ...
          ##
          ## e.g GLib::MetaInterface::FBIG ... GLib::Log::SEEK_CUR ...
          ##
          ## ... reached here by accident of yard's static
          ## parse for the C definition of those constants.
          ##
          ## Constants of a similar name are defined,
          ## though not under the module that Yard inferred
          ##
          ## Notwithstanding the scarcity of symbols avaialble from
          ## completion with rdoc RI in IRB, Yard's parse of the sources
          ## may be fairly comprehensive - those missing constants, the
          ## only "missing thing" discovered so far, under local testing
          ## with Ruby-GNOME and gobject-introspection
        when YARD::CodeObjects::MethodObject
          mtd = false
          ## TBD @ object mapping - singleton_class, etc

          ### if obj.is_alias?
          ## can handle in callback
          ### if obj.is_attribute?
          ## can handle in callback
          #### if obj.constructor?
          ## NB constructor is still accessible by method name
          ## i.e 'initialize' @ :instance scope, private visibility
          ### else
          mtd_name = obj.name.to_sym
          mtd = false
          if (obj.scope == :class)
            if root.methods.include?(mtd_name) ||
                root.protected_methods.include?(mtd_name) ||
                root.private_methods.include?(mtd_name)
              mtd = root.method(mtd_name)
            end
          elsif (Class === root)
            if root.instance_methods.include?(mtd_name) ||
                root.protected_instance_methods.include?(mtd_name) ||
                root.private_instance_methods.include?(mtd_name)
              mtd = root.instance_method(mtd_name)
            else
              mtd = $DEBUG ? -5 : false
            end
          else ## obj.scope == :module ... not ever used ??
            mtd = self.class.module_method(mtd_name, root)
          end
          rb_obj = mtd ## ?? may be false/nil
          if ! mtd
            STDERR.puts("[DEBUG] Method not found: %p [%s] in %p [%s]" % [
              mtd_name , obj.scope, root, root.class
            ]) if $DEBUG
          end
        when YARD::CodeObjects::ClassVariableObject
          ## using the current runtime value
          ##
          ## reached for some @@class_var when traversing the glib2 gem
          rb_obj = root.class_variable_get(obj.name)
        else
          Kernel.warn("FIXME not deserialized: #{obj.inspect}") if $DEBUG
        end
        block.yield(rb_obj, obj) if block_given?
      rescue NameError => e
        Kernel.warn(e) if $DEBUG
      end

      ## itreate for any yard namespace object
      if (YARD::CodeObjects::NamespaceObject === obj)
        obj.children.each do |chl_codeobj|
          walk_obj(chl_codeobj, spec, rb_obj, &block)
        end
      end
    end
  end

end

=begin TBD

YARD::Registry.all(:module) do |obj|
 ## ...
end

## ....
      #
      #   ## find all constants ... store in a table under DbStorage
      #   obj.files each do |f|
      #     add_def_file(obj, f)
      #     ## create any missing yardoc data for the dynamic API
      #     ## definitions located in this albeit trivial API walk
      #     ##
      #     ## ... and then, store the yardoc data in groonga tables
      #     ## (needs a consistent schema here)
      #     ##
      #     ## 1) Starting at the module, ensure that each object as
      #     ##    defined in that module has a corresponding YARD code
      #     ##    object. For each that does not, add a YARD code object
      #     ##    ... ensuring that the modified data is serialized back
      #     ##    to the filesystem, after each batch transaction.
      #     ##    See YARD::Registry.save
      #     ##
      #     ## 2) in some separate transaction, map the entire
      #     ##    YARD::Registry onto a Grroonga schema managed in this class
      #     ##    ... then available for prefix and full-text search via Groonga
      #
      #   end
      #   ## [...]
      # end
      #


(root = YARD::Registry.resolve(nil,nil)) == YARD::Registry.root

=end
