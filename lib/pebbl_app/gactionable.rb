## ActionableMixin

require 'pebbl_app/gtk_framework'

module PebblApp
  ## Mixin for Gio::Action management with Gtk::Actionable and
  ## Gtk::ActionMap implementations (typically of type Gtk::Widget or
  ## Gio::Application)
  ##
  ## This mixin will define the following methods in the including class:
  ##
  ## **#map_simple_action**
  ## : for binding a named action to some receiving object
  ##
  ## **#default_action_prefix**
  ## : a utility method for #map_simple_action, used when no action prefix
  ##   can be determined from the arguments provided to that method.
  ##
  ## @see GAction (How Do I...? GNOME Developer Center) https://developer-old.gnome.org/GAction/
  module ActionableMixin
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
      ## @param name [String] The action name, or "<prefix>.<name>" string.
      ##
      ## @param prefix [String, nil] If provided, the prefix for the
      ##  action name. When this value is specified, the `name` parameter
      ##  should include only the action name, without any prefix name
      ##  string.
      ##
      ## @param to [Gtk::Actionable, Gtk::ActionMap] The object for the
      ##  action's binding
      ##
      ## @param param_type [false, GLib::VariantType, string] Either a
      ##  string with a syntax as described under "GVariant Format
      ##  Strings" in GNOME devehelp, or a GLib::VariantType. If provided,
      ##  then the Gio::Action#activate method should be called with
      ##  either a GLib::Variant or Ruby object of a compatible type, to
      ##  ensure that the action's callback is activated for that call.
      ##
      ## @param handler [Proc] a callback for the action.
      ##
      def map_simple_action(name, prefix: nil, to: self,
                            param_type: nil, &handler)
        if name.include?(PebblApp::Const::DOT)
          elts = name.split(PebblApp::Const::DOT)
          parsed_prefix = elts.first
          nr = elts.length
          if nr.eql?(1)
            name = name_components.first
          elsif nr >= 2
            ## no style warning here, if the name substring includes a dot
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
          prefix ||= default_action_prefix(to)
        end

        if prefix.empty?
          raise ArgumentError.new("Empty prefix for #{name}")
        end

        if block_given?
          if (Gtk::Widget === to)
            prefix.freeze
            ## Known Limitation: Gtk::Widget#get_action_group may return
            ## an action group not literally bound to the widget
            ## itself. This may result in unspecified side effects for
            ## action binding, and should be noted in the main
            ## documentation.
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
            if ! (action_to = to.get_action_group(prefix))
              action_to = Gio::SimpleActionGroup.new
              to.insert_action_group(prefix, action_to)
            end
          else
            ## when Gio:Application === to || Gio::ActionMap === to
            ## there may not be any public API available for determing if
            ## the prefix exists on 'to'
            ##
            ## If the prefix is "app" and `to` is a Gio::Application, then
            ## generally it may "just work".
            ##
            ## For other to/prefix bindings, the caller should provide any
            ## orchestration needed for binding an action group and/or
            ## action map for that prefix in 'to'.
            ##
            ## Generally, for prefixes not "app" the prefix should be
            ## bound to some Gtk::Widget.
            ##
            ## The "app" prefix itself may be accessible under an object
            ## not a Gio::Application, e.g within a Gio::ApplicationWindow.
            ## This prefix should generally be used only for actions that
            ## have a relevance directly within an application scope,
            ## e.g an "app.quit" action
            action_to = to
          end

          PebblApp::AppLog.debug("Binding action #{prefix}.#{name} for #{self}")
          act = Gio::SimpleAction.new(name.freeze, param_type)
          if param_type
            act.signal_connect("activate".freeze) do |action, param|
              handler.yield(action, param)
            end
          else
            ## the param value received by the callback should always be
            ## nil here.
            ##
            ## The nil value received by the intermediate signal callback
            ## will be discarded in this instance, not passed to the
            ## callback provided to this method.
            ##
            ## Generally, this may not be noticed in applications unless a
            ## lambda object is provided as the callback.
            act.signal_connect("activate".freeze) do |action, _|
              handler.yield(action)
            end
          end
          action_to.add_action(act)
        else
          raise ArgumentError.new("No block provided")
        end

        return act
      end

      ## a utility method for #map_simple_action if called without an
      ## action prefix
      ##
      ## This method may be overridden as needed, in any implementing class
      ##
      ## @param to [Gtk::Appliation, Gtk::Widget] an object that may
      ##  receive an action binding as via map_simple_action
      def default_action_prefix(to = self)
        case to
        when Gtk::Application
          ## no action_prefixes method for this class of object
          "app".freeze
        when Gtk::Widget
          all = to.action_prefixes
          if all.empty
            raise ArgumentError.new("No action prefixes found for #{to}")
          else
            ## Assumption: the first action prefix may represent a default
            ## e.g "win" in %w(win app) for a Gtk::ApplicationWindow
            all[0]
          end
        else
          raise ArgumentError.new("No action support known for #{to}")
        end
      end

    end ## included
  end ## AcitonableMixin
end
