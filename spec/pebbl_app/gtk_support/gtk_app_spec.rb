## rspec tests for PebblApp::GtkSupport::AppModule

## the library to test:
require 'pebbl_app/gtk_support/app_module.rb'

describe %(PebblApp::GtkSupport::AppModule implementation) do
    subject {
      module TestClasses
        ## an implementing class, for the test
        class GtkTestApp
          #include PebblApp::GtkSupport::AppModule
          extend PebblApp::GtkSupport::AppModule
        end
      end
    }

    context "GTK support" do
      ## tests specs defined here may modify DISPLAY in the test
      ## environment. The initial value should be restored after
      ## each test.
      ##
      ## This text context requires that some DISPLAY is available.
      ## See also: Xvfb(1)
      let!(:display_initial) { ENV['DISPLAY'] }

      before(:each) do
        subject.config.parsed_args=[]
        subject.config.unset_display
        subject.config[:debug] = true
      end

      after(:each) do
        ENV['DISPLAY'] = display_initial
      end

      it "Uses a GtkConfig for config" do
        expect(subject.config).to be_a PebblApp::GtkSupport::GtkConfig
      end

      it "parses arg --display DPY" do
        subject.config.parse_opts(%w(--display :10))
        expect(subject.config.display).to be == ":10"
      end

      it "parses arg --display DPY to gtk_args" do
        subject.config.parse_opts(%w(--display :10))
        expect(subject.config.gtk_args).to be == %w(--display :10)
      end

      it "parses arg --display=DPY" do
        subject.config.parse_opts(%w(--display=:11))
        expect(subject.config.display).to be == ":11"
      end

      it "parses arg --display=DPY to gtk_args" do
        subject.config.parse_opts(%w(--display=:11))
        expect(subject.config.gtk_args).to be == %w(--display :11)
      end

      it "parses arg -dDPY" do
        subject.config.parse_opts(%w(-d:12))
        expect(subject.config.display).to be == ":12"
      end

      it "parses arg -dDPY to gtk_args" do
        subject.config.parse_opts(%w(-d:12))
        expect(subject.config.gtk_args).to be == %w(--display :12)
      end

      it "resets parsed args" do
        subject.config.parsed_args=[]
        subject.config.configure(argv: [])
        expect(subject.config.parsed_args).to be == []
      end

      it "indicates when no display is configured" do
        ENV.delete('DISPLAY')
        null_argv = []
        subject.config.configure(argv: null_argv)
        expect(subject.config.display?).to_not be_truthy
      end

      it "fails in activate if no display is configured" do
        ENV.delete('DISPLAY')
        null_argv = []
        expect { subject.activate(argv: null_argv) }.to raise_error(
          PebblApp::GtkSupport::ConfigurationError
        )
      end

      it "overrides env DISPLAY with any display arg" do
        if (initial_dpy = ENV['DISPLAY'])
          ENV['DISPLAY']= initial_dpy + ".nonexistent"
          subject.config.parse_opts(['--display', initial_dpy])
          expect(subject.config.display).to be == initial_dpy
        else
          RSpec::Expectations.fail_with("No DISPLAY configured in test environment")
        end
      end

      it "dispatches to Gtk.init" do
        ## this test spec will have side effects that may affect any
        ## later tests using GNOME components
        subject.config.options[:gtk_init_timeout] = 5
        expect { subject.activate(argv: []) }.to_not raise_error
      end

    end
end
