## rspec tests for ./spec_helper.rb

## FIXME these tests should always be run first

describe "spec_helper.rb" do

  it "stores a data root path globally" do
    expect(global_variables.include?(:$DATA_ROOT)).to be true
    expect($DATA_ROOT).to be_a String
    expect(File.directory?($DATA_ROOT)).to be true
  end

  it "stores a HOME path relative to TMPDIR for tests" do
    if ! (tmpdir = ENV['TMPDIR'])
      RSpec::Expectations.fail_with("No env TMPDIR configured")
    end
    if ! (homedir = ENV['HOME'])
      RSpec::Expectations.fail_with("No env HOME configured")
    end
    tmp_re = Regexp.new("^" + tmpdir)
    if !(homedir.match?(tmp_re))
      RSpec::Expectations.fail_with(
        "home directory for tests %s is not relative to tmpdir %s" % [
          homedir, $DATA_ROOT
        ])
    end
  end

  it "stores the rspec config globally" do
    expect(global_variables.include?(:$RSPEC_CONFIG)).to be true
  end

  ## this test serves to illustrate the HOME directory used for tests in
  ## the rspec output, furthermore testing the initialization for the
  ## test homedir in the project's ./spec_helper.rb
  it "creates a home directory for tests: #{ENV['HOME']}" do
    expect(File.directory?(ENV['HOME'])).to be true
  end


end
