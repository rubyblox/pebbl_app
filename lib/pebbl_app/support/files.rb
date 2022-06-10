
## define modules, autoloads
require 'pebbl_app/support'

require 'tempfile'

## Filesystem Support
module PebblApp::Support::Files

  class << self

    ## create a temporary File.
    ##
    ## If a string name is provided, this will be used as a filename
    ## suffix for the temporary file.
    ##
    ## If a block is provided, the temporary File will be yielded to the
    ## block and the file will be unlinked after exit from the
    ## block. The return value from the block will then provide the
    ## return value from this method.
    ##
    ## If a block is not provided, a new File object will be returned
    ## for the temporary file.
    ##
    ## Similar to Dir.mktmpdir, if a TMPDIR is provided in ENV then this
    ## TMPDIR must denote an existing directory. This directory will
    ## be used as a default base directory for the temporary file.
    ##
    ## If no TMPDIR is provided in ENV then this will use Ruby defaults
    ## for the running operating system to determine the root directory
    ## for the temporary file.
    ##
    ## @param name [String, nil] prefix for the temporary filename, if a
    ##        string
    ##
    ## @see File#close_on_exec=
    ##
    def mktmp(name = nil, &block)
      if name
        f = Tempfile.new(name)
      else
        f = Tempfile.new
      end
      if block_given?
        begin
          block.yield(f)
        ensure
          f.close
          f.unlink
        end
      else
        return f
      end
    end

    ## create a temporary directory
    ##
    ## If a string arg is provided, this will be used as the first arg
    ## for Dir.mktmpdir
    ##
    ## If a block is provided, the temporary directory will be yielded
    ## to the block as a string, and the directory will be unlinked
    ## after exit from the block. The return value from the block will
    ## then provide the return value from this method.
    ##
    ## If a block is not provided, a new directory name will be returned
    ## for the temporary directory.
    ##
    ## Similar to Tempfile.new, if a TMPDIR is provided in ENV then this
    ## TMPDIR must denote an existing directory. This directory will
    ## be used as a default base directory for the temporary directory.
    ##
    ## If no TMPDIR is provided in ENV then this will use Ruby defaults
    ## for the running operating system to determine the root directory
    ## for the temporary directory.
    ##
    ## @param name [String, nil] first arg for Dir.mktmpdir
    def mktmp_dir(arg = nil, &block)
      if block_given?
        Dir.mktmpdir(arg, &block)
      else
        Dir.mktmpdir(arg)
      end
    end

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
