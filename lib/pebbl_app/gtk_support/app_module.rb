## Definition of PebblApp::GtkSupport::AppModule

require 'pebbl_app/project/project_module'
require 'pebbl_app/support/app_module'
require 'pebbl_app/gtk_support'

require 'optparse'
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
module PebblApp::GtkSupport::AppModule

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

  module Const
    GTK_INIT_TIMEOUT_DEFAULT = 15
  end

  def self.extended(whence)

    whence.extend PebblApp::Support::AppModule

    ## NB defining this all in class scope may affect the availability
    ## under nested include/extend - there is really no 'super' there.

    def display=(dpy)
      ## set the display, independent of parse_opts
      config[:display] = dpy
    end

    def display()
      self.config[:display] ||
        ENV['DISPLAY']
    end

    def unset_display()
      self.config.delete(:display)
    end

    def display?()
      self.config.has_key?(:display) ||
        ENV.has_key?('DISPLAY')
    end

    def configure_option_parser(parser)
      parser.on("-d", "--display DISPLAY",
                "X Window System Display, overriding DISPLAY") do |dpy|
        self.config[:display] = dpy
      end
    end

    ## configure this application
    ##
    ## the provided argv will be destructively modified by this method.
    def configure(argv: ARGV)
      super(argv: argv)
      config[:gtk_init_timeout] ||= Const::GTK_INIT_TIMEOUT_DEFAULT
      self.parse_opts(argv)
      self.parsed_args = argv
    end

    def gtk_args()
      args = self.parsed_args.dup
      if ! self.display?
        raise PebblApp::GtkSupport::ConfigurationError.new("No display configured")
      elsif self.config.has_key?(:display)
        args.push(%(--display))
        args.push(self.display)
      end
      return args
    end

    def activate(argv: ARGV)
      if (ENV['XAUTHORITY'].nil?)
        Kernel.warn("No XAUTHORITY found in environment", uplevel: 0)
      end
      self.configure(argv: argv)
      ## preload GIR object definitions via Gtk.init
      ## with timeout on the call to Gtk.init
      time = config[:gtk_init_timeout]
      Timeout::timeout(time, Timeout::Error, "Timeout in Gtk.init") do
        require 'gtk3'
        Gtk.init(* self.gtk_args)
      end
    end

  end ## self.extended
end
