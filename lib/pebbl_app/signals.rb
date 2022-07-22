## signal trap support for PebblApp

require 'pebbl_app'

module PebblApp

  class SignalMap

    class Const
      SYS_DEFAULT ||= 'SYSTEM_DEFAULT'.freeze
      DEFAULT ||= 'DEFAULT'.freeze
      IGNORE ||= 'IGNORE'.freeze
      EXIT ||= 'EXIT'.freeze
      NULL_PROC = proc { }.freeze
      EXIT_PROC = proc { exit }.freeze
    end

    class << self
      def proc_for_handler(hdlr, kind)
        ## referenced on line_editor.rb from the reline gem
        case hdlr
        when Const::SYS_DEFAULT, Const::DEFAULT
            proc { raise Interrupt.new("Signal #{kind}") }
        when Const::IGNORE
          Const::NULL_PROC
        when Const::EXIT
          Const::EXIT_PROC
        else
          if hdlr.respond_to?(:call)
            proc { hdlr.call }
          else
            Const::NULL_PROC
          end
        end
      end
    end ## class <<

    attr_reader :handlers

    def initialize()
      @handlers ||= Hash.new
    end

    ## Bind a callback for later signal trap binding
    ##
    ## After the signal trap binding is activated, then when the named
    ## signal is received by this process, the callback proc will
    ## receive two args: The signal name and any previous signal trap
    ## binding for that signal.
    ##
    ## If the previous signal handler should be evaluated within the
    ## new signal trap handler, a proc for the handler may be
    ## retrieved by passing the previous signal binding (second
    ## arg to the callback) to the method SignalMap.proc_for_handler.
    ##
    ## **Limitations on Signal Trap Callbacks**: As a known feature, the
    ## callback should avoid making any calls to Mutex#synchronize or
    ## Mutex#lock
    ##
    ## @param name [Integer, String] Name of the signal to trap
    ##
    ## @param block [proc] Callback for the signal trap. Two parameters
    ##  will be yielded to this block
    ##
    ## @yieldparam kind [String or Integer]
    ##    the signal name provided to set_handler
    ##
    ## @yieldparam handler [Object]
    ##    an object representing the signal trap handler that was
    ##    previously bound when this method was invoked. If the previous
    ##    binding should be invoked, this object can be converted to a
    ##    proc using SignalMap.proc_for_handler
    ##
    ## @return [String] the signal name provided to this method
    ##
    ## @see #with_handlers for reentrant evaluation with a SignalMap
    ##
    ## @see #bind_handlers for other evaluation with a SignalMap
    def set_handler(name, &block)
      handlers[name] = block
      return name
    end

    ## Call a block in a context where all signal handlers defined via
    ## #set_handler will be initialized as signal trap handlers
    ##
    ## If a signal cannot be bound for any of the handlers, a warning
    ## will be emitted.
    ##
    ## On normal return or on non-local return via throw or error, any
    ## signal handlers as previously initialized in the process will be
    ## restored.
    ##
    ## **Thread Safety Advisory:** This method operates on signal
    ## bindings in the operting system's process scope and should be
    ## called from at most one thread in each process.
    ##
    ## @param block [proc] The block to call
    ##
    ## @return [void] The value returned by the block
    ##
    ## @see #bind_handlers for other evaluation with a SignalMap
    def with_handlers(&block)
      exists = {}
      begin
        bind_handlers do |kind, prev|
          exists[kind] = prev
        end
        block.yield() if block_given?
      ensure
        exists.each do |kind, hdlr|
          Signal.trap(kind, hdlr) if hdlr
        end
      end
    end

    ## Bind all signal handlers defined with #set_handler
    ##
    ## If a block is provided, two args will be yielded to that block,
    ## for each binding: A signal name provided to #set_handler and
    ## any previous trap for that signal.
    ##
    ## If any previous trap binding should be handled after this call,
    ## a proc can be retrieved for each previous binding by passing the
    ## binding's object to the method SignalMap.proc_for_handler
    ##
    ## @see #with_handlers for reentrant evaluation with a SignalMap
    def bind_handlers(&block)
      ## This method is used in the definition of with_handlers
      ## and may be used separately, such as when the signal trap
      ## handlers may be invoked in a scope other than the scope in
      ## which the signal trap calls were produced
      handlers.each do |kind, hdlr|
        begin
          ## this is where the Signal.trap callback is bound
          exists = Signal.trap(kind) do
            hdlr.yield(kind, exists)
          end
          block.yield(kind, exists) if block_given?
        rescue ArgumentError => e
          Kernel.warn("Unable to bind signal trap for #{kind.inspect}", e,
                      uplevel: 0)
        end
      end ## handlers.each
    end ## bind_handlers
  end ## SignalMap

end
