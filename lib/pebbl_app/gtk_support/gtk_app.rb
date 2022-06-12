## Definition of PebblApp::GtkSupport::AppModule

require 'pebbl_app/project/project_module'
require 'pebbl_app/support/app'
require 'pebbl_app/gtk_support'

require 'timeout'

## :nodoc: earlier protototype:
## ./apploader_gtk.rb

## :nodoc: Goals
## [X] provide support for pathname handling for applications
##     [x] via rb_app-support.gemspec
## [x] provide support for args parsing for applications
##     [ ] FIXME move to PebblApp::Support::AppModule (all to self.parsed_args)
## [x] ensure Gtk.init is not reached if no display is configured
## [ ] provide support for runtime configuration for applications,
##     [ ] under some YAML syntax for application configuration
##     [ ] integrating with pathname handling
##         as compatible with XDG recommendations
## [ ] provide support for creating XDG desktop files
##     as typically during application installation
##
## Far-term goals
## - provide support for application packaging
## - provide support for issue tracking for applications
class PebblApp::GtkSupport::GtkApp < PebblApp::Support::App

  ## using PebblApp::Support::AppModule @ config dirs, YAML suport
  ## 1. compute a timeout for Gtk.init
  ## 2. compute a default display for Gtk.init
  ##    and emit a warning if no display can be determined
  ## 3. call Gtk.init with locally derived args
  ##    assuming Gtk.init handles args like in GTK 3 for now
  ##
  ## TBD before Gtk.init: Initialize a logger, ideally such that would
  ## also be used under GTK and such that could be mapped to a PTY
  ## and/or to a file

  ## NB this needs to access a configuration context from outside of
  ## any objects that would be initilized in the Ruby process with Gtk.init

  def config
    @config ||= PebblApp::GtkSupport::GtkConfig.new(self)
  end

  def activate(argv: ARGV)
    super(argv: argv)
    ## reduce memory usage, clearing the module's original autoloads
    ## definitions
    PebblApp::GtkSupport.freeze unless self.config.option(:defer_freeze)

    if (ENV['XAUTHORITY'].nil?)
      Kernel.warn("No XAUTHORITY found in environment", uplevel: 0)
    end
    self.configure(argv: argv)
    ## preload GIR object definitions via Gtk.init
    ## with timeout on the call to Gtk.init
    time = self.config.option(:gtk_init_timeout)
    Timeout::timeout(time, Timeout::Error, "Timeout in Gtk.init") do
      require 'gtk3'
      Gtk.init(* self.config.gtk_args)
    end
  end

end
