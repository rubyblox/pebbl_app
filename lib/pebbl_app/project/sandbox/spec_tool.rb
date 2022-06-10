## spec_tool.rb --- SpecTool and related class definitions (sandbox)

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory. The module may define autoloads that would be
  ## used in this file.
  require(__dir__ + ".rb")
}


require 'pathname'

module ThinkumSpace::Project::Sandbox

  class FileNotFound < RuntimeError
    attr_reader :pathname
    def initialize(pathname, message = "File not found: #{pathname}")
      super(message)
      @pathname = pathname
    end
  end

  class GemDataError < RuntimeError
    attr_reader :name
    def initialize(name: nil,
                   message:
                     ("Gem Data Error" + ( name ? " in #{name}" : "")))
      super(message)
      @name = name
    end
  end

  class GemQueryError < GemDataError
    def initialize(name: nil,
                   message:
                     ("Gem Query Error" + ( name ? " in #{name}" : "")))
      super(name: name, message: message)
    end
  end

  class GemSyntaxError < GemDataError
    attr_reader :pathname
    def initialize(name: nil,
                   message:
                     ("Gem Syntax Error" + ( name ? " in #{name}" : "")),
                   pathname: nil)
      super(name: name, message: message)
      @pathname = pathname
    end
  end


  class SpecTool

    ## synchronization for chdir in #load
    PWD_LOCK = Mutex.new

    ## synchrnoize onto Gem::Specification::LOAD_CACHE_MUTEX for the
    ## duration of the provided block.
    ##
    ## This method does not support recursive synchronization
    def self.synchronize_read(&block)
      Gem::Specification::LOAD_CACHE_MUTEX.synchronize do
        block.call
      end
    end

    ## return the value of *Gem::Specification::LOAD_CACHE*
    ##
    ## This method does not support recursive synchronization
    def self.gem_load_cache()
      self.synchronize_read do
        Gem::Specification.const_get(:LOAD_CACHE)
      end
    end


    ## Find all cached Gem Specification objects matching the provided
    ## specification name.
    ##
    ## This method does not support recursive synchronization
    def self.find_cached_gems(name)
      self.synchronize_read do
        self.gem_load_cache().values.find_all { |s| s.name == name }
      end
    end

    ## Find any cached Gem Specification matching the provided
    ## specification name.
    ##
    ## If more than one cached Gem Specification is found for the
    ## provided name, or if no Gem Specification is found for the
    ## provided name, an error of type *GemQueryError* will be raised.
    ##
    ## * Known Limitations *
    ##
    ## This method does not support gem version qualification.
    ##
    ## This method will err if more than one version of a named Gem is
    ## cached under *::Gem::Specification::LOAD_CACHE*
    ##
    ## This method does not support recursive synchronization
    ##
    ## @param name [String] Name for the Gem Specification
    ##
    ## @see #find_cached_gems
    def self.find_cached_gem(name)
      cached = self.find_cached_gems(name)
      count = cached.length
      if (count.eql?(1))
        return cached[0]
      elsif count.eql?(0)
        raise GemQueryError.new(message: "No cached gems found \
for name #{name}", name: name)
      else
        raise GemQueryError.new(message: "More than one cached gem \
found for name #{name}: #{cached}", name: name)
      end
    end


    ## Evaluate the contents of a gemspec file and return the last
    ## Gem specification defined in the file.
    ##
    ## This method differs from *Gem::Specification.load*, in at
    ## least the following features:
    ##
    ## - This method will evaluate and return a new Gem Specification
    ##   for the definition  in the specified file, on every invocation
    ##
    ## - This method will not store the evaluted Gem Specification,
    ##   outside of the return value.
    ##
    ## - If a block is provided to this method, the Gem
    ##   Specification source text will be evaluated with bindings
    ##   deriving from that block. The Gem Specification object
    ##   will be yielded to the block, once evaluated.
    ##
    ## - If the Gem Specification source text contains an error,
    ##   the error will propogated to the caller of this method,
    ##   rather than being intercepted for a warning message.
    ##
    ## - This method this will not # store the Gem Specification for
    ##  reuse within the Gem module
    ##
    ## Behaviors similar to *Gem::Specification.load*:
    ##
    ## - The Gem Specification source file will be assumed to be
    ##   accessible under a UTF-8 external encoding.
    ##
    ## - This method will set the *loaded_from* attribute on the
    ##   returned Gem Specification to the absolute pathname for the
    ##   provided +file+. The value of this attribute may differ in
    ##   comparision to the *spec_file* attribute, such that would
    ##   provide the Gem Specification path that will be used by e.g
    ##   the class method *Gem::Specification#find_by_name*
    ##
    ## - If the final top-level form in the file does not return a
    ##   Gem Specification, an error will be raised
    ##
    ## *Rationale*
    ##
    ## Regardless of whether the Gem Specification source file has
    ## been updated since the file was last evaluated under
    ## *Gem::Specification.load*, this method will return the Gem
    ## Specification as represented in the file at the time of method
    ## call.
    ##
    ## Notwisthanding any changes in file modification time under a file
    ## at a provided absolute pathname, the *Gem::Specification.load*
    ## method will continue to reuse any cached Gem Specification as
    ## originally represented in the file, subsequently reused
    ## throughout the duration of the Ruby process. This behavior may be
    ## suitable for most usage cases under a noninteractive programming
    ## environment.
    ##
    ## When editing a Gem Specification source file for simultaneous
    ## access from separate threads in  an interactive Ruby session, the
    ## behavior of reusing every cached Gem specification from
    ## *Gem::Specification.load* may serve to require that the
    ## interactive Ruby session be restarted after each Gem
    ## specification file update
    ##
    ## While the following method does not in itself address that
    ## limitation at the scale of a Ruby process, this method will allow
    ## for retrieving the current definition of a gemspec at the time of
    ## the method call.
    ##
    ## *Known Limitation: Not all shell commands supported*
    ##
    ## If a project produces a Gem specification using some shell
    ## command e.g git(1) such that the shell command may not produce an
    ## equivalent output under the Gem specification directory as
    ## installed, if absent of any resources in the original project
    ## directory, this mthod may not be able to produce a usable Gem
    ## specification from that Gem specification directory.
    ##
    ## In such instances, the project's original source code should be
    ## consulted when available.
    ##
    ## *Known Limitations: This method temporarily modifies PWD*
    ##
    ## For compatibility with Gem specification files using shell
    ## commands for operations on Gem specification data, this method
    ## will temporarily set the value of the calling process' current
    ## working directory to the Gem specifiation directory as
    ## installed. For purpose of thread-safe evaluation, the *PWD_LOCK*
    ## mutex will be acquired for the duration of this change in the
    ## process' current working directory.
    ##
    ## In applications, any other threads may operate to change the
    ## process' current working directory should synchronize on this
    ## *PWD_LOCK*.
    ##
    ## After either a normal exit or a nonlocal return of this method,
    ## the process' current working directory will be restored to that
    ## which was in use at the beginning of the critical section in this
    ## method. If any other thread has changed the current working
    ## directory within that duration, the change will be in effect lost
    ## upon exit from this method.
    ##
    ## *Known Limitation: No External Caching*
    ##
    ## This method does not use any of the following cache
    ## objects:
    ## - Gem::Specification::LOAD_CACHE (obsolete?)
    ## - @@stubs in Gem::Specification - as via Gem::Specification::stubs
    ## - @@all in Gem::Specification - as via Gem::Specification::_all
    ## - @@stubs_by_name in Gem::Specification, as via Gem::Specification::stubs_for(...)
    ## - Gem.loaded_specs, synchronizing on Gem::LOADED_SPECS_MUTEX,
    ##   and used e.g under Gem#activate
    ##
    def self.load(file, &block)
      usefile = File.expand_path(file)
      if File.exists?(usefile)
        text = File.read(usefile, external_encoding: "UTF-8")
        usebind = block_given? ? block.binding : binding
        lastpwd = Dir.pwd
        filedir=File.dirname(file)
        last = nil
        PWD_LOCK.synchronize {
          begin
            ## FIXME this pwd call is problematic, but will be necessary
            ## for evaluation of some Gem Specs, e.g for a yard gemspec
            ## using the 'find' shell command, to compute the set of
            ## spec files
            ##
            ## this has side effects on the calling process, though the
            ## original pwd should be restored on normal or abnormal return
            Dir.chdir(filedir)
            last = usebind.eval(text, usefile)
          ensure
            Dir.chdir(lastpwd)
          end
        }
        if last.is_a?(Gem::Specification)
          last.loaded_from = usefile
          ## ensure a correct value for #full_gem_path
          ## cf. pathname hacking in Gem::BasicSpecification
          last.full_gem_path=filedir
          yield last if block_given?
          return last
        else
          raise GemSyntaxError.new(message: "Evaluation of #{file} \
did not return a Gem Specification: #{last}", pathname: file)
        end
      else
        raise FileNotFound.new(usefile)
      end
    end

    ## Utility method
    def self.find_gem_spec(name)
      ## FIXME add an optional version arg
      ## TBD add optional search-patch args
      ##
      ## FIXME resume calling #load once a method is defined here for
      ## configuring the load path for a provided gemspec and all
      ## gemspecs on which the gemspec depends
      s = Gem::Specification::find_by_name(name)
      return s
    end


    ## utility method
    def self.to_gem(gem)
      case gem
      when Gem::Specification
        gem
      when String
        find_gem_spec(gem)
      when Symbol
        find_gem_spec(gem.to_s)
      else
        raise ( "Unrecognized gem specifier %S" % [ gem ])
      end
    end

    def self.gem_base_directory(gem)
      ## NB in applications: not every gemspec will have installed a
      ## <name>.gemspec file under the spec.full_gem_path
      ##
      ## e.g
      ## rblib vendor/bundle/ruby/3.1/gems/native-package-installer-1.1.4/
      ## contains no *.gemspec file
      ## to which, note the file
      ## rblib vendor/bundle/ruby/3.1/specifications/native-package-installer-1.1.4.gemspec
      ## accessible with
      ## Gem::Specification.find_by_name("native-package-installer").spec_file
      spec = to_gem(gem)
      return Pathname(spec.full_gem_path)
    end

    ## utility method for editor applications
    ##
    ## e.g
    ## using = ThinkumSpace::Project::Ruby
    ## s_gtk = using::SpecTool.gemspec_source_file('gtk3')
    ## s_npt = using::SpecTool.gemspec_source_file("native-package-installer")
    ##
    ## e.g with shell, using bundle-exec(1) in the rblib project source directory
    ## $EDITOR $(bundle exec ruby -I lib -r 'thinkum_space/project/ruby/spectool' -e 'puts ThinkumSpace::Project::Ruby::SpecTool.gemspec_source_file("gtk3")')
    ##
    ## FIXME needs a binscript e.g as 'project edit gem' for a project(1) cmd
    def self.gemspec_source_file(gem)
      spec = to_gem(gem)
      gempath = spec.full_gem_path
      ## NB this assumes a certain convention in gemspec source naming
      srcname = spec.name + '.gemspec'
      srcpath = File.join(gempath, srcname)
      if File.exists?(srcpath)
        return srcpath
      else
        ## FIXME this quiet difference in the semantics of the return
        ## value should be noted in the return value itself, or
        ## reflected in some alternate approach for accessing the
        ## gemspec source (e.g browse the spec.full_gem_path dir in such case)
        return spec.spec_file
      end
    end


    ## Return the set of library files for a Gem Specification object,
    ## such that each library file is accessible under one or more of
    ## the require paths for the object.
    ##
    ## This method will normally return an array of absolute pathnames.
    ##
    ## If the *loaded_from* attribute of the Spec is +nil+, this method
    ## will return the array of +spec.files+ without duplication or
    ## modification. In such a case, the return value may represent an
    ## array of relative pathnames. FIXME this method should probably err,
    ## under such case.
    def self.spec_lib_files(spec)
      ##
      ## NB used in the latest ./gemdocs.rb
      ##
      if (from = spec.loaded_from)
        specdir = File.dirname(from)
      end
      files=spec.files
      ## NB assumption: all files in the 'files' list are
      ## relative pathnames, whose base pathname is provided
      ## in the spec.loaded_from path
      if specdir.nil?
        ## no base directory for the pathnames
        ## FIXME/TBD could warn() here - loaded_from would have been nil
        return files
      else
        ## NB using expand_path here, this should serve to ensure that
        ## any relative pathname elements e.g a directory name "."
        ## will be interpolated in the pathnames, before any filenames
        ## will be tested for a glob match
        req_globs=spec.require_paths.map { |p|
          glob = File.join(p, "*")
          File.expand_path(glob, specdir)
        }
        return files.filter_map { |f|
          abs = File.expand_path(f, specdir)
          abs if req_globs.find { |g| File.fnmatch(g, abs) }
          }
      end
    end
  end
end
