## rspec tests for PebblApp::GtkSupport::AppModule

## the library to test:
require 'pebbl_app/gtk_support/app_module.rb'

describe %(PebblApp::GtkSupport::AppModule implementation) do
    subject {
      module TestClasses
        module GtkTestApp
          ## an implementing module, for the test
          include PebblApp::GtkSupport::AppModule
        end
      end
    }

    context "configuration" do
      it "Provides a configuration map" do
        expect(subject.config).to_not be_falsey
      end
    end

    context "GTK support" do
      let!(:display_initial) { ENV['DISPLAY'] }

      it "fails if no display is available" do
        ENV.delete('DISPLAY')
        null_argv = []
        subject.configure(argv: null_argv)
        expect { subject.activate(argv: null_argv) }.to raise_error(
          PebblApp::GtkSupport::ConfigurationError
        )
      end

      it "parses arg --display DPY" do
        subject.parse_opts(%w(--display :10))
        expect(subject.display).to be == ":10"
      end

      it "parses arg --display DPY to gtk_args" do
        subject.parse_opts(%w(--display :10))
        expect(subject.gtk_args).to include(":10")
      end

      it "parses arg --display=DPY" do
        subject.parse_opts(%w(--display=:11))
        expect(subject.display).to be == ":11"
      end

      it "parses arg --display=DPY to gtk_args" do
        subject.parse_opts(%w(--display=:11))
        expect(subject.gtk_args).to include(":11")
      end

      it "parses arg -dDPY" do
        subject.parse_opts(%w(-d:12))
        expect(subject.display).to be == ":12"
      end

      it "parses arg -dDPY to gtk_args" do
        subject.parse_opts(%w(-d:12))
        expect(subject.gtk_args).to include(":12")
      end


      it "overrides env DISPLAY with args" do
        ## FIXME this requires a working DISPLAY to set in the module's
        ## option parser args
        if (initial_dpy = ENV['DISPLAY'])
          ENV['DISPLAY']= initial_dpy + ".nonexistent"
          subject.parse_opts(['--display', initial_dpy])
          expect(subject.display).to be == initial_dpy
          subject.config[:gtk_init_timeout] = 5
          expect { subject.activate }.to_not raise_error
        else
          RSpec::Expectations.fail_with("No DISPLAY configured in test environment")
        end
      end

      after(:each) do
        ENV['DISPLAY'] = display_initial
      end
    end
end
