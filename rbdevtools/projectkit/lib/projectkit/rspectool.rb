## rspectool.rb - rspec utility methods

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}


require 'pathname'

class ProjectKit::RSpecTool

  ## FIXME reimplement how the following constants are used

  RSPEC_LOCAL_SUFFIX=".rspec"
  RSPEC_PROJECT_SUFFIX=".rb"
  PROJECT_LIBDIR_RELATIVE="lib"
  PROJECT_TESTDIR_RELATIVE="test"
  PROJECT_ROOT_FILES=%w(*.gemspec *.yproj Rakefile .git) ## NB name | case-insensitive glob patterns

  RSPEC_DEFAULT_ARGS=%w(--no-color)

  def self.fork_in(dir, *block_args, &block)
    ## NB this of course requires a usable fork() implementation on
    ## the host
    ##
    ## NB the block may call 'exit' before either of the
    ## handlers, below, would be reached
    ##
    ## FIXME how to fork_in & exec w/o reusing spawn here, per se?
    ## - see IOProc::OutProc / IOKit::OutProc
    unless (has_block = block_given?)
      warn("No block provided to #{self}.#{__method__}", uplevel: 1)
    end

    pid = Process.fork()
    if pid
      pid, st = Process.waitpid2(pid)
      return st.exitstatus
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
      ## NB File.directory? will dereference symlinks
      whence_dir_p = File.directory?(whence)
    else
      raise ArgumentError.new("File does not exist: #{File.expand_path(whence)}")
    end
    base = File.expand_path(whence_dir_p ? whence : File.dirname(whence))
    fnflags = (File::FNM_DOTMATCH | File::FNM_CASEFOLD)
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
      root = find_project_root(f)
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

    ## FIXME this 'fork' approach may not be tremendously
    ## effective. If a library was already required in the
    ## calling Ruby environment and has been edited since last
    ## require, the updated version will not be loaded for the
    ## internal rspec checks.
    ##
    ## TBD can use fork_in => exec
    ## - ensure at_exit functions are called before the exec
    ## - this will prevent any internal modifications to the
    ##   environment runnming rspec from within Ruby

    fproc = lambda {
      $LOAD_PATH.concat(paths)
      gem 'rspec'
      gem 'rspec-core'
      require 'rspec/core'
      obj = ::RSpec::Core::Runner
      obj.disable_autorun!
      st = obj.run(use_args, stderr, stdout).to_i
      Kernel.exit(st)
    }
    ## NB if using absolute pathnames, it should not be per se
    ## necessary to chdir under the (IRB/Ruby/...) process running
    ## rspec. Probably safer to run it from the project root dir,
    ## regardless.
    self.fork_in(dir, &fproc)
  end
end

=begin TBD

e.g
RSpecTool.run("..",%w[test/basedir.rb]) ## FIXME file moved

=end


## Local Variables:
## fill-column: 65
## End:
