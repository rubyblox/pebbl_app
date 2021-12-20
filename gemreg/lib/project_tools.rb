## project_tools.rb - utility methods (non-gem source file)

require 'pathname'

class RSpecTool

  RSPEC_LOCAL_SUFFIX=".rspec"
  RSPEC_PROJECT_SUFFIX=".rb"
  PROJECT_LIBDIR_RELATIVE="lib"
  PROJECT_TESTDIR_RELATIVE="test"
  PROJECT_ROOT_FILES=%w(*.gemspec *.yproj Rakefile .git) ## NB name | case-insensitive glob patterns

  RSPEC_DEFAULT_ARGS=%w(--no-color)

  def self.fchdir(dir, *block_args, &block)
    ## NB this of course requires a usable fork() implementation on
    ## the host
    ##
    ## NB the block may call 'exit' before either of the
    ## handlers, below, would be reached
    ##
    unless (has_block = block_given?)
      warn("No block provided to #{self}.#{__method__}", uplevel: 1)
    end

    pid = Process.fork()
    if pid
      pid, status = Process.waitpid2(pid)
      return status.exitstatus
    else
      begin
        Dir.chdir(dir)
        block.yield(*block_args) if has_block
      rescue
        Kernel.exit(-1)
      else
        Kernel.exit(0)
      end
    end
  end

  def self.find_project_root(whence = Dir.pwd)
    if File.exists?(whence)
      whence_dir_p = File.directory?(whence)
    else
      raise ArgumentError.new("File does not exist: #{File.expand_path(whence)}")
    end
    base = File.expand_path(whence_dir_p ? whence : File.dirname(whence))
    fnflags = (File::FNM_DOTMATCH | File::FNM_SYSCASE | File::FNM_CASEFOLD)
    path = nil
    catch(:found) {
      Dir.children(base).each { |chfile|
        PROJECT_ROOT_FILES.each { |glob|
          if File.fnmatch(glob, chfile, fnflags)
            path = base
            throw(:found)
          end
        }
      }
    }
    if path
      return path
    else
      p = Pathname.new(base)
      if p.root?
        return nil
      else
        find_project_root(p.parent.to_s)
      end
    end
  end


  def self.project_libdir(whence)
    root = find_project_root(whence)
    dir = File.expand_path(PROJECT_LIBDIR_RELATIVE, root)
    dir if File.exists?(dir)
  end


  def self.project_testdir(whence)
    root = find_project_root(whence)
    dir = File.expand_path(PROJECT_TESTDIR_RELATIVE, root)
    dir if File.exists?(dir)
  end



  def self.find_rspec_for(file)
    f = file.to_s
    extlen = File.extname(f).length
    if (extlen < f.length)
      name = f[...-extlen]
    else
      name = f
    end

    rspec_local = name + RSPEC_LOCAL_SUFFIX
    if File.exists?(rspec_local)
      return rspec_local
    else
      root = find_project_root(f) ## FIXME
      return nil unless root
      lib_root = project_libdir(root)
      test_root = project_testdir(root)
      p = Pathname.new(File.expand_path(f))
      p_rel = p.relative_path_from(lib_root).to_s
      name_rel = p_rel[...-extlen]
      proj_rspec =
        File.join(test_root, name_rel + RSPEC_PROJECT_SUFFIX)
      if File.exists?(proj_rspec)
        return proj_rspec
      else
        return nil
      end
    end
  end

  def self.run(tests,
               basedir: find_project_root(),
               args: RSPEC_DEFAULT_ARGS,
               stderr: STDERR, stdout: STDOUT)
    ## NB this method does not provide any support for host environments
    ## that provide no usable fork() implementation
    dir = File.expand_path(basedir)
    paths = tests.map { |f| project_libdir(f) }.sort.uniq
    use_args = args.dup.concat(tests)


    fproc = lambda {
      $LOAD_PATH.concat(paths)
      gem 'rspec'
      gem 'rspec-core'
      require 'rspec/core'
      obj = ::RSpec::Core::Runner
      obj.disable_autorun!
      st = obj.run(use_args, stderr, stdout).to_i
      Kernel.exit(st)
      ## TBD assuming no interverning errors (e.g in exit after
      ## forking irb), test the process exit code, via the status
      ## object that will be returned in the forking process
    }
    self.fchdir(dir, &fproc)
  end
end

=begin TBD

e.g
RSpecTool.run("..",%w[test/basedir.rb])

=end


## Local Variables:
## fill-column: 65
## End:
