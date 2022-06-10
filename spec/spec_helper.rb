## configuration for rspec

## see also: ./spec_helper_spec.rb

RSpec.configure do |config|
  ## configure $DATA_ROOT and test for bundler environment
  if ! (gemfile = ENV['BUNDLE_GEMFILE'])
    RSpec::Expectations.fail_with(
      "No BUNDLE_GEMFILE configured in env (rspec without bundler?)"
    )
  end
  $DATA_ROOT = File.dirname(gemfile)

  ## configure an ENV for the testing environment
  if !(test_out_dir = ENV['TEST_OUTPUT_DIR'])
    test_out_dir = File.join($DATA_ROOT, "tmp/tests")
  end
  test_tmpdir = File.expand_path("tmp", test_out_dir)
  test_home_dir=File.expand_path("home", test_tmpdir)

  ## an ephemeral, singleton mkdir_p method
  ##
  ## this mirrors the implementation in
  ## rblib lib/pebbl_app/support/files.rb
  ## @ PebblApp::Support::Files.mkdir_p
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
  ENV['TMPDIR'] = test_tmpdir
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
