## GemReg spectool.rb

module GemReg

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
                   message: "Gem Data Error#{" in #{name}" if name}")
      super(message)
      @name = name
    end
  end

  class GemQueryError < GemDataError
    def initialize(name: nil,
                   message: "Gem Query Error#{" in #{name}" if name}")
      super(message, name: name)
    end
  end

  class GemSyntaxError < GemDataError
    attr_reader :pathname
    def initialize(name: nil,
                   message: "Gem Syntax Error#{" in #{name}" if name}",
                   pathname: nil)
      super(message, name: name)
      @pathname = pathname
    end
  end


  class SpecTool

    PWD_LOCK = Mutex.new

    ## return the value of *Gem::Specification::LOAD_CACHE*
    ##
    ## In any multi-threaded applications, methods operating on this
    ## return value should sychronize on the *Mutex*
    ## +Gem::Specification::LOAD_CACHE_MUTEX+ for the duration of any
    ## read or write operations on the return value.
    ##
    ## @see #find_cached_gems
    ## @see #find_cached_gem
    ## @see ::Gem::Specification::LOAD_CACHE_MUTEX
    def self.gem_load_cache()
      Gem::Specification::LOAD_CACHE_MUTEX.synchronize {
        Gem::Specification.const_get(:LOAD_CACHE)
      }
    end


    ## Find all cached Gem Specification objects matching the provided
    ## specification name.
    ##
    ## In any multi-threaded applications, methods operating on this
    ## return value should sychronize on the *Mutex*
    ## +Gem::Specification::LOAD_CACHE_MUTEX+ for the duration of any
    ## read or write operations on the return value.
    ##
    ## @see #find_cached_gem
    ## @see ::Gem::Specification::LOAD_CACHE_MUTEX
    def self.find_cached_gems(name)
      Gem::Specification::LOAD_CACHE_MUTEX.synchronize {
        self.gem_load_cache().values.find_all { |s| s.name == name }
      }
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
    ## This method will err if  more than one version of a named Gem is
    ## cached under *::Gem::Specification::LOAD_CACHE*
    ##
    ## @param name [String] Name for the Gem Specification
    ##
    ## @see #find_cached_gems
    def self.find_cached_gem(name)
      cached = self.find_cached_gems(name)
      count = cached.length
      if (count == 1)
        return cached[0]
      elsif count.zero?
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
    ## - This method will evaluate and return the Gem
    ##   Specification defined in the specified file, on every
    ##   call to the method.
    ##
    ## - This method will not perform any _untaint_ calls on the
    ##   evaluated Gem Specification.
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
    ## As one limitation to the following method, this will not
    ## store the Gem Specification for reuse with the Gem module
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
    ## access via an interactive Ruby session, the behavior of reusing
    ## every cached Gem specification from *Gem::Specification.load*
    ## would serve to require that the interactive Ruby session be
    ## restarted after each Gem specification file update.
    ##
    ## Thus, the following method will evaluate the original gem
    ## specification on every call to the method.
    ##
    ## *Known Limitations: This method temporarily modifies PWD*
    ##
    ## In order to ensure proper evaluation of Gem Specification
    ## distribution files, this method will temporarily set the value of
    ## the calling process' current working directory to the directory
    ## containing the provided Spec file. For purpose of thread-safe
    ## evaluation, the *PWD_LOCK* mutex will be acquired for the
    ## duration of this change in the process' current working
    ## directory.
    ##
    ## After either a normal exit or a nonlocal return of this method,
    ## the process' current working directory will be changed again, to
    ## that which was in use at the beginning of the critical section
    ## in this method.
    ##
    ## As such, in any multi-threaded program, this method should not be
    ## used simultaneous to any other methods relying on the value of
    ## *Dir.pwd*, within the same process - unless e.g those methods are
    ## also synchronized on the *PWD_LOCK* used here, or if this method
    ## will be executed under a fork, and thus under a separate process
    ## environment.
    ##
    ## *Known Limitation: No Internal Caching*
    ##
    ## The following method could be updated to perform some caching,
    ## such as based on the file's absolute pathname and the file's last
    ## modified time. For any Gem Specification that was not updated
    ## since last load, the only subsequent I/O that would need be
    ## performed would be to access the file's metadata, as to retrieve
    ## the file's last motified time. For any updated Gem Specification,
    ## the latest form could be evaluated and returned as usual.
    ##
    ## Similar to *Gem::Specification*, for purpose of thread-safe
    ## caching, that update would serve to require the creation of an
    ## additional Mutex object. That Mutex would be used for
    ## synchronizing any thread-safe access to the cache table.
    ##
    ## *Known Limitation: No External Caching*
    ##
    ## This method does not use any of the following cache
    ## objects:
    ## - Gem::Specification::LOAD_CACHE
    ## - @@stubs in Gem::Specification - as via Gem::Specification::stubs
    ## - @@all [array] in Gem::Specification - as via Gem::Specification::_all
    ## - whatever cache is being used by Gem::Specification::find_by_name(...)
    ## - @@stubs_by_name in Gem::Specification, as via Gem::Specification::stubs_for(...)
    ## - See also: Gem::Specifications::all= (not useful for activated gems)
    ## - Gem.loaded_specs, synchronizing on Gem::LOADED_SPECS_MUTEX,
    ##   and used under Gem#activate (NB do not access, for this)
    ##
    def self.load(file, &block)
      usefile = File.expand_path(file)
      if File.exists?(usefile)
        text = File.read(usefile, external_encoding: "UTF-8")
        usebind = block_given? ? block.binding : binding
        lastpwd = Dir.pwd
        last = nil
        PWD_LOCK.synchronize {
          begin
            ## FIXME this pwd call is problematic, but will be necessary
            ## for evaluation of some Gem Specs, e.g for yard - such
            ## that uses 'find' to compute the set of spec files
            pwd=Dir.pwd
            Dir.chdir(File.dirname(file))
            last = usebind.eval(text, usefile)
          ensure
            Dir.chdir(pwd)
          end
        }
        if last.is_a?(Gem::Specification)
          last.loaded_from = usefile
          yield last if block_given?
          return last
        else
          raise GemSyntaxError.new(message: "Evaluation of #{file} \
did not return a Gem Specification: #{last}",
                                   pathname: file)
        end
      else
        raise FileNotFound.new(usefile)
      end
    end


    ## load and return a Gem Specification from any cached specification's
    ## full gem path
    ##
    ## If a block is provided, that block will be be used for providing
    ## a binding for gemspec evaluation, in the internal call to the
    ## overriding *#load* method. The block will then be called with the
    ## initialized Gem Specification object as its only argument.
    ##
    ## If no Gem Specification for the provided name can be located under
    ## the initialized Gem Home and Gem Paths, an error of type
    ## Gem::MissingSpecError will be raised.
    ##
    ## Given the provided +<name>+, if a file +<name>.gemspec+ does not
    ## exist under the cached specification's +#full_gem_path+ then an
    ## error will be raised.
    ##
    ## *Known Limitations*
    ##
    ## This method shares any limitations of the overriding *load*
    ## method.
    ##
    ## This method will not cache the returned Gem Specification for any
    ## access within the Gem module.
    ##
    ## Any specification returned by this method will not be updated
    ## when the specification used by the Gem module is activated.
    ##
    ## *Known Limitations*
    ##
    ## *FIXME* This method returns a spec with a spurious files list,
    ## when used to retrieve the 'yard' gem - presumably due to the
    ## value of 'pwd' when the Gem Specification is evaluated
    ##
    ## *Rationale*
    ##
    ## For some Gem Specification definitions, the Gem Specification
    ## object loaded from the *spec_file* may differ from that loaded from
    ## the +<name>.gemspec+ file under the specification's *full_gem_path*.
    ## This issue is apparent with at least the +rdoc+ gem, version 6.3.1
    ## installed from Arch Linux, under Ruby 3.0.0. The Gem Specification
    ## provided in the *spec_file* for this gem does not identify any
    ## +'*.rb'+ files, while the Gem Specification - of the same name
    ## and version - as accessed under the gem's *full_gem_path* will
    ## provide a complete Gem Specification, including Ruby source
    ## files.
    ##
    ## As such, the Gem Specification returned by this method may differ
    ## from that returned from Gem query methods, such as
    ## *Gem::Specification::find_by_name(name)*.
    ##
    ## To the best estimation of the author of this method, the Gem
    ## Specifications returned by this method may represent a manner of
    ## _Gem Specification for distribution_, whreas the Gem
    ## specification returned by such a method in the *Gem* module may
    ## represent a _Gem Specification for runtime_.
    ##
    ## @see #load
    def self.find_gem_spec(name, &block)
      s = Gem::Specification::find_by_name(name)
      gempath = s.full_gem_path
      fullpath = File.expand_path(name + ".gemspec",gempath)
      if File.exists?(fullpath)
        fullspec  = self.load(fullpath, &block)
        return fullspec
      else
        raise FileNotFound.new(fullspec, "No gemspec found \
for name #{name} under #{gempath}")
      end
    end
  end
end
