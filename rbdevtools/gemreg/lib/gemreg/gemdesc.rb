## gemreg.rb - Ruby Gem registry service

## see ../bin/gemreg
##
## and ./gemdocs.rb, ./spectool.rb

require 'rubygems'

##
## @fixme This module may seem redundant onto Gem::Specification::all()
module GemReg

  ## Local container for file metadata
  ##
  ## *Known Limitations*
  ##
  ## This class does not allow for an *mtime* to provided
  ## external to the filesystem.
  class FileDesc

    ## default file modified time to store for any *FileDesc*
    ## having a *pathname* that does not match any known file
    ##
    ## @see #mtime
    ## @see #fs_mtime
    ## @see #updated?
    ## @see #update_mtime
    MTIME_UNAVAILABLE = Time.new(-1)

    ## absolute pathname of the file for this *FileDesc*
    ##
    ## @return [String] the pathname for the file
    attr_reader :pathname

    ## The most recent last modified time stored for the file
    ##
    ## If no file is found at the pathname for this *FileDesc*,
    ## then this value should contain a *Time* with a year -1,
    ## generally equivalent to +MTIME_UNAVAILABLE+
    ##
    ## @return [Time] the last modified time, as stored locally
    ##
    ## @see #fs_mtime
    ## @see #updated?
    ## @see #update_mtime
    attr_reader :mtime

    ## create a new *FileDesc*, using the provided +pathname+
    ##
    ## If +no_update+ is not _true_, then this constructor will
    ## call +#update_mtime+ to store the last modified time for
    ## the file - assuming the file exists. If +no_update+ is
    ## true, then the calling application should call
    ## *update_mtime* sometime after this constructor method has
    ## returned.
    ##
    ## @see #pathname
    ## @see #mtime
    ## @see #fs_mtime
    ## @see #updated?
    ## @see #update_mtime
    ##
    ## @param pathname [String] The file's name. When stored, an
    ##  absolute pathname will be used, such that any relative
    ##  pathname provided in the constructor's +pathname+
    ##  parameter will be expanded as relative to +dir+
    ##
    ## @param dir [String] Default base directory, used for
    ##  relative pathname expansion when storing the +pathname+.
    ##
    ##  Applications creating multiple *FileDesc* objects within
    ##  one directory may use a common +dir+, across each call to
    ##  this constructor.
    ##
    ## @param no_update [boolean] If true, no last modified time
    ##  will be stored for the file, within this constructor. If
    ##  false (the default), the file's last modified time - when
    ##  available - will be stored via *update_mtime*
    ##
    def initialize(pathname, dir: Dir.pwd, no_update: false)
      @pathname = File.expand_path(pathname)
      if no_update
        @mtime = MTIME_UNAVAILABLE
      else
        update_mtime()
      end
    end

    ## return the last modified time for the file. as determined
    ## from the host filesystem.
    ##
    ## If no file is found for the *pathname* of this *FileDesc*,
    ## this method will return the value of +MTIME_UNAVAILABLE+
    ##
    ## @return [Time] a *Time* object representing the file's
    ##  last modified time, as determined from the host
    ##  filesystem
    ##
    ## @see #updated?
    ## @see #update_mtime
    def fs_mtime()
      if File.exists?(pathname)
        return File.mtime(@pathname)
      else
        return MTIME_UNAVAILABLE
      end
    end

    ## return a boolean value indicating whether the file
    ## described by this *FileDesc* has been updated since any
    ## previous *mtime* change
    ##
    ## If the *mtime* for this *FileDesc* is equal to
    ## +MTIME_UNAVAILABLE+, this method will return the value
    ## +nil+. Otherwise, this method will return a boolean +true+
    ## or +false+ value indicating whether the stored *mtime* for
    ## this *FileDesc* differs from the file's last modified time
    ## on the host filesystem.
    ##
    ## @return [boolean] the logical flag value
    ##
    ## @see #fs_mtime
    ## @see #update_mtime
    def updated?()
      if ( @mtime == MTIME_UNAVAILABLE )
        return nil
      else
        return ( fs_mtime() != @mtime )
      end
    end

    ## ensure that the *mtime* for this *FileDesc* will match the
    ## last modified time for the *pathname* of this *FileDesc*,
    ## at the time when this method is evaluated.
    ##
    ## If no file exists at the *pathname* for this *FileDesc*,
    ## then the value of +MTIME_UNAVAILABLE+ will be stored as
    ## the *mtime* for this *FileDesc*
    ##
    ## @return [Time|boolean] the last modified time for the
    ##  file, or +false+ if the last modified time stored for the
    ##  file is equivalent to that on the host filesystem
    ##
    ## @see #updated?
    ## @see #fs_mtime
    def update_mtime()
      if File.exists?(pathname)
        time = fs_mtime()
        if (time != @mtime)
          @mtime=time
        end
      else
        @mtime=MTIME_UNAVAILALBE
      end
    end
  end ## GemReg::FileDesc


  class GemDesc < FileDesc

    ## return the pathname for a named gemspec, or null
    def self.find_spec_paths(name, *versions)
      ## FIXME $LOAD_PATH DNW here.
      ##
      ## NB $LOAD_PATH is typically modified under 'require',
      ## as when a gemspec adds new elements to $LOAD_PATH
      ##
      ## TBD how is data initialized for Gem::Specification::dirs() ?
      ## - TBD/NB Gem::GemRunner
      ##   - used in rubysrc:bin/gem
      ##   - NB rubysrc:lib/rubygems/gem_runner.rb
      ## - NB rubysrc:lib/rubygems/*.rb
      ## - NB rubysrc:lib/rubygems/specification.rb
      ## => values in ::Gem.path with a 'specifications' subdir
      ##    suffixed on each element
      ##    - in which 'Gem' is a module
      ##    - ... defined in rubysrc:lib/rubygems.rb
      ##    - onto Gem::PathSupport.new(ENV...)
      ##      - defined in rubysrc:lib/rubygems/path_support.rb
      ##      - using environment variable GEM_HOME (when defined)
      ##        - default e.g /usr/lib/ruby/gems/3.0.0
      ##           - via ::Gem.default_dir
      ##        - such that default_dir is set in
      ##        rubysrc:lib/rubygems/defaults.rb
      ##        as generally based on <rubylibprefix>/gems/<ruby_version>
      ##        for <constants> via the RbConfig::CONFIG Hash
      ##
      ## NB as to how how /usr/lib/ruby/gems/3.0.0/specifications/
      ## is  computed as a path : see previous
      ##
      ##
      ## ** NB ~/.local/share/gem/ruby/3.0.0/doc/ **
      ##
      # $LOAD_PATH.find{ |p|
      #   ##
      # }
      rtn=[]
      ::Gem::Specification.dirs.each do |p|

      end
    end
  end

end

## Local Variables:
## fill-column: 65
## End:
