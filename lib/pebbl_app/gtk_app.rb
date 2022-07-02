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

  class GtkMain < GMain
    def context_dispatch(context)
      super(context)
      Gtk.main_iteration_do(true)
    end
  end


  class GtkApp < Gtk::Application
    include GAppMixin ## TBD this && GtkAppMixin

    def conf
      @conf ||= PebblApp::GtkConf.new() do
        ## FIXME store this deferred app_cmd_name block as a proc
        ## in an AppMixin const, use; by default with some config_class
        ## method on the class in AppMixin
        self.app_cmd_name
      end
    end


    def main_new()
      GtkMain.new(logger: AppLog.app_log)
    end

    def context_default()
      ## a while there is no API onto g_main_context_push_thread_default
      ## in Ruby-GNOME, a workaround: always using the default context,
      ## across all threads in the process environment (needs further testing)
      ##
      ## may not be interoperable with Gtk.main, like anything except Gtk.main
      ##
      if GtkApp.class_variable_defined?(:@@default_context)
        GtkApp.class_variable_get(:@@default_context)
      else
        default = DefaultContext.new(logger: logger)
        GtkApp.class_variable_set(:@@default_context, default)
      end
    end

    ## [needs docs, subsq. of the next iteration in API refactoring]
    def main(argv: ARGV, &block)
      AppLog.app_log ||= AppLog.new
      configure(argv: argv)

      timeout = self.conf.gtk_init_timeout
      ## TBD instance storage for the framework obj
      framework = PebblApp::GtkFramework.new(timeout: timeout)

      gmain = (@gmain ||= main_new)
      gmain.debug("framework.init in #{self}#{__method__}")
      app_args = self.conf.gtk_args
      open_args = framework.init(argv: app_args)

      def gmain.context_acquired(context)
        ## FIXME ...
        context.debug("Context acquired")
      end

      if block_given?
        cb = block
      else
        cb = proc do |thr|
          info("Activate")
          register()
          if open_args.empty?
            activate()
          else
          end
        end ## proc
      end

      gmain.main(context_default, &cb)
    end
  end
end
