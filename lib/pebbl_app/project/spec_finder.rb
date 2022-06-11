
## ensure the module and autoloads are defined
require 'pebbl_app/project'

class PebblApp::Project::SpecFinder
  ## to implement a find_by_path that can actually find the gemspec for
  ## a file installed under some gemspec

  class << self

    ## return the first gem specification found within active
    ## gemspecs, for any gem providing the indicated file.
    ##
    ## **Known Limitations**
    ##
    ## This method operates on the list of files indexed in each gem
    ## specification's `files` list. If a gem was installed with any
    ## additional files not listed in that files list, this method will
    ## not be able to detect those additional files as being provided by
    ## the gem, even if installed under the gem's full path.
    ##
    ## @param file [String] a filename. If a relative filename, the
    ##        provided value will be expanded as a filename relative
    ##        to Dir.pwd at time of call
    ##
    ## @param deref [Boolean] If a truthy value, this method will
    ##        dereference symbolic links for the provided file and for
    ##        each file listed in each gemspec. If false (the default),
    ##        then symbolic links will not be dereferenced within this
    ##        method.
    ##
    ## @return [Gem::Specification, false] a gem specification, or
    ##         false if none is found
    ##
    def find_for_file(file, deref = false)
      f_st = deref ? File.stat(file) : File.lstat(file)
      f_dev = f_st.dev
      f_ino = f_st.ino
      Gem::Specification::latest_specs.map do |spec|
        dir = spec.full_gem_path
        spec.files.each do |f|
          p = File.expand_path(f, dir)
          if File.exists?(p)
            p_st = deref ? File.stat(p) : File.lstat(p)
            p_dev = p_st.dev
            p_ino = p_st.ino
            if (p_dev == f_dev) && (p_ino == f_ino)
              ## same file, dir, link, ... however reached for the
              ## pathname expansion within each initial filename
              return spec
            end
          else
            ## a file listed in a gemspec's files list does not exist
            ##
            ## This may not be actually uncommon
            ## for a spec file "ext/<name>/extconf.rb"
            Kernel.warn("File does not exist in #{spec.name} gemspec: #{f}",
                        uplevel: 1) if $DEBUG
          end
        end
      end
      return false
    end ## find_for_file

  end
end
