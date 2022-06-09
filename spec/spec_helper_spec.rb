## rspec tests for ./spec_helper.rb

## FIXME these tests should always be run first

describe "spec_helper.rb" do

  it "stores the rspec config globally" do
    expect(global_variables.include?(:$RSPEC_CONFIG)).to be true
  end

  it "defines a mkdir_p method" do
    expect($RSPEC_CONFIG.singleton_methods.include?(:mkdir_p)).to_not be_falsey
  end

  ## this test serves to illustrate the HOME directory used for tests in
  ## the rspec output, furthermore testing the initialization for the
  ## test homedir in the project's ./spec_helper.rb
  it "creates a home directory for tests: #{ENV['HOME']}" do
    expect(File.directory?(ENV['HOME'])).to be true
  end


end
