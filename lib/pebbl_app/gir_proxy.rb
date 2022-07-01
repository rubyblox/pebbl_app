
require 'pebbl_app'

gem 'gobject-introspection'
require 'gobject-introspection/loader'


require 'forwardable'

module PebblApp

  ## Providing reader method names onto instance variables of a
  ## GObjectIntrospection::Loader::Invoker
  ##
  ## e.g usage
  ## ~~~~
  ## invk = PebblApp::GtkFramework::InvokerP.invokers_for(Gtk).first
  ##
  ## invk.callable_info
  ##
  ## PebblApp::GtkFramework::InvokerP.invokers_for(Vte::Pty)
  ##
  ## ~~~~
  class InvokerP
    extend PebblApp::AttrProxy

    extend Forwardable
    attr_reader :invoker
    def_delegator(:@invoker, :invoke)
    %i(method_name full_method_name info in_args n_in_args
       n_required_in_args last_in_arg last_in_arg_is_gclosure
       valid_n_args_range in_arg_types in_arg_nils in_arg_nil_indexes
       function_info_p have_return_value_p require_callback_p
       prepared).each do |name|
      ## attr_forward_read is defined via PebblApp::AttrProxy
      attr_forward_read(:@invoker, ("@".freeze + name.to_s))
    end

    ## storage for a proxy onto a GObjectIntrospection::FunctionInfo
    ## with proxy to the value in the 'info' field of the Invoker instance
    attr_accessor :callable_info

    class << self
      def cached_invokers
        @@cached_invokers ||= {}
      end

      def find_invoker_p(invk)
        if (mtd = invk.instance_variable_get(:@full_method_name))
          key = mtd.freeze
          if cached_invokers.has_key?(key)
            return cached_invokers[key]
          else
            inst = self.new(invk)
            cached_invokers[key] = inst
            inst.callable_info = FuncInfo.find_callable_info(inst.info)
            return inst
          end
        else
          raise "No @full_method_name found for #{invk.inspect}"
        end
      end

      def invokers_for(whence)
        ## FIXME only suitable for a top-level module namespace ?
        ## e.g Gtk3, Vte, ...
        case whence
        when Class
          if whence.const_defined?(:INVOKERS)
            ## e.g Gdk::X11Display::INVOKERS
            mtd_invokers = whence::INVOKERS.map do |key, invk|
              find_invoker_p(invk)
            end
          else
            mtd_invokers = []
          end
          if whence.const_defined?(:INITIALIZE_INVOKERS)
            ## e.g Vte::Pty::INITIALIZE_INVOKERS
            ## where @info is a ConstructorInfo
            ctor_invokers = whence::INVOKERS.map do |key, invk|
              find_invoker_p(invk)
            end
          else
            ctor_invokers = []
          end
          return mtd_invokers.concat(ctor_invokers)
        when Module
          sgl = whence.singleton_class
          if sgl.const_defined?(:INVOKERS)
            ## e.g Gdk.singleton_class::INVOKERS
            ## or briefly Vte.singleton_class::INVOKERS
            sgl::INVOKERS.map do |key, invk|
              find_invoker_p(invk)
            end
          else
            return [].freeze
          end
        else
          ## tbd
          raise "Unable to find invokers for %s"
        end
      end
    end ## class << self

    def initialize(invoker)
      @invoker = invoker
    end

    def inspect
      "#<%s 0x%06x %s (0x%06x)>" % [
        self.class, self.__id__,
        ( @invoker ? self.full_method_name : "(n/a)".freeze ),
        @invoker.__id__
      ]
    end
  end

  ## @abstract base class for proxy objects onto
  ## GObjectIntrospection::CallableInfo
  class CallableInfoP
  end

  ## Providing forwarding onto instance methods of a
  ## GObjectIntrospection::FunctionInfo
  class FuncInfo < CallableInfoP

    extend PebblApp::AttrProxy

    extend Forwardable
    attr_reader :info

    ## the #invoke method on a FunctionInfo
    ## may be of interest for prototyping
    %i(signature return_type may_return_type_null
       lock_gvl_default invoke).each do |name|
      def_delegator(:@info, name)
    end

    class << self
      def cached_info
        @@cached_info ||= {}
      end

      def find_callable_info(info)
        if (key = info.signature)
          cached_info[key.freeze] ||= self.new(info)
        else
          raise "No signature found for #{info.inspect}"
        end
      end
    end ## class << self


    def initialize(info)
      @info = info
    end

    def inspect
      info = self.info
      ## tbd: storage for the 'ptr' and 'own' values for a FunctionInfo
      ## towards presentation in the inspect form for this proxy class
      "#<%s 0x%06x %s (0x%06x)>" % [
        self.class, self.__id__,
        ( info ? info.signature : "(n/a)".freeze ),
        info.__id__
      ]
    end
  end
end

