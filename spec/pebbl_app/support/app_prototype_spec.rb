## rspec tests for PebblApp::Support::AppModule

## the library to test
require 'pebbl_app/support/app_prototype'

## NB call subject.config.options[:defer_freeze] = true
## before any calls to subject.activate here

shared_examples "scalar configured by process environment" do |conf|
  ## the calling example should define an instance value
  let!(:var) { conf[:var] }
  let!(:initial_value) { ENV[var] }
  let(:value) { conf[:value] }
  let(:mtd) { conf[:mtd] }

  it "to configure #{described_class}.#{conf[:mtd]} from #{conf[:var]}" do
    ENV[var] = value
    expect(instance.class.send(mtd)).to be == value
  end

  after(:each) do
    ENV[var] = initial_value
  end
end

shared_examples "path array configured by process environment" do |conf|
  ## the calling example should define an instance value
  let!(:var) { conf[:var] }
  let!(:initial_value) { ENV[var] }
  let(:value) { conf[:value] }
  let(:mtd) { conf[:mtd] }

  it "to configure #{described_class}.#{conf[:mtd]} from #{conf[:var]}" do
    ## NB the subject is a class here, the described_class is a module
    ENV[var] = value
    expect(instance.class.send(mtd)).to be == value.split(File::PATH_SEPARATOR)
  end

  after(:each) do
    ENV[var] = initial_value
  end
end


shared_examples "an app filesystem manager" do |conf|
  ## the calling example should define an instance value
  let(:ns) { instance.class }
  let(:ns_mtd) { conf[:ns_mtd] }
  let(:mtd) { conf[:mtd] }

  it "uses a known directory for #{conf[:ns_mtd]}" do
    ## testing dirname under the provided implementation method
    ## given that the ns module will return the dirname of the dir
    ## returned by <described_class>:<mtd>
    expect(File.dirname(instance.send(mtd))).to be ==
      ns.send(ns_mtd)

    ## testing basename under the provided implementation method,
    ## given that the implementing method will return a directory
    ## representing the app_dirname, suffixed to pathname from the
    ## corresponding method in the namespace module
    expect(File.basename(instance.send(mtd))).to be ==
      File.basename(instance.app_dirname)

    ## testing full pathname under the provided implementation method
    expect(instance.send(mtd)).to be ==
      File.join(ns.send(ns_mtd), instance.app_dirname)
  end
end


