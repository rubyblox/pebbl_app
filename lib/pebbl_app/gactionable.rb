## ActionableMixin

require 'pebbl_app/gtk_framework'

module PebblApp

  ## Mixin for Gio::Action management with Gtk::Actionable,
  ## Gtk::ActionMap, and other GLib::Object implementations.
  ##
  ## This mixin is activated by way of `include`, e.g
  ## ~~~~
  ## class IncludingClass
  ##   include PebblApp::ActioanbleMixin
  ## end
  ## ~~~~
  ##
  ##
  ## This mixin will define the following methods in the including class:
  ##
  ## **#map_simple_action**
  ## : for binding a named action of type Gio::SimpleAction to some
  ##   receiving object
  ##
  ## **#map_value_action** and **#map_stateful_action**
  ## : for complex actions receiving a parameter in activation and/or an
  ##   action state value
  ##
  ## **#default_action_prefix**
  ## : a utility method for #map_simple_action, used when no action prefix
  ##   can be determined from the arguments provided to that method.
  ##
  ## The `map_simple_action` method is generally compatible with
  ## Gio::Action usage cases in Gtk::Widget and Gio::Application
  ## objects.
  ##
  ## The `map_value_action` and `map_stateful_action` methods should
  ## generally not be used for actions used internally by `Gtk::Widget`
  ## objects, but may be of use for other GLib objects.
  ##
  ## @see GAction (How Do I...? GNOME Developer Center) https://developer-old.gnome.org/GAction/
  module ActionableMixin

    class << self

      ## @private Methiod This method provides a generalized API for
      ## `map_simple_action` and may be extended for similar utility
      ## methods.
      def map_action(name, prefix, receiver, param_type, activate_data = nil,
                     handler, &ctor)
        ## TBD the name value may be provided with a "Detailed name" part,
        ## e.g "name::str"
        ##
        if name.include?(PebblApp::Const::DOT)
          elts = name.split(PebblApp::Const::DOT)
          parsed_prefix = elts.first
          nr = elts.length
          if nr.eql?(1)
            name = name_components.first
          elsif nr >= 2
            name = elts[1..].join(PebblApp::Const::DOT)
          else
            raise ArgumentError.new("Unable to parse action name: #{name.inspect}")
          end
          if prefix && (prefix != parsed_prefix)
            raise ArgumentError.new(
              "Provided prefix %p does not match implied prefix %p in %p" % [
                prefix, parsed_prefix, name
              ])
          else
            prefix ||= parsed_prefix
          end
        else
          prefix ||= default_action_prefix(receiver)
        end

        if prefix.empty?
          raise ArgumentError.new("Empty prefix for #{name}")
        end

        if (Gtk::Widget === receiver)
          ## Known Limitation: Gtk::Widget#get_action_group may return
          ## an action group not literally bound to the widget
          ## but rather to some containing widget. This may result in
          ## unspecified side effects for an action binding, and should
          ## be noted in the main documentation.
          ##
          ## There might not be any public API available for determining
          ## the exact widget that an action group for some prefix has
          ## been bound to, short of a depth-first manual traversal of
          ## the set of widget ancestors for any single widget.
          ##
          ## If the caller must override some action group in a
          ## containing widget, the caller may add the overriding action
          ## group to that widget before calling this method. Albeit,
          ## this may not represent an ideal approach for applications.
          ##
          ## Generally, each window should be created such that every
          ## action prefix for any widget under that window will map to
          ## exactly one action group within that widget's' widget tree.
          ##
          ## This utility method may not provide a complete support for
          ## debugging with regards to widget/prefix and group/action
          ## bindings. A comprehensive widget inspector may be provided
          ## in some other API.
          if ! (action_recv = receiver.get_action_group(prefix))
            ## TBD test for any existing action of the provided name on action_recv
            action_recv = Gio::SimpleActionGroup.new
            receiver.insert_action_group(prefix, action_recv)
          end
        else
          ## when Gio:Application === receiver || Gio::ActionMap === receiver
          ## there may not be any public API available for determing if
          ## an action prefix exists on the receiver
          ##
          ## If the prefix is "app" and `receiver` is a Gio::Application,
          ## then generally it may "just work".
          ##
          ## For other receiver/prefix bindings, the caller should
          ## provide any orchestration needed for binding an action
          ## group and/or action map for that prefix in 'to', or simply
          ## provide a prefix known to exist on the receiver.
          ##
          ## Generally, for prefixes not "app" the prefix should be
          ## bound to some Gtk::Widget.
          ##
          ## The "app" prefix itself may be accessible under an object
          ## not a Gio::Application, e.g within a Gio::ApplicationWindow.
          ## This prefix should generally be used only for actions that
          ## have a relevance directly within an application scope,
          ## e.g an "app.quit" action
          action_recv = receiver
        end

        PebblApp::AppLog.debug("Binding action %s.%s for %s" %
                               [prefix, name, receiver]) if $DEBUG

        act = ctor.yield(name, param_type)

        if handler
          ## param will always be nil if no param_type was provided
          ##
          ## if an activate_data value was provided, generally the data
          ## arg to the callback/handler will eql?(activate_data)
          cb = lambda { |action, param, data|
            ## placing this in a lambda will allow for a normal 'return'
            ## call from within the handler callback => return from lambda
            handler.yield(action, param, data)
          }
          act.signal_connect("activate", activate_data, &cb)
        end

        action_recv.add_action(act)
        return act
      end

    end ## class << ActionableMixin


    ## See also: PebblApp::ActionableVariation (sandbox)
    def self.included(whence)

      ## Add a Gio::Action to some receiving object.
      ##
      ## This method accepts an optional parameter type for the action's
      ## `activate` method. The semantics of a call to the `activate`
      ##  method for the action will differ as per whether a parameter
      ## type was provided.
      ##
      ## The callback will be activated under any call to the `activate`
      ## method on the action, such that the call provdies an argument
      ## signature compatible to the action's definition.
      ##
      ## The definition of the callback will also differ for whether a
      ## parameter type is provided. If a parameter type is provided, then
      ## the callback for the action should accept two arguments: An
      ## action object and the parameter value.
      ##
      ## If no param_type is provided, then the callback should accept
      ## one argument, the action object.
      ##
      ## For any action:
      ##
      ## If an action defined with a parameter type is activated with an
      ## incompatible parameter object or activated with no parameter, or
      ## if an action with no parameter type is activated with a
      ## parameter, then a critical log message should be emitted by Gio
      ## and the callback may not be activated.
      ##
      ## For any action defined with a parameter type:
      ##
      ## - When the activate method is called for the action, if called
      ##   with an object that is a GLib::Variant object holding some
      ##   value compatible with the parameter type, then the callback
      ##   will receive the original value of the variant object.
      ##
      ## - If the activate method is called with a Ruby object, such that
      ##  the Ruby object is of a type compatible with the parameter type
      ##  for the action, then the call should receive the original Ruby
      ##  object. Ruby-GNOME may provide some intermediate handling for
      ##  the GLib::Variant objects here.
      ##
      ## For any action defined without a parameter type: When the
      ## Gio::Action#activate method is called for that action, and called
      ## with no parameter value, the callback will be activated for that
      ## action.
      ##
      ## **Compatibility**
      ##
      ## This method returns a Gio::SimpleAction. When using `nil` as
      ## the _`param_type`_, this method is known to be generally
      ## interoperable with actionable GTK widgets, e.g Gtk::ModelButton
      ##
      ## @param name [String] The action name, or "<prefix>.<name>" string.
      ##
      ## @param prefix [String, nil] If provided, the prefix for the
      ##  action name. When this value is specified, the `name` parameter
      ##  should include only the action name, without any prefix name
      ##  string.
      ##
      ## @param receiver [Gtk::Actionable, Gtk::ActionMap, or nil] The
      ##  object to receive the action's binding. If nil, then the
      ##  scoped instance of the implementing class will be used.
      ##
      ## @param param_type [false, GLib::VariantType, string] Either a
      ##  string with a syntax as described under "GVariant Format
      ##  Strings" in GNOME devehelp, or a GLib::VariantType. If provided,
      ##  then the Gio::Action#activate method should be called with
      ##  either a GLib::Variant or Ruby object of a compatible type, to
      ##  ensure that the action's callback is activated for that call.
      ##  When using the action as an action for a GTK widget, the
      ##  `param_type` should generally be `nil`.
      ##
      ## @param handler [Proc] a callback for the action.
      ##
      def map_simple_action(name, prefix: nil, receiver: nil,
                            param_type: nil,  activate_data: nil,
                            &handler)
        receiver = self if ! receiver
        ActionableMixin.map_action(name, prefix, receiver,
                                   param_type, activate_data, handler) do
          |name, param_type|
          Gio::SimpleAction.new(name, param_type)
        end
      end

      ## a utility method for #map_simple_action if called without an
      ## action prefix
      ##
      ## This method may be overridden as needed, in any implementing class
      ##
      ## @param receiver [Gtk::Appliation, Gtk::Widget] an object that may
      ##  receive an action binding as via map_simple_action
      def default_action_prefix(receiver = nil)
        case receiver
        when NilClass, FalseClass
          default_action_prefix self
        when Gio::Application
          ## no action_prefixes method for this class of object
          "app"
        when Gtk::Widget
          all = receiver.action_prefixes
          if all.empty?
            raise ArgumentError.new("No action pre found for #{receiver}")
          else
            ## Assumption: the first action prefix may represent a default
            ## e.g "win" in %w(win app) for a Gtk::ApplicationWindow
            all[0]
          end
        else
          raise ArgumentError.new("No action support known for #{receiver}")
        end
      end

    end ## included
  end ## ActionableMixin
end
