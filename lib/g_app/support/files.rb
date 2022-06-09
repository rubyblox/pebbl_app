
## define modules, autoloads
require 'g_app/support'

## Filesystem Support
module GApp::Support::Files

  class << self

    ## create all directories for a provided directory filename
    ##
    ## This method may raise a SystemCallError if some component of the
    ## filename cannot be created as a directory.
    ##
    ## Any directories created by this method will be assigned a
    ## filesystem permission mask compatible with the active umask in
    ## the current process.
    ##
    ## @param path [String, Pathname] the directory to create.
    ##
    ##        If provided as a relative filename, the filename will be
    ##        expanded relative to Dir.pwd
    ##
    ## @return [String] the directory created, as an absolute filename
    def mkdir_p(path)
      dirs = []
      lastdir = nil
      File.expand_path(path).split(File::SEPARATOR)[1..].each do |name|
        dirs << name
        lastdir = File::SEPARATOR + dirs.join(File::SEPARATOR)
        Dir.mkdir(lastdir) if ! File.directory?(lastdir)
      end
      return lastdir
    end
  end
end
