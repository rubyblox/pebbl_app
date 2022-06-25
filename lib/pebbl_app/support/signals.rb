## signals support for PebblApp

require 'pebbl_app/support'


module PebblApp::Support

  class SignalHandlerMap

    attr_reader :handlers

    def initialize()
      @handlers ||= Hash.new
    end

    ## Configure a signal handler to initialied in #with_handlers
    ##
    ## When the signal is received by the process, the handler's block
    ## will be called with one arg, the signal name for which the
    ## handler was configured. This behavior is in extension to
    ## Signal.trap
    ##
    ## @param name [Integer, String] Name of the signal to trap within
    ##  #with_handlers
    ##
    ## @param block [proc] Callback for the signal trap
    ##
    ## @return [String] the name value
    def set_handler(name, &block)
      handlers[name] = block
      return name
    end

    ## Call block in a context where all signal handlers added via
    ## #set_handler will be initailized as Signal.trap handlers
    ##
    ## On normal return or on return with error, any signal handlers as
    ## previously initialized in the active process will be restored.
    ##
    ## @param block [proc] The block to call
    ##
    ## @return [void] The value returned by the block
    ##
    def with_handlers(&block)
      previous = {}
      begin
        handlers.each do |kind, hdlr|
          previous[kind] = Signal.trap(kind) do
            hdlr.yield(kind)
          end
        end
        block.yield() if block_given?
      ensure
        previous.each do |signal, prev|
          Signal.trap(signal, prev)
        end
      end
    end
  end
end
