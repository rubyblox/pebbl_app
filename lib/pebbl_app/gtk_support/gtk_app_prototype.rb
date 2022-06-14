## Definition of PebblApp::GtkSupport::AppModule

require 'pebbl_app/project/project_module'
require 'pebbl_app/support/app_prototype'
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
module PebblApp::GtkSupport

  ## Constants for PebblApp::GtkSupport::GtkApp
  module Const
    ## default timeout for Gtk.init, measured in seconds. This value
    ## will be used if no :gtk_init_timeout was configured as a
    ## GtkApp#config.option for the GtkApp
    GTK_INIT_TIMEOUT_DEFAULT = 15
  end

  module GtkAppPrototype

  include(PebblApp::Support::AppPrototype)

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


  def handle_args(args)
    ## prototype method, should be overridden in implementing classes
    ##
    ## args: as returned by Gtk.init_with_args
    ##       and as may be used under "handle open" typically
  end


  def activate(argv: ARGV)
    configure(argv: argv)

    ## reduce memory usage, clearing the module's original autoloads
    ## definitions
    ##
    ## FIXME call the freeze during app startup if deferred here
    # PebblApp::GtkSupport.freeze unless self.config.option(:defer_freeze)


    if (ENV['XAUTHORITY'].nil?)
      Kernel.warn("No XAUTHORITY found in environment", uplevel: 0)
    end
    ## preload GIR object definitions via Gtk.init
    ## with timeout on the call to Gtk.init
    time = self.config.option(:gtk_init_timeout, Const::GTK_INIT_TIMEOUT_DEFAULT)
    init = false
    args = self.config.gtk_args
    next_args = args
    Timeout::timeout(time, Timeout::Error, "Timeout in Gtk.init") do
      require 'gtk3'
      ## This calls Gtk.init_with_args, such that may not be initially defined.
      ##
      ## In the first instance, this will call through to Gtk.init
      ##
      ## In subsequent instances, this method will still be available
      ##
      ## FIXME after Gtk.init and before initializing the application's
      ## GTK code, pre-load any classes named with string values under
      ## a config parameter, config.options[:preload_classes] (Array)
      ##
      if Gtk.respond_to?(:init)
        Gtk.init(*args)
        init = true
      else
        ## calling Gtk.init_with_args here, e.g after Gtk.init has
        ## removed the method Gtk.init
        ##
        ## The behaviors of Gtk.init_with_args may not entirely match
        ## the behaviors of the initial Gtk.init e.g for some args
        ## processed by GTK such as "--display"
        ##
        ## This at least provides a consistently reachable method
        ## for initialization onto GTK
        init, next_args = Gtk.init_with_args(args, self.app_cmd_name, [].freeze, nil)
      end
    end
    if init
      nm = self.app_name
      GLib::set_application_name(nm)
      GLib::Log::set_log_domain(nm)
      self.handle_args(next_args)
    else
      ## TBD whether and how this may be reached
      ## TBD error codes under GTK via Ruby
      raise "Gtk initialization failed"
    end
  end


#  end ## included(whence)

end

end
