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
      Gtk.main_iteration_do(context.blocking)
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
        nil ## returning nil => remove this callback after call
      end
    end
  end


  ## Gtk Application class for PebblApp
  ##
  ## This class provides GtkMain integration for Gtk::Application classes
  ##
  ## @see GtkApplication (How Do I...? GNOME Developer Center) https://developer-old.gnome.org/GtkApplication/
  class GtkApp < Gtk::Application
    include GAppMixin
    extend GUserObject
    self.register_type

    attr_accessor :framework, :open_args


    def initialize(name, flags = Gio::ApplicationFlags::FLAGS_NONE, **opts)
      ## subsq. of type_register, the opts will not be passed to any
      ## #initialize methods defined in mixins
      ##
      ## The following is anemulation of the options parsing for the
      ## #initialize method defined when inculding AppMixin
      ##
      @app_name = AppMixin.pop_opt(:app_name, opts) do
        PebblApp::ProjectModule.s_to_filename(self.class, Const::DOT).freeze
      end
      @app_dirname = AppMixin.pop_opt(:app_dirname, opts) do
        (@app_name && @app_name.downcase)
      end
      @app_env_name = AppMixin.pop_opt(:app_env_name, opts) do
        (@app_dirname && @app_dirname.split(Const::DOT).last.upcase)
      end
      if !opts.empty?
        AppLog.warn("Unused args in #{self.class}##{__method__}: #{opts}")
      end

      ## subsequent of type_register here, then at least when this
      ## method is reached from some subclass, super() here will
      ## dispatch to GLib::Object
      super("application-id" => name.freeze,
            "flags" => flags)

      ##
      ## additional configuration
      ##
      self.signal_connect("handle-local-options") do
        ## 0 : success, no further option processing needed for this application
        return 0
      end
    end

    def config
      @config ||= PebblApp::GtkConf.new() do
        ## FIXME update the binding for default app_command_name in config
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
        ctx = GtkApp.class_variable_get(:@@default_context)
        return ctx
      else
        default = DefaultContext.new(blocking: true)
        GtkApp.class_variable_set(:@@default_context, default)
      end
    end

    alias_method :context_new, :context_default


    def quit
      ## This may generally emulate Gio::Application#quit
      ## without trying to call to the Gtk main loop,
      ## such that will be unused in this application
      main_quit
      self.windows.each do |wdw|
        PebblApp::AppLog.debug("Closing #{wdw}")
        wdw.close
      end
      self.signal_emit("shutdown")
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

      ## rebind signal traps after @framework.init => Gtk.init
      bind_sys_trap

      if block_given?
        cb = block
      else
        ## join the main_context thread
        cb = proc { |thr| thr.join }
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
