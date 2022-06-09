## rblib configuration for rspec

## see also: ./spec_helper_spec.rb

require "thinkum_space/project"

RSpec.configure do |config|
  ## configure an ENV for the testing environment
  if ! (test_out_dir = ENV['TEST_OUTPUT_DIR'])
    if (base_file = ENV['BUNDLE_GEMFILE'])
      base_dir = File.dirname(base_file)
    else
      base_dir = File.dirname(__dir__)
    end
    test_out_dir = File.join(base_dir, "tmp/tests")
  end
  test_out_dir=File.expand_path(test_out_dir)
  test_home_dir=File.join(test_out_dir, "home")

  ## an ephemeral, singleton mkdir_p method
  ##
  ## this mirrors the implementation in
  ## rblib lib/g_app/support/files.rb
  ## @ GApp::Support::Files.mkdir_p
  def config.mkdir_p(path)
    dirs = []
    lastdir = nil
    File.expand_path(path).split(File::SEPARATOR)[1..].each do |name|
      dirs << name
      lastdir = File::SEPARATOR + dirs.join(File::SEPARATOR)
      Dir.mkdir(lastdir) if ! File.directory?(lastdir)
    end
  end
  config.mkdir_p(test_home_dir)
  ENV['HOME'] = test_home_dir

  ## ensure any singleton methods defined here can be accessed under
  ## tests, via the config object received here
  $RSPEC_CONFIG = config

  ## configure a persistence path for rspec
  ##
  ## used with rspec  --only-failures, --next-failure options
  config.example_status_persistence_file_path = ".rspec_status"

  # config.expect_with :rspec do |c|
  #   c.syntax = :expect
  # end
end
