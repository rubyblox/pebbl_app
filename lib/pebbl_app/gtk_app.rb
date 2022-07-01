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

  class GtkApp < GApp

    def conf
      @conf ||= PebblApp::GtkConf.new() do
        ## FIXME store this deferred app_cmd_name block as a proc
        ## in an AppMixin const, use by default with some config_class
        ## method on the class in AppMixin
        self.app_cmd_name
      end
    end

    ## prototype method, should be overridden in implementing classes
    ##
    ## called from #main, after framwork initialization start(args)
    warn("Reached prototype #{__method__} method", uplevel: 0)
  end

  def context_dispatch(context)
    super()
    throw :main if Gtk.main_iteration_do(false)
  end

  def main(argv: ARGV)
    configure(argv: argv)


    timeout = self.conf.gtk_init_timeout
    app_args = self.conf.gtk_args
    ## TBD instance storage for the framework obj
    framework = PebblApp::GtkFramework.new(timeout: timeout)
    ## Not Reached
    Kernel.warn("Calling framework.init in #{self}#{__method__}", uplevel: 0) if $DEBUG
    next_args = framework.init(argv: app_args)
    context = self.context_new
    super(context) do |thread|
      self.start(next_args)
    end
  end

end
