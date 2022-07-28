## DialogMixin

require 'pebbl_app/gtk_framework'


module PebblApp

  ## Mixin kind for Gtk::Dialog implementations
  ##
  ## This mixin can be applied within an including class, by calling
  ## `include DialogMixin`
  ##
  ## This mixin kind will define the following actions during `initialize`
  ## - `win.cancel`
  ## - `win.apply`
  ## - `win.ok`
  ##
  ## The actions will be mapped respectively to the following instance
  ## methods:
  ## - `prefs_cancel`
  ## - `prefs_apply`
  ## - `prefs_ok`
  ##
  ## Using the Glade UI designer, each action defined with this mixin
  ## can be set as the _Action Name_ for a corresponding widget, in a
  ## Glade UI definition used by the including class.
  ##
  ## This mixin does not require that the including class would be a
  ## subclass of Gtk::Dialog.
  ##
  ## In order to bind the actions for an instance of the including class,
  ## the including class should generally ensure that the #initialize
  ## method for this mixin will be reached from that class' constructor.
  ## This may generally be reached via `super`
  ##
  module DialogMixin
    def self.included(whence)
      whence.include ActionableMixin

      def initialize(**args)
        ## see also:
        ## - signal bindings, for events that may not be easily mapped to
        ##   an action
        ##
        ## - accelerator keys configured for individual widgets.
        ##
        ##   The acceleator bindings for individual widget can be
        ##   configured in a Glade UI file, mainly under the 'Common'
        ##   panel for each UI widget definition.
        ##
        ##   This would establish a static accelerator mapping, not user
        ##   configurable during runtime.
        ##
        ##   Gtk may display each bound accelerator key combination in any
        ##   corresponding menu entry to which an accelerator has been
        ##   defined.
        ##
        ## FIXME For now, this mixin uses actions without any support for
        ## dynamic acceletor paths. Such support may require some
        ## integration with the UI definition, but may not be represented
        ## normally in the GLade UI designer.
        ##
        super(**args)
        map_simple_action("win.cancel") do |obj|
          prefs_cancel(obj)
        end
        map_simple_action("win.apply") do |obj|
          prefs_apply(obj)
        end
        map_simple_action("win.ok") do |obj|
          prefs_ok(obj)
        end
      end

      ## close the prefs window without updating configuration changes
      ##
      ## This method will be activated by the `win.cancel` action on this window
      ##
      ## @param obj [Gio::Action]
      def prefs_cancel(obj)
        PebblApp::AppLog.debug("cancel @ #{obj} => #{self}") if $DEBUG
        self.close
      end

      ## apply configuration changes without closing the window
      ##
      ## This method will be activated by the `win.apply` action on this window
      ##
      ## @param obj [Gio::Action]
      def prefs_apply(obj)
        PebblApp::AppLog.debug("apply @ #{obj} => #{self}") if $DEBUG
      end

      ## apply configuration configuration changes and close the window
      ##
      ## This method will be activated by the `win.ok` action on this window
      ##
      ## @param obj [Gio::Action]
      def prefs_ok(obj)
        PebblApp::AppLog.debug("ok @ #{obj} => #{self}") if $DEBUG
        self.close
      end

    end
  end
end
