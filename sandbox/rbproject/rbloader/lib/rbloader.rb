
## FIXME see also autload
## cf. https://learning.oreilly.com/library/view/metaprogramming-ruby-2/9781941222751/f_0066.xhtml#d24e24696

module Utils ## FIXME move to the rbloader gem

  ## FIXME this needs to be developed in a separate bundle
  ## - TBD where
  ##   - Usage case: Editor support - iruby [gem pkg, see also: ports, pkgsrc]
  ## - Subsq TBD, "What more ..."
  ##   - Bundler console && iruby
  ##     - requires an API for Emacs-like eval, essentially IPC
  ##     - refer to `iruby-completions' +> process filter support
  ##     - i.e iruby-ipc-send (expr &optional proc)
  ##       - to be accomp. with a separate library, iruby-ipc
  ##         && eieio classes for the effective IDL
  ##   - Gen'l package management for Gem-based projects


  ## Utility class for *RbLoader::load!*
  class FileInfo
    attr_reader :pathname
    attr_accessor :mtime

    def initialize(pathname, mtime = File.mtime(pathname))
      @pathname = pathname
      @mtime = mtime
    end
  end

  ## Context class for *RbLoader::load!* orchestration
  class RbLoader

    ## FIXME scan across $LOAD_PATH when provided with a relative file
    ## name, furthermore using the ruby suffix global (locally defined)

    ## FIXME the following two class variables are not used in any
    ## thread-safe manner. This class also needs a mutex for locking
    ## both

    ## Array of *FileInfo* objects, each recording a file pathname and
    ## the file's last modified time at the instance of last *::load!*
    ## @see ::load!
    ## @fixme may not be compatible with +freeze()+
    ## @fixme reimplement with access via class method
    LOAD_HIST = []

    ## Array of pathname strings, used to prevent recursive load
    ## under *::load!*
    ##
    ## @see ::load!
    ## @fixme may not be compatible with +freeze()+
    ## @fixme reimplement with access via class method
    LOAD_STACK = []

    ## *Mutex* for ensuring thread-safe access to *LOAD_HIST* and
    ## *LOAD_STACK* under *::load!*
    ##
    ## @fixme should be compatible with +freeze()+ (needs testing)
    LOAD_LOCK = Mutex.new()

    ## see also (ruby core)
    ## $LOADED_FEATURES
    ## $LOAD_PATH

    ## intiial value for +$SEARCH_SUFFIX_RUBY+
    ##
    ## This value will be used to initialize +$SEARCH_SUFFIX_RUBY+
    ## within *load!*. If no such global variable was previously
    ## defined, +$SEARCH_SUFFIX_RUBY+ will be set to a copy of this
    ## value
    ##
    ## @see #load!
    ## @fixme move this into to a BEGIN block in the source file
    RUBY_DEFAULT_SEARCH_SUFFIX= %w{.rb}

    ## @param name [String]
    ## @param whence [String or nil]
    ## @return string or nil
    def self.resolve_library_path(name,whence = nil)
      if whence
        exp = File.expand_path(name, whence)
        if File.exists?(exp)
          return exp
        else
          sfxp = false
          $SEARCH_SUFFIX_RUBY.any? do |sfx|
            sfxp = exp + sfx
            File.exists?(sfxp)
          end
          return sfxp
        end
      else
        ## first, search PWD
        exp = self.resolve_library_path(name, Dir.pwd)
        ## then, search LOAD_PATH
        exp || $LOAD_PATH.any? do |p|
          exp = self.resolve_library_path(name,p)
        end
        return exp
      end
    end

    ## Trivial operation onto **Gem::default_path*
    ##
    ## @note This method may be removed in a subsequent revision
    def self.gem_src?(name)
      ## FIXME/TBD Remove (earlier prototype)
      dir = File.dirname(File.absolute_path(name))
      rslt = false
      Gem::default_path.each do |gempath|
        dir.match('^' + gempath) && rslt = gempath
      end
      return rslt
    end


    ## conditional *load* for Ruby source files,
    ## with a semantics similar to *require*
    ##
    ## *load!* provides the following features,
    ## as principally extensional to the call
    ## semantics of *Kernel#require*,
    ##
    ## 1) File modification time will be recorded,
    ##    such as to ensure that that a file that
    ##    has been modified since previous *load!*
    ##    will be loaded again
    ##
    ## 2) a configurable source file suffix list,
    ##    in $SEARCH_SUFFIX_RUBY
    ##
    ##
    ## Similar to *Kernel#require*, this method uses
    ## a load history, here providing storage for
    ## physical file pathnames - vis *File#realpath* -
    ## and file modification time.
    ##
    ## @note This method implements thread-safe access
    ## to *LOAD_HIST*
    ##
    ## @param name [String] The pathname of the
    ##  file to load. This may be provided as a file name
    ##  with or without directory. Similar to +require+, the file name
    ##  suffix may also be ommitted. However, in this instance, the file
    ##  name suffix - if ommitted - must be equivalent to some value in
    ##  +$SEARCH_SUFFIX)_LIST+
    ##
    ## @param wrap [boolean] +wrap+ parameter provided to
    ##  *Kernel.load+
    ##
    ## @param timeout [unsigned integer] Number of seconds to wait
    ##  when acquiring the *LOAD_LOCK*.
    ##
    ##  If *load!* has been called in some other thread, the
    ##  +timeout+ value provided in this thread should be greater
    ##  than the number of seconds required up to normal return
    ##  or non-local throw for the *load~* call in the earlier
    ##  thread
    ##
    ## @see #resolve_library_path
    ## @see $SEARCH_SUFFIX_RUBY
    ## @see RUBY_DEFAULT_SEARCH_SUFFIX
    ## @see LOAD_HIST
    ## @todo This method does not support hooks for
    ##   +Bundler::require+. See also {gemfile(5)}[https://manpages.debian.org/testing/ruby-bundler/gemfile.5.en.html]
    ## @fixme move the $SEARCH_SUFFIX_RUBY initializer into a BEGIN
    ## block in the source file
    def self.load!(name, wrap = false,
                   timeout = 5)

      if !defined?($SEARCH_SUFFIX_RUBY)
        $SEARCH_SUFFIX_RUBY= RUBY_DEFAULT_SEARCH_SUFFIX.dup
      end

      abs = self.resolve_library_path(name)

      if LOAD_STACK.any?(abs)
        raise ("Recursive load: #{abs}")
      else
        ## ensure that the file is loaded if not previously loaded
        ## or if updated since last load
        ##
        ## FIXME Ruby Mutex.* forms do not not accept a timoeut
        ##
        ## so ... condition variables
        ##
        if LOAD_LOCK.owned?
          self.load2(abs, wrap)
          caller_locked = true
        else
          Timeout::timeout(timeout) {
            LOAD_LOCK.lock
          }
          self.load2(abs, wrap)
          caller_locked = false
        end
      end
    ensure
      ## FIXME not atomic. In this API, absent of a timeout option in
      ## the Mutex.lock-like stage of Mutex.synchronize, this may not be
      ## able to callMutex.synchronize above. Wrapping the entire lock
      ## acquisition and source load section in a timer would not be OK
      ##
      ## see e.g
      ## https://pubs.opengroup.org/onlinepubs/007904875/functions/pthread_mutex_timedlock.html
      caller_locked || LOAD_LOCK.unlock
    end

    protected

    def self.load2(path, wrap)
      ## NB path is assumed to represent an absolute pathname
      ## of a physical file (not symbolic link)
      ##
      ## FIXME may not be thread-safe
      ## - may need to lock a mutex onto LOAD_HIST && pass no-lock to subsq calls...

      LOAD_STACK.push(path)

      ## ^ NB doing this always, if 'ensure' forms cannot be
      ## nested below method top-level

      mtime_f = File.mtime(path)
      found = false
      newer = true

      LOAD_HIST.any? do |finfo|
        if (finfo.pathname == path)
          found = finfo
          newer = ( mtime_f > finfo.mtime )
          break
        end
      end

      if newer
        Kernel.class.send(:load, path, wrap)
        return true
      else
        return false
      end

    ensure
      LOAD_STACK.delete(path)
      if found
          found.mtime = mtime_f
       else
          found = FileInfo.new(path,mtime_f)
          LOAD_HIST.push(found)
       end
    end

  end ## ZMulti::RBtools::RbLoader

end ## ZMulti::RBUtils
