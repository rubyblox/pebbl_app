## rspec tests for PebblApp:::GtkAppMixin

## the library to test:
require 'pebbl_app/gtk_app'

require 'timeout'

describe PebblApp::GtkApp do

  it "uses a default init timeout" do
    expect(subject.conf.gtk_init_timeout).to_not be nil
  end

  it "accepts a custom init timeout" do
    subject.conf.gtk_init_timeout=5
    expect(subject.conf.gtk_init_timeout).to be 5
  end

  # it "fails in main if no display is configured" do
  #   ## TBD what actually causes the sometime deadlock under Gtk.init with no DISPLAY
  #   ## If it does not fail, then this test is not valid
  #   dpy_initial = ENV['DISPLAY']
  #   ENV.delete('DISPLAY')
  #   null_argv = []
  #   subject.conf.gtk_init_timeout=5
  #   # subject = subject.new ## ? mo change
  #   dbg = $DEBUG
  #   $DEBUG = true
  #   begin
  #     ## FIXME this test is invalid if anything calls Gtk.init earlier
  #     ##

  #     ## validity pre-test
  #     expect(Gtk.respond_to?(:init)).to be true

  #     ## testing the API
  #     expect { subject.main(argv: null_argv) }.to raise_error(
  #       PebblApp::FrameworkError
  #     )

  #     ## validity post-test
  #     expect(Gtk.respond_to?(:init)).to be true
  #   ensure
  #     ENV['DISPLAY'] = dpy_initial
  #     $DEBUG = dbg
  #   end
  # end

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
