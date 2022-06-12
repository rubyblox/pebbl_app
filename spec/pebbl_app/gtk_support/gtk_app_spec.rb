## rspec tests for PebblApp::GtkSupport::GtkApp

## the library to test:
require 'pebbl_app/gtk_support/gtk_app'

describe PebblApp::GtkSupport::GtkApp do

  it "fails in activate if no display is configured" do
    dpy_initial = ENV['DISPLAY']
    ENV.delete('DISPLAY')
    null_argv = []
    begin
      subject.config.options[:defer_freeze] = true
      expect { subject.activate(argv: null_argv) }.to raise_error(
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
    subject.config.options[:gtk_init_timeout] = 5
    subject.config.options[:defer_freeze] = true
    expect { subject.activate(argv: []) }.to_not raise_error
  end

end
