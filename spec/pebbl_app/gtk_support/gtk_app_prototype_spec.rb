## rspec tests for PebblApp::GtkSupport::GtkApp

## the library to test:
require 'pebbl_app/gtk_support/gtk_app_prototype'

require 'timeout'

describe PebblApp::GtkSupport::GtkAppPrototype do
  subject {
    class GtkTestProtoApp
      include PebblApp::GtkSupport::GtkAppPrototype
    end
  }
  let(:instance) {
    subject.new
  }


  it "fails in activate if no display is configured" do
    dpy_initial = ENV['DISPLAY']
    ENV.delete('DISPLAY')
    null_argv = []
    begin
      instance.config.options[:defer_freeze] = true
      expect { instance.activate(argv: null_argv) }.to raise_error(
        PebblApp::GtkSupport::ConfigurationError
      )
    ensure
      ENV['DISPLAY'] = dpy_initial
    end
  end

  it "dispatches to Gtk.init" do
    ## this test spec will have side effects that may affect any
    ## later tests using GNOME components
    ##
    ## it does not appear to work out to try to run this test under
    ## fork, as the Gtk.init call may then deadlock in the forked
    ## process.
    instance.config.options[:gtk_init_timeout] = 5
    instance.config.options[:defer_freeze] = true
      expect {
        begin
          instance.activate(argv: [])
        rescue Timeout::Error
          ## this error may indicate a misconfiguration
          ## in the testing environment
          RSpec::Expectations.fail_with("Timeout during Gtk.init")
        end
      }.to_not raise_error
  end

end
