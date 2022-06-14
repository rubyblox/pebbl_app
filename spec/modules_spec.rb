## rspec tests for Pebbl App support modules

require 'pebbl_app/project/project_module'

## the libraries to test
require 'pebbl_app/support'
require 'pebbl_app/gtk_support'

shared_examples_for 'a project module' do |conf|
  let(:ns) { conf[:ns] }

  it "defines an exsisting source_path" do
    expect(ns.source_path).to_not be_falsey
    expect(File.exist?(ns.source_path)).to be true
  end

  it "defines autoloads for existing files" do
    dir = ns.source_path
    ns.autoloads.each do |name, file|
      if !File.exist?(File.expand_path(file, dir))
        RSpec::Expectations.fail_with(
          "Autoload file for %s does not exist: %p" % [
            name, file
          ])
      end
    end
  end

  it "clears autoloads table on freeze" do
    ## This test forks the active Ruby process. This is in order to
    ## conduct the test without modifications to the initial test
    ## environment such that would prevent succesful evaluation of later
    ## tests within this rspec process.
    if (subpid = Process.fork)
      Process.waitpid(subpid)
      status = $?
      ## The exit status will be an encoded bitmask value, such that
      ## should provide some diagnostic information as to which tests
      ## failed in the forked process.
      ##
      ## Each condition as indicated in the exit status will be added to
      ## a single message string for the failed instance.
      if ! (status.exitstatus.eql?(0))
        failcode = status.exitstatus
        reasons = []
        if (failcode & 1) != 0
          reasons.push "exception during freeze"
        elsif (failcode & 2) != 0
          reasons.push "autoloads non-empty after freeze"
        end
        if (failcode & 4) != 0
          reasons.push "autoloads not frozen after freeze"
        end
        RSpec::Expectations.fail_with reasons.join(", ")
      end
    else
      ## running in the subprocess, where the testing will be conducted
      ##
      ## this will exit the subprocess with a bitmask value indicating
      ## which tests failed, after printing any captured exception in
      ## the tested method to STDERR
      ex = 0
      begin
        begin
          ns.freeze
        rescue
          ex = 1
          STDERR.puts $!
        end
        if (! ns.autoloads.length.eql?(0))
          ex = ex + 2
        end
        if (! ns.autoloads.frozen?)
          ex = ex + 4
        end
      ensure
        ## exit without on_exit calls, to avoid any confusing output
        ## during exit from rpsec, while the foreground process is still
        ## conducting a test session
        exit!(ex)
      end
    end
  end ## freeze test
end

describe PebblApp::Support do
  it_behaves_like  'a project module', ns: described_class
end

describe PebblApp::GtkSupport do
  it_behaves_like  'a project module', ns: described_class
end
