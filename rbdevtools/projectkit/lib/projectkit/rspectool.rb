## rspectool.rb - rspec utility methods

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}


require 'pathname'
require 'rspec'

class ProjectKit::RSpecTool

  extend IOKit::ProcessFacade
  ## ^ NB new definition source for .fork_in
  ##   @ rbproject:iokit/lib/iokit/process_facade.rb
  ## ^ NB spawn supports a :chdir arg

  ## FIXME reimplement how the following constants are used

  RSPEC_LOCAL_SUFFIX=".rspec"
  RSPEC_PROJECT_SUFFIX=".rb"
  PROJECT_LIBDIR_RELATIVE="lib"
  PROJECT_TESTDIR_RELATIVE="test"
  PROJECT_ROOT_FILES=%w(*.gemspec *.yproj Rakefile .git) ## NB name | case-insensitive glob patterns

  RSPEC_DEFAULT_ARGS=%w(--no-color)

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
    ## FIXME needs integration with a broader projects API
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


  # def self.rspec_runner_lambda(specs, *args)
  ## TBD for portability's sake
  # end

  def self.process_exit(status)
    ## exit without activating any exit hooks (IRB/other)
    ## in a forked subprocess
    ##
    ## used in a lambda constructed in self.run(..)
    Kernel.exit!(status)
  end

  ## run a set of rspec tests
  def self.run(tests,
               basedir: find_project_root(),
               args: RSPEC_DEFAULT_ARGS,
               stderr: STDERR, stdout: STDOUT)
    ## NB spawn accepts a :chdir arg

    ## NB this method does not provide any support for host environments
    ## that provide no usable fork() implementation
    dir = File.expand_path(basedir)
    tests = [tests] unless tests.is_a?(Array)
    libdirs = tests.map { |f| project_libdir(f) }.sort.uniq
    run_args = args.dup.concat(tests)

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

    fproc = lambda { |libdirs, run_args|
      ## initialize and dispatch to an RSpec Runner, in a manner
      ## generally similar to the implementation of the 'rspec'
      ## shell command, in Ruby
      ##
      ## NB this will be called in a subprocess, under fork
      $LOAD_PATH.concat(libdirs)
      gem 'rspec'
      gem 'rspec-core'
      require 'rspec/core'
      obj = ::RSpec::Core::Runner
      obj.disable_autorun!
      ## run the RSpec Runner
      st = obj.run(run_args, stderr, stdout).to_i
      ## NB skipping any irb exit hooks (history save, etc)
      ## in the forked subprocess
      self.process_exit(st)
    }
    ## NB if using absolute pathnames, it should not be per se
    ## necessary to chdir under the (IRB/Ruby/...) process running
    ## rspec. Probably safer to run it from the project root dir,
    ## regardless.
    self.fork_in(dir, args: [libdirs, run_args],
                 &fproc)
  end


  ## run an rspec test for a single project file
  def self.run_for(file, args: RSPEC_DEFAULT_ARGS,
                   reload: true)
    use_file = File.expand_path(file)
    spec = find_rspec_for(use_file)
    base = find_project_root(use_file)
    ## ensure the latest version of the file is loaded
    begin
      load(use_file) if reload
    rescue => exc
      return [exc.message, *exc.backtrace]
    end
    run(spec, basedir: base)
  end
end

=begin TBD

e.g
RSpecTool.run("..",%w[test/basedir.rb]) ## FIXME file moved

=end

=begin DEBUG

NB if using 'exit' rather than 'Kernel.exit!' in the forked
process for RSpecTool.run, the following may appear ... when this is run
under irb in an Emacs buffer

/usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ext/save-history.rb:112:in `[]': no implicit conversion of Range into Integer (TypeError)
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ext/save-history.rb:112:in `save_history'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ext/save-history.rb:60:in `block in extended'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:485:in `block in run'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:485:in `each'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:485:in `ensure in run'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:485:in `run'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:409:in `start'
	from -e:1:in `<main>'
/home/u1000/wk/rbdevtools/projectkit/lib/projectkit/rspectool.rb:167:in `exit': exit (SystemExit)
	from /home/u1000/wk/rbdevtools/projectkit/lib/projectkit/rspectool.rb:167:in `block in run'
	from /home/u1000/wk/rbdevtools/projectkit/lib/projectkit/rspectool.rb:46:in `fork_in'
	from /home/u1000/wk/rbdevtools/projectkit/lib/projectkit/rspectool.rb:173:in `run'
	from /home/u1000/wk/rbdevtools/projectkit/lib/projectkit/rspectool.rb:187:in `run_for'
	from (irb):12:in `<main>'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/workspace.rb:116:in `eval'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/workspace.rb:116:in `evaluate'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/context.rb:450:in `evaluate'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:567:in `block (2 levels) in eval_input'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:758:in `signal_status'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:548:in `block in eval_input'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ruby-lex.rb:251:in `block (2 levels) in each_top_level_statement'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ruby-lex.rb:233:in `loop'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ruby-lex.rb:233:in `block in each_top_level_statement'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ruby-lex.rb:232:in `catch'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb/ruby-lex.rb:232:in `each_top_level_statement'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:547:in `eval_input'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:481:in `block in run'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:480:in `catch'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:480:in `run'
	from /usr/lib/ruby/gems/3.0.0/gems/irb-1.3.6/lib/irb.rb:409:in `start'
	from -e:1:in `<main>'

=end


## Local Variables:
## fill-column: 65
## End:
