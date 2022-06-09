## rspec tests for GApp::Support::AppModule

## the library to test
require 'g_app/support/app_module'


shared_examples "scalar configured by process environment" do |conf|
  let!(:var) { conf[:var] }
  let!(:initial_value) { ENV[var] }
  let(:value) { conf[:value] }
  let(:mtd) { conf[:mtd] }

  it "to configure #{described_class}.#{conf[:mtd]} from #{conf[:var]}" do
    ENV[var] = value
    expect(subject.send(mtd)).to be == value
  end

  after(:each) do
    ENV[var] = initial_value
  end
end

shared_examples "path array configured by process environment" do |conf|
  let!(:var) { conf[:var] }
  let!(:initial_value) { ENV[var] }
  let(:value) { conf[:value] }
  let(:mtd) { conf[:mtd] }

  it "to configure #{described_class}.#{conf[:mtd]} from #{conf[:var]}" do
    ENV[var] = value
    expect(subject.send(mtd)).to be == value.split(File::PATH_SEPARATOR)
  end

  after(:each) do
    ENV[var] = initial_value
  end
end

describe GApp::Support::AppModule do

  it_behaves_like "scalar configured by process environment",
    mtd: :data_home, var: described_class::Const::XDG_DATA_HOME_ENV,
    value: "dirs/data"

  it_behaves_like "scalar configured by process environment",
    mtd: :config_home, var: described_class::Const::XDG_CONFIG_HOME_ENV,
    value: "dirs/config"

  it_behaves_like "scalar configured by process environment",
    mtd: :cache_home, var: described_class::Const::XDG_CACHE_HOME_ENV,
    value: "dirs/cache"

  it_behaves_like "scalar configured by process environment",
    mtd: :state_home, var: described_class::Const::XDG_STATE_HOME_ENV,
    value: "dirs/state"

  it_behaves_like "scalar configured by process environment",
    mtd: :tmpdir, var: described_class::Const::TMPDIR_ENV,
    value: "dirs/tmp"

  it_behaves_like "scalar configured by process environment",
    mtd: :home, var: described_class::Const::HOME_ENV,
    value: "dirs/home"

  context "provided with a path list of more than one element" do
    it_behaves_like "path array configured by process environment",
      mtd: :data_dirs, var: described_class::Const::XDG_DATA_DIRS_ENV,
      value: "dirs/data:usr/dirs/data"
    it_behaves_like "path array configured by process environment",
      mtd: :config_dirs, var: described_class::Const::XDG_CONFIG_DIRS_ENV,
      value: "dirs/config:usr/dirs/config"
  end

  context "provided with a path list of one element" do
    it_behaves_like "path array configured by process environment",
      mtd: :data_dirs, var: described_class::Const::XDG_DATA_DIRS_ENV,
      value: "dirs/data"
    it_behaves_like "path array configured by process environment",
      mtd: :config_dirs, var: described_class::Const::XDG_CONFIG_DIRS_ENV,
      value: "dirs/config"
  end

  context "provided with an empty path list" do
    it_behaves_like "path array configured by process environment",
      mtd: :data_dirs, var: described_class::Const::XDG_DATA_DIRS_ENV,
      value: ""
    it_behaves_like "path array configured by process environment",
      mtd: :config_dirs, var: described_class::Const::XDG_CONFIG_DIRS_ENV,
      value: ""
  end

end

shared_examples "an app" do |conf|
  let(:using) { GApp::Support::AppModule }
  let(:using_mtd) { conf[:using_mtd] }
  let(:mtd) { conf[:mtd] }

  it "uses a known directory for #{conf[:using_mtd]}" do
    ## testing dirname under the provided implementation method
    expect(File.dirname(subject.send(mtd))).to be ==
      using.send(using_mtd)

    ## testing basename under the provided implementation method
    expect(File.basename(subject.send(mtd))).to be ==
      File.basename(subject.app_dirname)

    ## testing full pathname under the provided implementation method
    expect(subject.send(mtd)).to be ==
      File.join(using.send(using_mtd), subject.app_dirname)
  end
end

describe %(GApp::Support::AppModule implementation) do
    subject {
      module TestClasses
        module TestApp
          include GApp::Support::AppModule
        end
      end
      }

  context "app metadata in implementating namespace" do
    let(:altname) { "TestApp" }

    it "provides a default app name" do
      expect(subject.app_name).to be == "test_classes.test_app"
    end

    it "accepts an app_name" do
      subject.app_name = altname
      expect(subject.app_name).to be == altname
    end

    it "uses a downcased app dirname" do
      subject.app_name = altname
      expect(subject.app_dirname).to be == altname.downcase
    end

  end

  it_behaves_like "an app", using_mtd: :config_home, mtd: :app_config_home
  it_behaves_like "an app", using_mtd: :state_home, mtd: :app_state_home
  it_behaves_like "an app", using_mtd: :cache_home, mtd: :app_cache_home

end
