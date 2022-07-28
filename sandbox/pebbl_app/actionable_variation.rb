## ActionableVariation - extensions after ActioanbleMixin (sanbox)

require 'pebbl_app/gactionable'

module PebblApp
  module ActionableVariation

    def self.included(whence)
      whence.include ActionableMixin

      ## Add a ValueAction to some receiving GLib object. If initialized
      ## without a `nil` param_type, the ValueAction can be activated
      ## with a value
      ##
      ## **Compatibility**
      ##
      ## This method returns a ValueAction with an initialized value for
      ## the provided `param_type`. This is not known to be interoperable
      ## with actionable GTK widgets, but may be of use for other
      ## objects in GLib.
      ##
      ## @param name (see #map_simple_action)
      ## @param prefix (see #map_simple_action)
      ## @param receiver (see #map_simple_action)
      ## @param value initial value for the action; Should be compatible
      ##  with the provided `param_type`
      ## @param param_type (see #map_simple_action)
      def map_value_action(name, prefix: nil, receiver: nil,
                           activate_data: nil,
                           value: false,
                           param_type: ValueAction.guess_variant(value),
                           enabled: false, &handler)
        receiver = self if ! receiver
        ActionableMixin.map_action(name, prefix, receiver,
                                   param_type, activate_data, handler) do
          |name, param_type|
          ValueAction.new(name,
                          value: value, param_type: param_type,
                          enabled: enabled)
        end
      end


      ## Add a StatefulAction to some receiving GLib object.
      ##

      ## **Compatibility**
      ##
      ## This method returns a StatefulAction with an initialized value and
      ## state for each of the provided `param_type` and `state_type`.
      ## This is not known to be interoperable with actionable GTK
      ## widgets, , but may be of use for other objects in GLib.
      ##
      ## @param name (see #map_simple_action)
      ## @param prefix (see #map_simple_action)
      ## @param receiver (see #map_simple_action)
      ## @param value (see #map_value_action)
      ## @param param_type (see #map_simple_action)
      ## @param state initial state for the action
      def map_stateful_action(name, prefix: nil, receiver: nil,
                              activate_data: nil,
                              value: false,
                              param_type: ValueAction.guess_variant(value),
                              state: false,
                              enabled: false, &handler)
        receiver = self if ! receiver
        ActionableMixin.map_action(name, prefix, receiver,
                                   param_type, activate_data, handler) do
          |name, param_type|
          ## the state-type property is not ever writable
          StatefulAction.new(name,
                             value: value, param_type: param_type,
                             state: state, enabled: enabled)
        end
      end
    end ## ActionableVariation included

    ## A Gio::SimpleAction that supports activation with a value
    ##
    ## **Compatibility**
    ##
    ## This class is defined as a general convenience class for Ruby
    ## applications onto GLib.
    ##
    ## This class is not known to be interoperable with actionable GTK widgets,
    ## but may be used with other GLib objects.
    ##
    ## @see Gio::SimpleAction
    ## @see StatefulAction
    ## @see ActionableMixin
    class ValueAction  < Gio::SimpleAction
      extend GUserObject
      register_type

      class << self
        ## Return a variant indicating 'true'
        def true_variant
          if class_variable_defined? :@@true_variant
            @@true_variant
          else
            @@true_variant =
              GLib::Variant.new(true, GLib::VariantType::BOOLEAN)
          end
        end

        ## Return a variant indicating 'false'
        def false_variant
          if class_variable_defined? :@@false_variant
            @@false_variant
          else
            @@false_variant =
              GLib::Variant.new(false, GLib::VariantType::BOOLEAN)
          end
        end

        ## Return either the true_variant or the false_variant per whether
        ## the provided state represents a truthy value or a falsey value
        def tf_for(state)
          state ? true_variant : false_variant
        end

        ## @private
        def guess_variant_type(value)
          case value
          when TrueClass, FalseClass, NilClass
            "b"
          when String
            "s"
          when Array
            sub = value.map { |elt| guess_variant_type(elt) }.sort.uniq
            if (sub.length.eql?(1)) then
              "a#{sub}"
            else
              "a*"
            end
          when Integer
            bits = value.bit_length
            plusp = value.positive?
            if bits <= 8
              plusp ? "y" : "n"
            elsif bits <= 16
              plusp ? "n" : "q"
            elsif bits <= 32
              plusp ? "i" : "u"
            elsif bits <= 64
              plusp ? "x" : "t"
            else
              "v"
            end
          when Bignum
            ## in Ruby an Integer is also a Bignum ...
            "v"
          else
            ## other
            "v"
          end.freeze
        end


        def guess_variant(value)
          GLib::VariantType.new(guess_variant_type(value))
        end
      end ## class << ValueAction


      def initialize(name,
                     value: false,
                     param_type: ValueAction.guess_variant(value),
                     enabled: false, **args)
        super("enabled" => enabled ? true : false,
              "name" => name,
              "parameter-type" => param_type,
              **args
             )
      end

      def true_variant
        ValueAction.true_variant
      end
      def false_variant
        ValueAction.false_variant
      end

      def activate(param)
        set_param = GLib::Variant === param ?
          param : GLib::Variant.new(param, self.parameter_type)
        super(set_param)
      end
    end

    ## Class for a stateful implementation of Gio::Action
    ##
    ## See #state=
    ##
    ## A StatefulAction is also a ValueAction. As such, when initialized
    ## with a `param_type` not `nil`, the action can be activated with a
    ## value, as well as receiving a value for #state=
    ##
    ## The #activate method may be generally orthogonal to #state=
    ##
    ## **Compatibility**
    ##
    ## This class is defined as a general convenience class for Ruby
    ## applications onto GLib.
    ##
    ## This class is not known to be interoperable with actionable GTK
    ## widgets, but may be used with other GLib objects.
    ##
    ## @see Gio::SimpleAction
    ## @see ValueAction
    ## @see ActionableMixin
    class StatefulAction < ValueAction
      extend GUserObject
      register_type

      def initialize(name,
                     value: false,
                     param_type: ValueAction.guess_variant(value),
                     state: false,
                     enabled: false)
        ## the state-type property is not ever writable,
        ## not even in the constructor
        init_state =
          GLib::Variant === state ? state : GLib::Variant.new(state)
        super(name, value: value, param_type: param_type, enabled: enabled,
              "state" => init_state)
      end

      def state=(state)
        set_state = GLib::Variant === state ?
          state : GLib::Variant.new(state, self.state_type)
        super(set_state)
      end

    end
  end ## ActionableVariation
end
