## definition of PebblApp::GtkApp

require 'pebbl_app/app'
require 'pebbl_app/gtk_framework'

require 'timeout'

module PebblApp

  ## A GMain implementation for GtkApp
  class GtkMain < GMain

    attr_accessor :app

    ## @param app [GtkApp]
    def initialize(app)
      super()
      @app = app
    end

    def context_dispatch(context)
      if app.quit_state
        ## application is already in #quit
        throw :main_iterate, :quit
      else
        super(context)
        Gtk.main_iteration_do(!context.cancellation.cancelled?)
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
        nil ## returning nil => remove this callback after call
      end
    end
  end


  ## Gtk Application class for PebblApp
  ##
  ## This class provides GtkMain integration for Gtk::Application classes
  ##
  ## @see GtkApplication (How Do I...? GNOME Developer Center)
  ##  https://developer-old.gnome.org/GtkApplication/
  class GtkApp < Gtk::Application

    class << self
      ## initialize a GtkFramework for this class, using the provided
      ## args for that framework
      ##
      ## @opt options [Numeric] :timeout timeout for Gtk.init
      def framework(**options)
        if self.singleton_class.instance_variable_defined?(:@framework)
          self.singleton_class.instance_variable_get(:@framework)
        else
          self.framework = GtkFramework.new(**options)
        end
      end

      def framework=(framework)
        if self.singleton_class.instance_variable_defined?(:@framework)
          msg = "A framework is already initailized for %s : %p" % [
            self, self.framework
          ]
          raise FrameworkError,new(msg)
        else
          self.singleton_class.instance_variable_set(:@framework, framework)
        end
      end
    end

    include GAppMixin
    extend GUserObject
    self.register_type

    ## @private This accesor is used for determining whether the
    ## application is presently in an exiting state. This value should
    ## normally not be set directly, but may be set by side effect from
    ## a call to GtkApp#quit
    attr_accessor :quit_state

    def initialize(id, flags = Gio::ApplicationFlags::FLAGS_NONE)
      ## subsequent of type_register here, when this method is
      ## reached from some implementing class, super() here will
      ## dispatch to a constructor method onto GLib::Object
      super("application-id" => id.dup.freeze,
            "flags" => flags)
      ##
      ## additional configuration
      ##
      self.signal_connect("handle-local-options") do
        ## 0 : success, no further processing needed for command line
        ## options received by the Gio::Application for this instance
        0
      end
    end

    def conf_new
      PebblApp::GtkConf.new()
    end

    def main_new()
      GtkMain.new(self)
    end

    ## Return a DefaultContext initialized for the default GLib::MainContext
    ## at the time when this method was invoked
    ##
    ## @return [DefaultContext]
    def context_default()
      DefaultContext.new()
    end

    alias_method :context_new, :context_default

    ## close all application windows, call quit on any active GMain
    ## instance, then dispatch to the superclass quit method.
    ##
    ## The GMain quit method will set the cancellation for the
    ## active main context to a cancelled state. This should serve to
    ## ensure that the main context loop will exit from iteration and
    ## return from the context_main thread.
    def quit
      if ! self.quit_state
        self.quit_state = true
        PebblApp::AppLog.debug("Quit #{self}")
        self.windows.each do |wdw|
          PebblApp::AppLog.debug("Closing #{wdw}")
          wdw.close
        end
        if (main = @gmain) && (main.running)
          main.quit
          main.running = false
        end
        super()
      end
    end

    def main(argv: ARGV, &block)

      AppLog.app_log ||= AppLog.new
      configure(argv: argv)

      ## TBD gmain here will not be completely operable as a Glib::MainLoop.
      ##
      ## This framework does not ever run GLib::MainLoop#run.
      ## As such, it's unclear as to whether or how gmain#quit may
      ## operate here
      gmain = (@gmain ||= main_new)

      AppLog.debug("framework.init in #{self.class}##{__method__}")
      app_args = self.config.gtk_args(argv)

      ## ensure that the class' framework is initialized
      ##
      ## For GtkApp and generally for GNOME frameworks, the framework
      ## should be initialized via some exe script. This would be as to
      ## initialize the framework before any class names have been
      ## resolved over GIR.
      ##
      ## This call would provide a fallback behavior, such that would at
      ## least dispatch to call Gtk.init_check
      self.class.framework.init(app_args)

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
      ## cleanup after gmain.main return
      ##
      ## - ensure the shutdown signal is emitted.
      ##
      ## This is referenced onto g_application_run
      ## in glib-2.70.4 gio/gapplication.c
      ##
      ## Known Limitations & g_application_run behaviors not handled here
      ##
      ## - This method will not call g_settings_sync.
      ##
      ##   Any subclass' main method can call Gio::Settings.sync after
      ##   the superclass' main method returns
      ##
      ## - This will not un-register the application
      ##
      ##   When not using Gio::Application#main, and without any further
      ##   C language extensions to the GTK API, the application cannot
      ##   be un-registered in Ruby. GLib/GIO does not provide any public
      ##   API for as much.
      ##
      ##   Presently, the only time that the "is-registered" signal will
      ##   be received by an application will be emitted when the
      ##   application is initially registered.
      ##
      ##   By side effect, this will also not clear the private
      ##   implementation data of the Gio::Application. In effect, any
      ##   application object created with this API may provide at most
      ##   "one use" under #main
      ##
      ## - After return from the gmain.main call, this will not
      ##   provide any additional calls to Gtk.main_iteration_do
      ##   or g_main_context_iteration. (FIXME this can be adjuted)
      ##
      self.signal_emit("shutdown")
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
