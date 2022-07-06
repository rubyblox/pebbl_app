## definition of PebblApp::GtkApp

require 'pebbl_app/app'
require 'pebbl_app/gtk_framework'

require 'timeout'

## @private earlier protototype:
## ./apploader_gtk.rb

## @private Goals
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
module PebblApp

  ## A GMain implementation for GtkApp
  class GtkMain < GMain

    attr_accessor :app

    def initialize(app)
      super()
      @app = app
    end

    def context_dispatch(context)
      super(context)
      if ! Gtk.main_iteration_do(false)  # Gtk.main_iteration_do(true)
        ## FIXME not reached, afer a call to Gtk.main_quit
        ## from some other thread ...
        AppLog.debug("Exiting Gtk context dispatch")
        throw :main_iterate
      end
    end

    def context_acquired(context)
      AppLog.debug("Context acquired")
    end

    def map_sources(context)
      ## map a run-once idle source into the event loop,
      ## to register and activate the app for this GtkMain
      ##
      ## This may typically result in an app window being displayed
      GMain.map_idle_source(context.context, remove_on_nil: true) do |context|
        AppLog.info("Starting application")
        app.start
        nil ## remove callback after run
      end
    end
  end


  ## Gtk Application class for PebblApp
  ##
  ## This class provides GtkMain integration for Gtk::Application classes
  ##
  class GtkApp < Gtk::Application
    include GAppMixin

    attr_accessor :framework, :open_args
    attr_reader :gmain

    def initialize(name, flags = Gio::ApplicationFlags::FLAGS_NONE)
      super(name, flags)
    end

    def config
      @config ||= PebblApp::GtkConf.new() do
        ## FIXME store this deferred app_command_name block as a proc
        ## in an AppMixin const, use; by default with some config_class
        ## method on the class in AppMixin
        self.app_command_name
      end
    end

    def main_new()
      GtkMain.new(self)
    end

    def context_default()
      ## while there is no API onto g_main_context_push_thread_default
      ## here, a workaround: always using the default context, across
      ## all threads in the process environment (needs further testing)
      ##
      if GtkApp.class_variable_defined?(:@@default_context)
        GtkApp.class_variable_get(:@@default_context)
      else
        default = DefaultContext.new()
        GtkApp.class_variable_set(:@@default_context, default)
      end
    end


    def main(argv: ARGV, &block)
      AppLog.app_log ||= AppLog.new
      configure(argv: argv)

      timeout = self.config.gtk_init_timeout
      ## TBD instance storage for the framework obj
      @framework ||= PebblApp::GtkFramework.new(timeout: timeout)

      gmain = (@gmain ||= main_new)
      AppLog.debug("framework.init in #{self.class}#{__method__}")

      app_args = self.config.gtk_args
      self.open_args ||= @framework.init(argv: app_args) ## FIXME args mess

      context = context_default

      if block_given?
        cb = block
      else
        ## join the main_context thread
        cb = proc { |thr| thr.join }
      end

      self.signal_connect_after "shutdown" do
        ## never reached here - this app is providing its own main loop.
        ## The shutdown signal is unused, by side effect
        AppLog.debug("Cancelling (app shutdown)")
        context.cancellation.cancel
        # context.main_loop.quit ## not used here
      end

      gmain.main(context, &cb)
    end

    ## Register and activate this application
    ##
    ## This method provides an approximate analogy to Gio::Application#run
    ##
    def start()
      self.register
      self.activate
    end

  end
end
