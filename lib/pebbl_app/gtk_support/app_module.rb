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
        @config ||= {}
      end

      def configure(&block)
        block.yield self.config if block_given?
      end

      def activate
        time = config[:gtk_init_timeout] || Const::GTK_INIT_TIMEOUT_DEFAULT

        ## preload GIR object definitions via Gtk.init
        ##
        ## This should fail if no DISPLAY is available and no '--display name'
        ## has been provided for Gdk.init, as via ARGV... if it would not
        ## deadlock in Gtk.init, in some way that the timeout does not interrupt
        Timeout::timeout(time, Timeout::Error, "Timeout in Gtk.init") do
          ## FIXME the deadlock without a DISPLAY here, is it not interruptable?
          require 'gtk3'
          Gtk.init(*ARGV)
        end
      end
    end ## class << whence
  end
end
