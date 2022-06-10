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
        initialized = false
        passed = false
        begin
          ## FIXME this deadlocks in a way that Timeout::timeout will not interrupt
          ## and such that the ruby process cannot be interrupted with SIGINT
          # subject.activate
          initialized = true
        rescue Timeout::Error
          passed = true
        end
        expect(passed).to be true
      end

      after(:each) do
        ENV['DISPLAY'] = display_initial
      end
    end
end
