
require 'pebbl_app/gtk_framework'

require 'glib2'

module PebblApp
  module GAppMixin
    def self.included(whence)
      whence.include AppMixin
    end

    ## TBD GMain, GMainContext - initialization and dispatch for GApp, GtkApp

    def make_gcontext
      GMainContext.new
    end

    def make_gmain(logger: ConsoleLogger.new)
      GMain.new(logger: logger)
    end

    ## TBD
    def main(argv: ARGV, &block)
      PebblApp::AppLog.app_log ||= PebblApp::AppLog.new

      open_args = configure(argv: argv)
      make_gmain.main(make_gcontext) do |thr|
        info("Activate")
        register()
        if open_args.empty?
          activate()
        else
          ## FIXME open_args => [files...] &optional hint
          ## for "hints" @ g_application_open & the "open" signal
          open(open_args, "".freeze)
        end
      end
    end

  end ## GAppMixin
end
