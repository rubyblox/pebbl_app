
require 'pebbl_app/gtk_framework'

require 'glib2'

module PebblApp
  module GAppMixin
    def self.included(whence)
      whence.attr_reader :gmain
      whence.include AppMixin
    end

    ## TBD GMain, GMainContext - initialization and dispatch for GApp, GtkApp

    def make_gcontext
      GMainContext.new
    end

    def main_new()
      GMain.new()
    end

    def main_quit
      if (main = @gmain) && (main.running)
        main.quit
      end
    end

    def quit
      ## may not be reached across some `super` calls in later mixins
      main_quit
    end

    ## TBD (needs debug with/outside of GtkApp - see gmain)
    def main(argv: ARGV, &block)
      PebblApp::AppLog.app_log ||= PebblApp::AppLog.new

      gmain = (@gmain ||= main_new)

      if block_given?
        cb = block
      else
        cb = proc { |thr| thr.join }
      end

      gmain.main(make_gcontext, &cb)
    end

  end ## GAppMixin
end
