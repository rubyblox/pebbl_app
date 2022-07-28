
require 'pebbl_app/framework'
require 'pebbl_app/project_module'

require 'timeout'

module PebblApp
  module Const

    ## Default timeout for Gtk.init, measured in seconds. This value
    ## will be used during framework initialization, if no
    ## :gtk_init_timeout was configured in GtkConf options
    GTK_INIT_TIMEOUT_DEFAULT ||= 5
    ## Environment variable name for an X11 display
    DISPLAY_ENV ||= 'DISPLAY'.freeze

    ## Feature name for GTK support
    GTK_FEATURE ||= "gtk3".freeze

    ## Feature name for GDK support
    GDK_FEATURE ||= ("gdk" + GTK_FEATURE[-1]).freeze
  end

  require Const::GTK_FEATURE

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
      "tree_util" =>
        %w(TreeUtil),
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

    ## Timeout in seconds, for framework initialization
    attr_reader :timeout

    ## @param timeout [Numeric] Timeout in seconds, for framework
    ##  initialization
    def initialize(timeout: Const::GTK_INIT_TIMEOUT_DEFAULT)
      ## local storage, value may typically be set from app.conf data
      @timeout = timeout
    end

    ## Initialize Gtk once, setting initialized_args to the argv
    ## provided to the first call to this method.
    ##
    ## If a value has already been stored for initialized_args,
    ## the value will be returned on the assumption that Gtk has already
    ## been initialized.
    ##
    def init(argv = ARGV)
      if args = @initialized_args
        return args
      else
        AppLog.debug("In #{self.class}##{__method__}")
        error = false
        if ! ENV['DISPLAY']
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
              AppLog.debug("Initializing GDK, GTK")
              Gtk.init(*argv)
            end
            ## ensure the args are parsed by Gdk
            ## - albeit not of much use here, presently, except for
            ##   validating any provided args that Gdk might operate on
            ##
            ## FIXME need a separate way to parse out any known GTK/GDK args
            ##
            ## TBD this may block separately, e.g if Gtk.init was called earlier
            ## with a different DISPLAY enviornment
            continue, next_args = Gdk.init_check(argv)
            ## ^ if it's modifying any of the args internally, this is
            ## being lost in the API transform. Or maybe it's just not
            ## parsing out any --display option?
          rescue Gtk::InitError => err
            error = err
          end
        end
        if continue
          ## returns from here
          @initialized_args = next_args
        else
          error ||= "Gdk.init_check failed"
          raise FrameworkError.new(error)
        end
      end ## initialized
    end ## init
  end ## GtkFrmework
end
