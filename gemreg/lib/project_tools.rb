## project_tools.rb - utility methods (non-gem source file)

class RSpecTool
  def self.run(basedir, tests, args: %w[--no-color],
               stderr: STDERR, stdout: STDOUT)
    ## NB this method does not provide any support for host environments
    ## that provide no usable fork() implementation
    dir = File.expand_path(basedir)
    paths = tests.map { |f| File.expand_path(File.dirname(f)) }.sort.uniq
    use_args = args.dup.concat(tests)

    pid = Process.fork{
      Dir.chdir(dir)
      $LOAD_PATH.concat(paths)
      gem 'rspec'
      gem 'rspec-core'
      require 'rspec/core'
      whence = ::RSpec::Core::Runner
      whence.disable_autorun!
      st = whence.run(use_args, stderr, stdout).to_i
      exit(st)
    }
    if block_given?
      ## NB the block should call Proceses.wait or Process.waitpid on
      ## the PID
      yield pid
    else
      st = Process.waitpid2 pid
      return st[1]
    end
  end
end

=begin TBD

e.g
RSpecTool.run("..",%w[test/basedir.rb])

=end


## Local Variables:
## fill-column: 65
## End:
