## rspec tests for GApp::Support::AppModule

## the library to test
require 'g_app/support/app_module'

describe GApp::Support::AppModule do

  it "Uses the process environment for configuring self.data_dirs" do
    ## FIXME implement this testing pattern for all subject.*_home methods
    ## using some reusable setup/teardown calls under rspec
    pre = ENV[described_class::Const::XDG_DATA_HOME_ENV]
    begin
      ENV[described_class::Const::XDG_DATA_HOME_ENV]="a:b:c"
      expect(subject.data_home).to be == "a:b:c"
    rescue
      ENV[described_class::Const::XDG_DATA_HOME_ENV] = pre
    end
  end

end
