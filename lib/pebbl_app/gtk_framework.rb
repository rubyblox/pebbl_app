
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
    __dir__, {
      "accel_mixin" =>
        %w(AccelMixin),
      "gactionable" =>
        %w(ActionableMixin),
      "gapp_mixin" =>
        %w(GAppMixin),
      "gcomposite" =>
        %w(UIError CompositeWidget FileCompositeWidget),
      "gdialog" =>
        %w(DialogMixin),
      "gmain" =>
        %w(GMainCancellation GMainContext GMain),
      "gtk_app" =>
        %w(GtkMain GtkApp),
      "gtk_conf" =>
        %w(GtkConf),
      "guser_object" =>
        %w(GUserObject),
      "keysym" =>
        %w(Keysym),
      "gir_proxy" =>
        %w(InvokerP FuncInfo),
      "gtk_framework/threads" => ## FIXME remove, refactor legacy to use "anonymous threads"
        %w(NamedThread),
      "gobj_type" =>
        %w(GObjType),
      "gtk_builders" =>
        %w(UIBuilder TemplateBuilder
           ResourceTemplateBuilder FileTemplateBuilder),
      "gbuilder_app" =>
        %w(GBuilderApp),
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
      AppLog.debug("In #{self.class}##{__method__}")

      error = false
      if ! ENV['DISPLAY']
        ## FIXME Gdk.init may also fail if there's no xauthority
        ## information available in the environment while the X server
        ## requires xauth - not checked here
        AppLog.warn("No DISPLAY found in environment")
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
              ## not reached (Gtk.init already called ???)
              AppLog.debug("argv post Gtk.init: #{argv}")
            end
            ## ensure the args are parsed by Gdk
            ## - albeit not of much use here, presently, except for
            ##   validating any provided args that Gdk might operate on
            ##
            ## FIXME need a separate way to parse out any known GTK/GDK args
            ##
            ## TBD this may block separately, e.g if Gtk.init was called earlier
            ## with a different DISPLAY enviornment
            continue, next_args = Gdk.init_check(argv) # or Gtk.init_check(argv)
            ## ^ if it's modifying any of the args internally, this is
            ## being lost in the API transform. Or maybe it's just not
            ## parsing out any --display option?
          rescue Gtk::InitError => err
            error = err
          end
      end
      if continue
        return next_args
      else
        error ||= "Gdk.init_check failed"
        raise FrameworkError.new(error)
      end
    end ## init
  end ## GtkFrmework
end
