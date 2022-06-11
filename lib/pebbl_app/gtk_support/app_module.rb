## Definition of PebblApp::GtkSupport::AppModule

require 'pebbl_app/gtk_support'
require 'pebbl_app/project/project_module'

require 'pebbl_app/support/app_module'

require 'timeout'

## :nodoc: earlier protototype:
## ./apploader_gtk.rb

## :nodoc: Goals
## [X] provide support for pathname handling for applications
##     [x] via rb_app-support.gemspec
## [x] provide support for args parsing for applications
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
  include PebblApp::Support::AppModule

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

  def self.included(whence)
    class << whence
      def config
        @config ||= {} ## FIXME app config previous to CLI args
        ## - needs actual implementation, tests @ application config files
      end

      def display=(dpy)
        ## set the display, independent of parse_opts
        if self.instance_variable_defined?(:@display)
          raise "Display already configured in #{self}. Cannot set display #{dpy}"
        else
          @display = dpy
        end
      end

      def display()
        if self.instance_variable_defined?(:@display)
          @display
        else
          ENV['DISPLAY'] ||
            ( raise PebblApp::GtkSupport::ConfigurationError.new("No display configured") )
        end
      end

      def configure_option_parser(parser)
        parser.on("-d", "--display DISPLAY",
                  "X Window System Display, overriding DISPLAY") do |dpy|
          @display = dpy
        end
      end

      ## create, configure, and return a new option parser for this
      ## application module
      def make_option_parser()
        OptionParser.new do |parser|
          self.configure_option_parser(parser)
        end
      end

      ## parse an array of command line arguments, using the option
      ## parser for this application module.
      ##
      ## the provided argv value will be destructively modified by this
      ## method.
      def parse_opts(argv = ARGV)
        parser = self.make_option_parser()
        parser.parse!(argv)
      end


      ## configure this application module
      def configure(argv: ARGV)
        config[:gtk_init_timeout] ||= Const::GTK_INIT_TIMEOUT_DEFAULT
        self.parse_opts(argv)
        self.parsed_args = argv
      end


      def parsed_args()
        ## return a new array, which can accept any calls to push or unshift
        @parsed_args ||= []
      end

      def parsed_args=(value)
        @parsed_args=value
      end

      def gtk_args()
        parsed = self.parsed_args
        if self.instance_variable_defined?(:@display) || !ENV['DISPLAY']
          ## ensure this errs if no display is configured in env
          dpy = parsed.push(self.display)
          parsed.push(%(--display))
          parsed.push(dpy)
        end
        return parsed
      end

      def activate(argv: ARGV)
        self.configure(argv: argv)
        ## preload GIR object definitions via Gtk.init
        ## with timeout on the call to Gtk.init
        time = config[:gtk_init_timeout]
        Timeout::timeout(time, Timeout::Error, "Timeout in Gtk.init") do
          require 'gtk3'
          Gtk.init(* self.gtk_args)
        end
      end

    end ## class << whence
  end
end
