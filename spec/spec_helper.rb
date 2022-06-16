## configuration for rspec

## see also: ./spec_helper_spec.rb

require 'pebbl_app/support/sh_proc'

RSpec.configure do |config|
  ## configure $DATA_ROOT and test for bundler environment
  if ! (gemfile = ENV['BUNDLE_GEMFILE'])
    RSpec::Expectations.fail_with(
      "No BUNDLE_GEMFILE configured in env (rspec without bundler?)"
    )
  end
  $DATA_ROOT = File.dirname(gemfile)

  ## configure an ENV for the testing environment
  if !(test_out_dir = ENV['TEST_OUTPUT_DIR'])
    test_out_dir = File.join($DATA_ROOT, "tmp/tests")
  end
  test_tmpdir = File.expand_path("tmp", test_out_dir)
  test_home_dir=File.expand_path("home", test_tmpdir)

  ## an ephemeral, singleton mkdir_p method
  ##
  ## this mirrors the implementation in
  ## rblib lib/pebbl_app/support/files.rb
  ## @ PebblApp::Support::Files.mkdir_p
  def config.mkdir_p(path)
    dirs = []
    lastdir = nil
    File.expand_path(path).split(File::SEPARATOR)[1..].each do |name|
      dirs << name
      lastdir = File::SEPARATOR + dirs.join(File::SEPARATOR)
      Dir.mkdir(lastdir) if ! File.directory?(lastdir)
    end
  end
  config.mkdir_p(test_home_dir)
  ENV['TMPDIR'] = test_tmpdir
  ENV['HOME'] = test_home_dir

  ## ensure any singleton methods defined here can be accessed under
  ## tests, via the config object received here
  $RSPEC_CONFIG = config

  ## configure a persistence path for rspec
  ##
  ## used with rspec --only-failures, --next-failure options
  config.example_status_persistence_file_path = ".rspec_status"

  # config.expect_with :rspec do |c|
  #   c.syntax = :expect
  # end

  this = File.basename($0)

  ## if no DISPLAY is configured and Xvfb is available,
  ## run Xvfb as a background process, providing a DISPLAY
  ## with a display name derived from the ruby PID
  if ! ENV['DISPLAY']
    cmd = PebblApp::Support::ShProc.which('Xvfb')
    if cmd
      $XVFB = cmd
      dpy=":#{$$}"
      $XVFB_PID = Process.spawn("#{$XVFB} #{dpy}")
      $XVFB_DPY = dpy
      Kernel.warn("#{this}: Initialized Xvfb (#{$XVFB_PID}) for display #{dpy}")
      at_exit {
        this = File.basename($0)
        if $XVFB_PID
          ## STDERR may not be available in an at_exit proc.
          ## Kernel.warn may typically use the stderr stream, when available
          Kernel.warn("#{this}: Closing Xvfb process (#{$XVFB_PID}) on #{$XVFB_DPY}")
          begin
            Process.kill("TERM", $XVFB_PID)
          rescue => e
            Kernel.warn("#{this}: Error during Xvfb sutdown: #{e}", uplevel: 0)
          end
        end
      }
      ENV['DISPLAY'] = dpy
      ## remove some xauth variables that might be inherited from
      ## the process environment.
      ##
      ## If using a DISPLAY other than for which the xauth service for
      ## these variables was created, absent of any corresponding
      ## xauth config for the Xvfb server, the xauth environment
      ## may interfere with X display service connections for that
      ## display, from Gdk under Gtk.init
      ##
      ## XAUTHORITY : Usually seen under local X server config
      ## XAUTHLOCALHOSTNAME : May be initialized under 'ssh -XY <remote>'
      ##                      (seen with an openSUSE remote host)
      ##
      %w(XAUTHORITY XAUTHLOCALHOSTNAME).each do |var|
        ENV[var] = nil
      end
    else
      Kernel.warn("#{this}: Xvfb not found in search path #{ENV['PATH']}")
    end
    STDERR.puts("#{this}: Using display #{ENV['DISPLAY'] || %((none))}")
  end

end
