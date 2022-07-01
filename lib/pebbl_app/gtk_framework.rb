
require 'pebbl_app/framework'
require 'pebbl_app/project_module'

require 'gtk3'

require 'timeout'

module PebblApp
  module Const
    ## default timeout for Gtk.init, measured in seconds. This value
    ## will be used if no :gtk_init_timeout was configured in conf options
    GTK_INIT_TIMEOUT_DEFAULT ||= 5
  end

  include ProjectModule

  defautoloads(
    __dir__,
    {"gapp" =>
     %w(GAppCancellation GAppContext GApp),
   "gtk_app" =>
     %w(GtkApp),
   "gtk_conf" =>
     %w(GtkConf),
   "gir_proxy" =>
     %w(InvokerP FuncInfo),
   "gtk_framework/logging" =>
     ## FIXME remove, update usage onto ServiceLogger
   %w(LoggerDelegate LogManager LogModule),
   "gtk_framework/threads" => ## FIXME remove, refactor legacy to use "anonymous threads"
     %w(NamedThread),
   ## FIXME move the next three files to ./
   "gtk_framework/gobj_type" =>
     %w(GObjType),
   "gtk_framework/builders" =>
     %w(UIBuilder TemplateBuilder
        ResourceTemplateBuilder FileTemplateBuilder),
   "gtk_framework/gbuilder_app" =>
     %w(GBuilderApp),
   ## FIXME deprecate SysExit / integrate with the Service class
   "gtk_framework/sysexit" =>
     %w(SysExit)
    })

  ## prototype implementation of independent framework support for
  ## gobject-introspection
  class GtkFramework < Framework

    attr_reader :timeout

    def initialize(timeout: Const::GTK_INIT_TIMEOUT_DEFAULT)
      ## local storage, value may typically be set from app.conf data
      @timeout = timeout
    end

    def init(argv: ARGV)
      ## not reached. why not, now?
      Kernel.warn("In #{self}#{__method__}", uplevel: 0) if $DEBUG

      error = false
      if ! ENV['DISPLAY']
        ## FIXME Gdk.init may also fail if there's no xauthority
        ## information available in the environment while the X server
        ## requires xauth - not checked here
        Kernel.warn("No DISPLAY found in environment", uplevel: 0)
      end
      error = false
      continue = false
      next_args = false
      Timeout::timeout(self.timeout, FrameworkError,
                         "Timeout in Gtk initialization") do
          begin
            ## the method will be removed after the first call
            ## but should be called once.
            ##
            ## this will result in a call to Gdk.init, which may block
            ## if unable to connect to an X11 display, thus the timeout
            if Gtk.respond_to?(:init)
              Gtk.init(*argv)
            end
            ## ensure the args are parsed by Gtk
            ##
            ## this may block separately, e.g if Gtk.init was called earlier
            ## with a different DISPLAY enviornment
            continue, next_args = Gtk.init_check(argv)
          rescue Gtk::InitError => err
            error = err
          end
      end
      if continue
        return next_args
      else
        error ||= "Gtk.init_check failed"
        raise FrameworkError.new(error)
      end
    end ## init
  end ## GtkFrmework
end
