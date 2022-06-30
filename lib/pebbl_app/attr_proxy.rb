
require 'pebbl_app/support'

module PebblApp::Support

  class IvarUnbound < StandardError
    attr_reader :instance
    attr_reader :accessor
    def initialize(*args)
      n_args = args.length
      if n_args >= 1
        first = args.first
        message = nil
        options = nil
        instance = nil
        accessor = nil
        unknown = "(unknown)".freeze
        case first
        when Hash
          ## map args
          options = first
        else
          ## first arg => string message, typically
          message = first
          if n_args > 1
            options = args[1]
          end
        end ## first
        if options
          if (instance = options[:instance])
            @instance = instance
          end
          if (accessor = options[:accessor])
            @accessor = accessor
          end
        end
        if ! message
          message = "Not bound: %p in %p" % [
            (accessor || unknown), (instance || unknown)
          ]
        end
        super(message)
      else
        super()
      end
    end
  end


  module AttrProxy

    ## define a reader method forwarding to an attribute of a delegate
    ## object
    ##
    ## The accessor for the delegate object and the receiving attribute
    ## on the delegate object may each be provided as a method name or
    ## instance variable name.
    ##
    ## The delegate method will accept a block.
    ##
    ## If the delegate name is provided as an instance variable name,
    ## then if the forwarding method is called for an instance in which
    ## that instance variable is unbound, the block will be called with
    ## that instance and the instance variable name as a symbol.
    ##
    ## If the delegate attribute name is provided as an instance
    ## variable name, then if that instance variable is unbound on the
    ## delegate instance when called to forward for the initial
    ## instance, the block will be called with the delegate object and
    ## the delegate's instance variable name as a symbol.
    ##
    ## If neither the delegate name nor delegate attribute name is
    ## provided as an instance variable name, the block will be
    ## unused. A warning will be emitted for this condition, when the
    ## call to attr_forward_read is evaluted while $DEBUG is true.
    ##
    ## @param delegate [String, Symbol] Method or instance variable name,
    ##  denoting the delegate object in the instance scope of the
    ##  implementing class.
    ##
    ## @param attr [String, Symbol] Method or instance variable name,
    ##  denoting the receiving attribute on the delgate instance. This
    ##  attribute's value will be returned by the forwarding method
    ##
    def attr_forward_read(delegate, attr, name = nil, &fallback)
      ## implementation notes
      ##
      ## - generally similar to Forwardable.def_delegator
      ##
      ## - can retrieve the delegate object on the forwarding instance,
      ##   via a method or instance variable on the forwarding instance.
      ##   also avaialble in def_delegator (some restrictions may apply,
      ##   for forwarding via methods with def_delegator)
      ##
      ## - can forward to a method or instance variable on the delegate
      ##   instance
      ##
      ## - can forward to a non-public method on the delegate instance,
      ##   as via delegate.send(attr)

      ## accessor symbol for the delegate object
      delegate_s = delegate.to_s
      delegate_is_var = (delegate_s[0] == "@")
      accessor = delegate_s.to_sym

      ## accessor symbol for the attribute on the delegate object
      attr_s = attr.to_s
      attr_is_var = (attr_s[0] == "@")
      attrname = attr_s.to_sym

      ## name for the forwarding method
      if name
        accname = name.to_sym
      else
        accname_s = attr_is_var ? attr_s[1..] : attr_s
        accname = accname_s.to_sym
      end

      ## configure a fallback lambda, to be applied if the forwarding
      ## method is configured for access to instance variables
      if block_given?
        if(!attr_is_var && !delegate_is_var && $DEBUG)
          ## fallback_lmb would not be used in this instance
          Kernel.warn(
            "Block provided for no instance varibles in %s(%p, %p, %p)" % [
              __callee__, delegate, attr, name
            ])
        end
        fallback_lmb = fallback
      elsif (attr_is_var || delegate_is_var)
        ## no block provided, but one or both of the dispatching lambda
        ## forms will access an instance variable.
        ##
        ## ensure that a fallback_lmb is initialized, for application
        ## in subsequent lambda forms
        fallback_lmb = lambda { |instance, field|
          IvarUnbound.new(variable: attrname, instance: delegate)
        }
      end

      ## define a forwarding lambda, to access an attribute
      ## on the delegate object
      if attr_is_var
        forward_lmb = lambda { |delegate|
          if delegate.instance_variable_defined?(attrname)
            return delegate.instance_variable_get(attrname)
          else
            fallback_lmb.yield(delegate, attrname)
          end
        }
      else
        forward_lmb = lambda { |delegate|
          delegate.send(attrname)
        }
      end

      ## define a lambda form for accessing the delegate
      ## object, whether via an instance variable or an
      ## instance method in the implementing class
      if delegate_is_var
        lmb = lambda {
          if instance_variable_defined?(accessor)
            delegate = instance_variable_get(accessor)
            forward_lmb.yield(delegate)
          else
            fallback_lmb.yield(delegate, attrname)
          end
        }
      else
        lmb = lambda {
          forward_lmb.yield(self.delgate)
        }
      end

      ## bind the deleggate lambda for call from the named method
      define_method(accname, &lmb)
    end
  end

end