describe PebblApp::Support::AppPrototype do
  let!(:impl_class) {
    class TestProtoApp
      include PebblApp::Support::AppPrototype
    end
  }
  let(:instance) {
    impl_class.new
  }


  context "method delegation" do
    it "initializes a file manager" do
      expect(instance.file_manager).to_not be_falsey
      expect(instance.file_manager).to be_a PebblApp::Support::FileManager
    end
    it "delegates the #app_config_home method" do
      expect(instance.file_manager.respond_to?(:app_config_home)).to be true
      expect(instance.respond_to?(:app_config_home)).to be true
      expect(instance.app_config_home).to be == instance.file_manager.app_config_home
    end
  end


  context "class methods" do
    it_behaves_like "scalar configured by process environment",
      mtd: :data_home, var: PebblApp::Support::Const::XDG_DATA_HOME_ENV,
      value: "dirs/data"

    it_behaves_like "scalar configured by process environment",
      mtd: :config_home, var: PebblApp::Support::Const::XDG_CONFIG_HOME_ENV,
      value: "dirs/config"

    it_behaves_like "scalar configured by process environment",
      mtd: :cache_home, var: PebblApp::Support::Const::XDG_CACHE_HOME_ENV,
      value: "dirs/cache"

    it_behaves_like "scalar configured by process environment",
      mtd: :state_home, var: PebblApp::Support::Const::XDG_STATE_HOME_ENV,
      value: "dirs/state"

    it_behaves_like "scalar configured by process environment",
      mtd: :tmpdir, var: PebblApp::Support::Const::TMPDIR_ENV,
      value: "dirs/tmp"

    context "homedir" do
      let!(:stored_home) { ENV['HOME'] }
      after(:each) do
        ENV['HOME'] = stored_home
      end

      it_behaves_like "scalar configured by process environment",
        mtd: :home, var: PebblApp::Support::Const::HOME_ENV,
        value: "dirs/home"

      it "fails in home when no HOME is configured" do
        ENV.delete('HOME')
        expect {impl_class.home}.to raise_error PebblApp::Support::EnvironmentError
      end
    end

    context "derives application configuration from user name" do
      let!(:stored_user) { ENV['USER'] }
      let!(:stored_path) { ENV['PATH'] }
      after(:each) do
        ENV['USER'] = stored_user
        ENV['PATH'] = stored_path
      end

      it_behaves_like "scalar configured by process environment",
        mtd: :username, var: PebblApp::Support::Const::USER_ENV,
        value: "user"

      it "calls whoami for username when no user name is configured" do
        pathdirs = ENV['PATH'].split(File::PATH_SEPARATOR)
        pathdirs.unshift(__dir__)
        ENV['PATH'] = pathdirs.join(File::PATH_SEPARATOR)
        ## the expected value should be produced with the local ./whoami mock
        ENV.delete('USER')
        expect(impl_class.username).to be == "whoami:#{stored_user}"
      end

      it "fails in username when no user name is configured and the whoami call fails" do
        ## ensure that the local whomai mock is not in PATH
        ENV['PATH'] = "/nonexistent"
        ## ensure that no USER string is present in the process environment
        ENV.delete('USER')
        expect { impl_class.username }.to raise_error PebblApp::Support::EnvironmentError
      end
    end

    context "provided with a path list of more than one element" do
      it_behaves_like "path array configured by process environment",
        mtd: :data_dirs, var: PebblApp::Support::Const::XDG_DATA_DIRS_ENV,
        value: "dirs/data:usr/dirs/data"
      it_behaves_like "path array configured by process environment",
        mtd: :config_dirs, var: PebblApp::Support::Const::XDG_CONFIG_DIRS_ENV,
        value: "dirs/config:usr/dirs/config"
    end

    context "provided with a path list of one element" do
      it_behaves_like "path array configured by process environment",
        mtd: :data_dirs, var: PebblApp::Support::Const::XDG_DATA_DIRS_ENV,
        value: "dirs/data"
      it_behaves_like "path array configured by process environment",
        mtd: :config_dirs, var: PebblApp::Support::Const::XDG_CONFIG_DIRS_ENV,
        value: "dirs/config"
    end

    context "provided with an empty path list" do
      it_behaves_like "path array configured by process environment",
        mtd: :data_dirs, var: PebblApp::Support::Const::XDG_DATA_DIRS_ENV,
        value: ""
      it_behaves_like "path array configured by process environment",
        mtd: :config_dirs, var: PebblApp::Support::Const::XDG_CONFIG_DIRS_ENV,
        value: ""
    end
  end ## class methods

  context "instance methods" do
    context "configuration" do
      it "Provides a configuration" do
        expect(instance.config).to_not be_falsey
      end
    end

    context "app metadata in implementing namespace" do
      let(:altname) { "TestApp" }

      it "provides a default app name" do
        ## this default value should not be used in any applications,
        ## except for purpose of testing
        ##
        ## PebblApp::Support::App is in effect an abstract class
        expect(instance.app_name).to be == "test_proto_app"
      end

      it "accepts an app name" do
        instance.app_name = altname
        expect(instance.app_name).to be == altname
      end

      it "uses a downcased app dirname" do
        instance.app_name = altname
        expect(instance.app_dirname).to be == altname.downcase
      end
    end

    context "app filesystem" do
      it_behaves_like "an app filesystem manager",
        ns_mtd: :config_home, mtd: :app_config_home
      it_behaves_like "an app filesystem manager",
        ns_mtd: :state_home, mtd: :app_state_home
      it_behaves_like "an app filesystem manager",
        ns_mtd: :cache_home, mtd: :app_cache_home
    end

  end ## instance methods
end
