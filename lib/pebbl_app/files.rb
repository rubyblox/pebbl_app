## PebblApp::Files module definition

## define modules, autoloads
require 'pebbl_app'

require 'forwardable'
require 'tempfile'

## Filesystem Support
module PebblApp::Files

  class << self

    extend Forwardable

    ## class methods on File other than for stream I/O in Ruby
    %w(ctime birthtime utime chmod chown lchmod lchown lutime link
       symlink readlink lstat unlink rename umask truncate expand_path
       mkfifo absolute_path? absolute_path realdirpath realpath dirname
       basename fnmatch empty? path extname fnmatch? size split join
       delete directory? exist? exists? readable? readable_real?
       world_readable? writable? writable_real? world_writable?
       executable? executable_real? file? size? owned? grpowned? pipe?
       symlink? socket? zero? blockdev? chardev? setuid? sticky?
       identical? setgid? stat ftype atime mtime).each do |name|
      def_delegator(File, name.to_sym)
    end

    ## a subset of class methods on Dir
    %w(tmpdir each_child children chdir pwd chroot mkdir rmdir
       home glob empty?).each do |name|
      def_delegator(Dir, name.to_sym)
    end

    ## return a pathname removed of any directory and removed of any
    ## type component, i.e removed of any component including and after
    ## any dot "." character other than the fist character in the file
    ## basename.
    ##
    ## This method will operate similarly for file names and directory
    ## names, returning a name removed of any type extension.
    ##
    ## This method will parse a "Dot file" or "Dot directory" similar
    ## to an ordinary filename.
    ##
    ## Examples:
    ## ~~~~
    ## PebblApp::Files.shortname("/etc/login.conf") => "login"
    ## PebblApp::Files.shortname("#{Dir.home}/.login.conf") => ".login"
    ## PebblApp::Files.shortname(".bashrc") => ".bashrc"
    ## PebblApp::Files.shortname(".") => "."
    ## PebblApp::Files.shortname("..") => ".."
    ## PebblApp::Files.shortname("/") => ""
    ## PebblApp::Files.shortname("/a/b/") => "b"
    ## PebblApp::Files.shortname("/b/.c/") => ".c"
    ## PebblApp::Files.shortname(".files.d") => ".files"
    ## ~~~~
    ##
    ## @param name [String] a filename
    ##
    ## @return [String] the filename removed of any filename type
    ## extension
    ##
    def shortname(filename)
      name = File.basename(filename)
      if (name == File::SEPARATOR)
        return "".freeze
      else
        namelen = name.length
        if (namelen > 1 && name[0] == ".".freeze)
          ext = File.extname(name[1..])
        else
          ext = File.extname(name)
        end
        shortlen = namelen - ext.length - 1
        return name[..shortlen]
      end
    end

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

    ## create a temporary directory, forwarding to Dir.mktmpdir
    ##
    ## If a string arg is provided, this will be used as the first arg
    ## for Dir.mktmpdir
    ##
    ## If a block is provided, the temporary directory will be yielded
    ## to the block as a string, and the directory will be unlinked
    ## after exit from the block. The return value from the block will
    ## then provide the return value from this method. (FIXME needs
    ## test for a non-empty temporary directory)
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
    ## @param arg [String, nil] first arg for Dir.mktmpdir
    ## @param block [Proc, nil] block for Dir.mktmpdir, if provided
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
    ##  If provided as a relative filename, the filename will be
    ##  expanded relative to Dir.pwd
    ##
    ## @param callback [Proc] If provided, a block accepting one
    ##  argument.  For each directory created by this method, the
    ##  directory will be yielded to any provided block as an absolute
    ##  pathname in a string syntax. For example, this block can be used
    ##  to configure file permissions on directories created in this
    ##  method.
    ##
    ## @return [String] the directory created, as an absolute filename
    def mkdir_p(path, &callback)
      dirs = []
      lastdir = nil
      File.expand_path(path).split(File::SEPARATOR).each do |name|
        dirs << name
        if (name == "".freeze)
          lastdir = File::SEPARATOR
        else
          lastdir = dirs.join(File::SEPARATOR)
        end
        if ! File.directory?(lastdir)
          Dir.mkdir(lastdir)
          callback.yield(lastdir) if block_given?
        end
      end
      return lastdir
    end

    ## Update the last access time and/or last modified time for a file,
    ## dereferencing the file if a symbolic link.
    ##
    ## @param file [String] the filename
    ## @param atime [Time] timestamp for last access time
    ## @param mtime [Time] timestamp for last modified time
    ## @see ltouch
    def touch(file, atime = File.atime(file), mtime = Time.now)
      File.utime(atime, mtime, file)
    end

    ## Update the last access time and/or last modified  for a file
    ## or symbolic link
    ##
    ## @param file [String] the filename
    ## @param atime [Time] timestamp for last access time
    ## @param mtime [Time] timestamp for last modified time
    ## @see touch
    def ltouch(file, atime = File.atime(file), mtime = Time.now)
      File.lutime(atime, mtime, file)
    end
  end
end
