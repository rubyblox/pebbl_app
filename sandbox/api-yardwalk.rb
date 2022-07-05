
gem 'yard'
require 'yard'

module ApiDb

  ## see subsq: api-db.rb

  class YardWalk

    class << self
      def filename_contains?(basedir, other)
        ## assuming the paths are either both absolute or both relative
        ## filenames, for purpose of brevity
        base_ary = (Array === basedir) ?
          basedir : basedir.split(File::SEPARATOR)
        other_ary = (Array === other) ?
          other : other.split(File::SEPARATOR)
        base_len = base_ary.length
        other_len = other_ary.length
        if (other_len >= base_len) &&
            (base_ary == other_ary[...base_len])
          return other_ary[base_len...].join(File::SEPARATOR)
        end
      end

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

    end ## class << self

    attr_reader :context, :files_defs, :load_hist, :other_hist, :preload_binding

    def initialize()
      @files_defs ||= {}
      @load_hist ||= []
      @other_hist ||= []
      ## @context ||= Dir.pwd ## initialize only in each implementing class
    end

    def bind_preload(&block)
      @preload_binding = block
    end

    def call_preload(obj)
      if @preload_binding
        @preload_binding.call(obj)
      end
    end

    def expand_path(path)
      ## method not used in this class, overridden for gem traversal
      File.expand_path(path, @context)
    end

    def loaded?(path)
      other_hist.include?(path) ||
        load_hist.include?(path) ||
        $LOADED_FEATURES.include?(self.expand_path(path))
    end

    ## @param path [String] an absolute filename (FIXME should be relative-ok)
    def load_once(path)
      file = self.expand_path(path)
      if loaded?(path)
        STDERR.puts("Already loaded: #{path}") if $DEBUG
      else
        if File.extname(file) == ".rb".freeze ## FIXME move to #loadable?
          if File.basename(file).match(/mkmf/)
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
            STDERR.puts("[DEBUG] Not loading mkmf file #{file}") if $DEBUG
            other_hist << path
          else
            STDERR.puts("[DEBUG] Loading file #{file}") if $DEBUG
            load file
            load_hist << path
          end
        else
          STDERR.puts("[DEBUG] Not loading non-rb file #{file}") if $DEBUG
          other_hist << path
        end
      end ## ! loaded
    end ## load_once

    ## Add an object to the set of definitions recorded for a provided
    ## pathname
    ##
    ## @param obj [YARD::CodeObjects::Base] a YARD code object
    ## @param path [String] an absolute filename (FIXME or not)
    def add_def_file(obj, path)
      if ! (defs = files_defs[path])
        begin
          load_once(path)
        rescue
          Kernel.warn($!)
        end
        defs = (files_defs[path] = Array.new)
      end

      STDERR.puts("[DEBUG] adding definition file for #{obj.path} \
(#{obj.source_type}) => #{path}") if $DEBUG

      if ! defs.include?(obj)
        ## FIXME store this file => obj mapping in a groonga table,
        ## encoding the YARD code object (obj) in some way...
        defs.push(obj)
        # load_once(path)
      end
    end

    ## @param root [YARD::CodeObjects::RootObject]
    ## @param spec [Gem::Specification]
    def walk_root(root, &block)
      ## iterating without transformation on the RootObject
      root.children.each do |obj|
        call_preload(obj) ## sometimes reached for non-module code objects
        walk_obj(obj, Object, &block)
      end
    end

    ## @param obj [YARD::CodeObjects::Base]
    def walk_obj(obj, root = Object, &block)

      ## load any definition files for this object,
      ## before traversing downwards
      catch(:unparsed) do |tag|
        obj.files.each do |decl|
          ## decl[0]=> file pathname (relative); decl[1] => file line number
          f = decl[0]
          if f.match?(/mkmf/)
            ## FIXME apply any file exclusion patterns passed to the
            ## constructor/methods here, not hard-coding the exclusion
            ## patterns
            throw :unparsed
          else
            ## loading each file only once
            add_def_file(obj, f)
          end
        end

        ## pass any existing ruby object to the block
        rb_obj = false
        begin
          case obj
          when YARD::CodeObjects::NamespaceObject, YARD::CodeObjects::ConstantObject
            if  root && root.const_defined?(obj.name)
              rb_obj = root.const_get(obj.name)
            end
            ## NB uninitialized constants that would be found here ...
            ##
            ## e.g GLib::MetaInterface::FBIG ... GLib::Log::SEEK_CUR ...
            ##
            ## ... reached here by accident of yard's static
            ## parse for C definition of those constants.
            ##
            ## Constants of a similar name are defined,
            ## though not under the module that Yard inferred
            ##
          when YARD::CodeObjects::MethodObject
            mtd = false
            ### if obj.is_alias?
            ## can handle in callback
            ### if obj.is_attribute?
            ## can handle in callback
            #### if obj.constructor?
            ## NB constructor is still accessible by method name
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
            elsif root
              ## TBD obj.scope == :module is ever used in yard?
              mtd = self.class.module_method(mtd_name, root)
            else
              ## FIXME reached when trying to traverse definitions from gtk3/box.rb
              STDERR.puts("[DEBUG] Method ?? #{obj.path}") if $DEBUG
            end
            rb_obj = mtd ## ?? may be false/nil
            if ! mtd
              STDERR.puts("[DEBUG] Method not found: %p [%s] in %p [%s]" % [
                mtd_name , obj.scope, root, root.class
              ]) if $DEBUG
            end
          when YARD::CodeObjects::ClassVariableObject
            ## using the current runtime value, rather than the value
            ## stored in the yardoc data
            ##
            ## reached for some @@class_var when traversing glib2 e.g
            rb_obj = root.class_variable_get(obj.name)
          else
            Kernel.warn("FIXME not deserialized: #{obj.inspect}") if $DEBUG
          end
          block.yield(rb_obj, obj) if block_given?
        rescue NameError => e
          Kernel.warn(e) if $DEBUG
        end

        ## iterate for any yard namespace object
        if (YARD::CodeObjects::NamespaceObject === obj)
          obj.children.each do |chl_codeobj|
            walk_obj(chl_codeobj, rb_obj, &block)
          end
        end
      end ## catch(:unparsed)
    end ## walk_obj
  end

  class YardGemWalk < YardWalk

    class << self
      def traverse_gem(name, &block)
        spec = Gem::Specification.find_by_name(name)
        inst = new
        inst.traverse_spec(spec, &block)
        return inst
      end

    end ## class << YardGemWalk

    attr_accessor :feature_files

    attr_reader :name

    ## NB Gem::Specification === @context once the @context is initialized

    def initialize(name, feature_files: false)
      ## Gem::Specification === @context ## once located
      super()
      @name = name
      @feature_files = case feature_files
                       when String
                         [feature_files]
                       when Enumerable
                         feature_files
                       when NilClass
                         false
                       else
                         feature_files
                       end
    end

    def gemspec()
      @context ||= Gem::Specification.find_by_name(self.name)
    end


    def loadable?(path)
      ## FIXME also accept an exclude option and methods to add/remove
      ## exclude patterns, defaulting to use patterns like as follows
      if path.match?(/\.c$/) ||
          path.match?(/mkmf/) ||
          path.match?(/extconf/) ## might be used elsewhere
        return false
      else
        catch(:match) do |tag|
          ## FIXME even using relative paths, it's not resolving API
          ## quirks @ gtk3/box.rb and others - needs pre-load @ gobj
          self.gemspec.require_paths.each do |inc|
            if (req = YardWalk.filename_contains?(inc, path))
              throw(tag, req)
            end
          end
          ## return super(path)
        end
      end
    end

    def load_once(path)
      if (req = loadable?(path))
        if ! loaded?(req)
          STDERR.puts "[DEBUG] requiring #{req}" if $DEBUG
          require req
          load_hist << req
        else
          ## TBD ...
          super(path)
        end
      else
        STDERR.puts "[DEBUG] not loading #{path}" if $DEBUG
      end
    end

    def expand_path(path)
      File.expand_path(path, self.gemspec.full_gem_path)
    end

    ## @param spec [Gem::Specification]
    def traverse_spec(&block)
      gem_name = self.gemspec.name

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

      ## activate the gem and load any top-level feature files
      gem gem_name
      ## load files for any dynamic definitions, if provided earlier
      if feature_files
        feature_files.each do |f|
          STDERR.puts("[DEBUG] feature file: #{f}")
          ## using paths as provided, typically relative paths
          load_once f
        end
      end

      ## iterating from the registry root, for a single gem
      walk_root(YARD::Registry.root, &block)
    end ## # traverse_spec

  end

end ## ApiDb

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
