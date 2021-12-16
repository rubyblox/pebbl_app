## project_tools.rb - utility methods (non-gem source file)

class RSpecTool
  def self.run(basedir, tests, args: nil, stderr: STDERR, stdout: STDOUT)
    dir = File.expand_path(basedir)
    paths = tests.map { |f| File.expand_path(File.dirname(f)) }.sort.uniq
    Process.fork{
      warn "using #{dir}"
      Dir.chdir(dir)
      $LOAD_PATH.concat(paths)
      gem 'rspec'
      gem 'rspec-core'
      require 'rspec/core'
      whence = ::RSpec::Core::Runner
      whence.disable_autorun!
      st = whence.run(tests, stderr, stdout).to_i
      exit(st)
    }
  end
end

=begin TBD

e.g
RSpecTool.run("..",%w[test/basedir.rb])

=end
