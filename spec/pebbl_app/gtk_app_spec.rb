## rspec tests for PebblApp:::GtkAppMixin

## the library to test:
require 'pebbl_app/gtk_app'

require 'timeout'

describe PebblApp::GtkApp do
  subject {
    inst = described_class.new(described_class.app_name + ".test")
    def inst.activate
      self.quit
    end
    return inst
  }


  it "uses a default init timeout" do
    expect(subject.config.gtk_init_timeout).to_not be nil
  end

  it "accepts a custom init timeout" do
    subject.config.gtk_init_timeout=5
    expect(subject.config.gtk_init_timeout).to be 5
  end

  it "dispatches to Gtk.init" do
    ## this test spec will have side effects that may affect any
    ## later tests using GNOME components
    ##
    ## it does not appear to work out to try to run this test under
    ## fork, as the Gtk.init call may then deadlock in the forked
    ## process.
    subject.config.options[:gtk_init_timeout] = 5
      expect {
        begin
          subject.main(argv: [])
        rescue PebblApp::FrameworkError => err
          ## If reached, this error may indicate a misconfiguration
          ## in the testing environment
          RSpec::Expectations.fail_with(err)
        end
      }.to_not raise_error
  end

end
