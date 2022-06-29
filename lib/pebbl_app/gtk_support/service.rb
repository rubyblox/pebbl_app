## Service version 1.1.0

require 'pebbl_app/gtk_support'
require 'pebbl_app/support/logging'

require 'forwardable'

require 'glib2'
require 'gio2'

module PebblApp::GtkSupport

class ServiceCancellation < Gio::Cancellable
  ## e.g the #reason  may be set to an exception object under any error
  ## handler logic in the main event loop of a ServiceContext
  attr_accessor :reason
  def initialize()
    super()
    self.reset
  end
  def reset()
    super()
    @reason = false
  end
end

## see Service
class ServiceContext < GLib::MainContext

  attr_reader :conf_mtx, :main_mtx, :cancellation

  ## If true (the default) then the Service#context_dispatch method
  ## should block for source availability during main loop iteration
  attr_reader :blocking

  def initialize(blocking: true)
    super()
    ## in application with Service subclasses, the main loop will run
    ## in a thread separate to the main thread, i.e the thread in which
    ## the GLib::MainContext was configured
    ##
    ## the conf_mtx value here is applied to prevent the loop from
    ## dispatching events until after all sources have been configured
    ## for the context
    @conf_mtx = Mutex.new
    @main_mtx = Mutex.new
    @cancellation = ServiceCancellation.new
    ## used in Service#context_dispatch
    @blocking = blocking
  end

end


## This class is an adaptation after [the Main Contexts tutorial]
## (https://developer.gnome.org/documentation/tutorials/main-contexts.html)
## in the [GNOME Developer Documentation]
## (https://developer.gnome.org/documentation/index.html).
##
## This implementation uses GLib::MainContext support in [Ruby-GNOME]
## (https://github.com/ruby-gnome/ruby-gnome/)
##
## The Service/ServiceContext framework implements a cancellable main
## event loop model for GLib applications.
##
## **Examples**
##
## An example is avaialble in the file sandbox/service-example.rb under
## the project root directory
##
## **Notes**
##
## - This `Service` implementation requires a `ServiceContext`. The
##   `ServiceContext` class extends GLib::MainContext as to
##   provide mutex objects for synchronization in the _configure_  and
##   _application_ sections of the Service#main method.
##
## - Applications defining a subclass e.g ServiceImpl on Service may
##   extend the `ServiceContext` class, e.g as ServiceImplContext. This
##   may be of use, for instance to provide a custom API in the
##   ServiceImplContext. The custom API on the ServiceImplContext may be
##   used, for example, in the SeviceImpl's #configure and #main methods,
##   respectively for configuring sources/callbacks for the
##   ServiceImplContext and for any runtime logic in the #main thread.
##
##   The DispatchTest source code may provide an example of this
##   extensional logic.
##
## - Each ServiceContext in #main should be used for at most one call
##   to #main.
##
## - Generally, an application extending `Service` should provide at
##   least a #configure method and a #main method.
##
##   The #configure method should add any one or more GLib::Source
##   objects to the ServiceContext provided to the method, also
##   configuring any properties on each source, e.g source priority.
##   Each GLib::Source object should provide a custom callback, such that
##   will be available in each iteration of the main loop initialized via
##   #context_main.
##
##   The service main loop will run within a thread returned by
##   #context_main, internal to each call to to the Service#main method.
##
##   The main loop will not begin in that thread, until after the
##   service's #configure method has returned.
##
##   The #main method in a subclass of `Service` should call
##   `super(...)` i.e calling Service#main, there providing a new
##   ServiceContext object and a custom block in the call to
##   `super`. This block should accept a single argument, the main loop
##   thread. It generally can be assumed that the thread will be in a
##   running state, when received to the block.
##
##   The call to `super` will initialize the main loop for the service,
##   using sources initialized under #configure. The main loop will call
##   the block with the main thread initialized via #context_main, in
##   effect running until the block provided to `super(...)` has returned.
##
##   The block provided to `super(...`) should implement any
##   _Application Background Logic_ for the service. This would be
##   independent to any logic implemented via callbacks or framework
##   events in the service main loop.
##
##   After the block provided to Service#main returns, the main loop on
##   the Service will return, thus ending the runtime of the thread in
##   which the main loop was initailized.
##
##   If no block is provided to Service#main, the service's main loop
##   will not be run.
##
## - Service#main can be called more than once, within any one or more
##   consecutive threads, insofar as a new ServiceContext object is
##   provided in each call to Service#main.
##
## - FIXME add support for defining custom interrupt handlers in the
##   #main thread, such as in DispatchTest. Consider adding the INT
##   handler as a default.
##

class Service

  module Constants
    GIO_COND_READ ||= (GLib::IOCondition::IN |
      GLib::IOCondition::HUP |
      GLib::IOCondition::ERR)
    GIO_COND_WRITE ||=  (GLib::IOCondition::OUT |
      GLib::IOCondition::HUP |
      GLib::IOCondition::ERR)
    GIO_COND_RW ||= (GIO_COND_READ | GIO_COND_WRITE)
  end

  class << self

    ## Return the numeric representation of a `G_PRIORITY_<arg>`
    ## value
    ##
    ## The following symbolic arg values are supported:
    ## - `:high`
    ## - `:default`
    ## - `:high_idle`
    ## - `:default_idle`
    ## - `:low`
    ##
    ## For a symbol or string representation of a GLib::Source priority,
    ## the arg may be provided in any combination of case. Internally,
    ## the string representation of any symbol or string arg will be
    ## transformed to upcase, before returning the value of a
    ## corresponding constant under the GLib module.
    ##
    ## For an integer arg, the value itself will be returned as denoting
    ## a GLib::Source priority
    ##
    ## @param arg [String, Symbol, Integer]
    ##
    ## @see #map_idle_source, #map_fd_source, #map_timeout_source,
    ##      #map_seconds_timeout_source, #map_child_watch_source
    ## @see #configure_source
    def source_priority_int(arg)
      case arg
      when Integer
        arg
      when Symbol, String
        name = "PRIORITY_".freeze + arg.to_s.upcase
        s = name.to_sym
        GLib.const_get(s)
      else
        raise ArgumentError.new("Unsupported arg syntax (#{arg.class}) #{arg.inspect}")
      end
    end



    ## Return the numeric representation of a GLib::IOCondition constant
    ##
    ## For a symbol or string representation of a GLib::IOCondition,
    ## the arg may be provided in any combination of case. Internally,
    ## the string representation of any symbol or string arg will be
    ## transformed to upcase, before returning the value of a
    ## corresponding constant under GLib::IOCondition.
    ##
    ## For an enumerable arg value, the return value will represent the
    ## _btiwse or_ of integer values for all symbol, string, or integer
    ## element in the enumeration.
    ##
    ## The following symbolic arg values are supported:
    ##
    ## `:read`, `:r`
    ## : _bitwise or_ of `:in`, `:err`, `:hup` values
    ##
    ## `:write`, `:w`
    ## : _bitwise or_ of `:out`, `:err`, `:hup` values
    ##
    ## `:read_write`, `:write_read`. `:rw`, `:wr`
    ## : _bitwise or_ of :read, :write values
    ##
    ## `:in`, `:out`, `:pri`, `:err`, `:hup`, `:nval`
    ## : correspnding to e.g `G_IO_<arg>` e.g `G_IO_IN`
    ##
    def io_condition_int(arg)
      case arg
      when :read, :r
        return GIO_COND_READ
      when :write, :w
        return GIO_COND_WRITE
      when :rw, :read_write, :wr, :write_read
        return GIO_COND_RW
      when Symbol, String
        name = arg.to_s.upcase
        s = name.to_sym
        return GLib::IOCondition.const_get(s)
      when Integer
        return arg
      when Enumerable
        ret = 0
        arg.each do |cond|
          ret = ret | io_condition_int(cond)
        end
        return ret
      else
        raise ArgumentError.new("Unsupported arg syntax (#{arg.class}) #{arg.inspect}")
      end
    end ## io_condition_int
  end ## class << self

  attr_reader :logger
  self.extend Forwardable
  def_delegators(:@logger, :debug, :error, :fatal, :info, :warn)

  def initialize(logger: PebblApp::Support::ServiceLogger.new)
    @logger = logger
  end

  def debug_event(context, tag)
    if $DEBUG && context.respond_to?(:log_event)
      context.log_event(tag)
    end
  end

  ## an adaptation after `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
  def main(context = ServiceContext.new(), &block)
    debug "main"

    debug "Init locals"
    ## Initialize and hold a mutex during configuration and application runtime
    main_mtx = context.main_mtx
    ## using a separate mutex for blocking the main loop
    ## during event source configuration
    conf_mtx = context.conf_mtx
    main_thr = false

    begin
      conf_mtx.lock
      debug "Configure dispatch for work"

      begin
        ## configure event sources for this instance of the implementing class
        self.configure(context)
        debug "Call for main thread"
        main_thr = context_main(context)
      rescue
        debug_event(context, $!)
        main_thr.exit if main_thr
        return false
      end

      ## yield to the provided block, outside of the main event loop
      ##
      ## after this section returns, the main loop will exit
      main_mtx.synchronize do
        conf_mtx.unlock
        block.yield(main_thr) if block_given?
      end ## main_mtx

      # context.unref # no unref needed here
      main_thr.join
      return true
    end ## conf_mtx
  end

  ## configure a GLib::Source object for dispatch within the main event
  ## loop of the provided context.
  ##
  ## The source's callback will be set to a block that yields the
  ## _context_ to the _callback_ provided to this method.
  ##
  ## The source's _priority_ will be set to the priority value provided.
  ##
  ## Lastly, the source will be added to the context.
  ##
  ## This method is used by the following methods, for initializing each
  ## correponding kind of GLib::Source object
  ## - #map_idle_source
  ## - #map_fd_source
  ## - #map_timeout_source
  ## - #map_seconds_timeout_source
  ## - #map_child_watch_source
  ##
  ## @param context [ServiceContext] the context for the new source object
  ##
  ## @param source [GLib::Source, GLib::PollFD] the source to add to the
  ##  context
  ##
  ## @param priority [Symbol, String, Integer] priority to set as the
  ##  GLib::Source#priority for the source object. A symbol or
  ##  string value will be translated to an integer value, using
  ##  source_priority_int
  ##
  ## @param remove_on_nil [boolean] If true, the source will be
  ##  removed from the context if the callback yields
  ##  GLib::Source::REMOVE i.e yielding nil.
  ##
  ##  If a non-falsey value, the source will not be removed from the
  ##  context if yielding nil.  This behavior may be overriden within the
  ##  callback, if the callback yields a nil value via `return nil`
  ##
  ## @param callback [Proc] the block for the callback. The context will
  ##  be yielded to the block, in each iteration of the main event loop.
  ##  Any `return` call in the callback will return to a lambda form
  ##  encapsulating the callback block.
  def configure_source(context, source,
                       priority = GLib::PRIORITY_DEFAULT,
                       remove_on_nil = false,
                       callback)
    ## set the callback for the source, using a lambda proc.
    ##
    ## 'return' will be a valid call, within the callback proc
    if ! callback
      raise ArgumentError.new("No callback provided")
    end
    ## lambda procs will allow for return from within the callback block.
    if remove_on_nil
      lmb = lambda {
        callback.yield(context)
      }
    else
      lmb = lambda {
        callback.yield(context)
        GLib::Source::CONTINUE
      }
    end
    source.set_callback(&lmb)

    source.priority = self.class.source_priority_int(priority)
    ## add the source and its callback to the provided main context
    source.attach(context)
    return source
  end

  ## initialize a GLib::Idle kind of GLib::Source for a provided
  ## ServiceContext
  ##
  ## returns the new GLib::Idle source, as added to the context
  ##
  ## @param context (see #configure_context)
  ##
  ## @param priority (see #configure_context)
  ##
  ## @param remove_on_nil (see #configure_source)
  ##
  ## @param callback (see #configure_source)
  ##
  def map_idle_source(context, priority: :default_idle,
                      remove_on_nil: false, &callback)
    ## TBD extending map_idle_source for iVty -> IRB
    ## - starting with vtytest, create a new Vte::Pty for running IRB
    ##   in the same process (limitations include: Only available for
    ##   IRB on the same machine as the Vty app. usage cases include:
    ##   available for initial prototyping for iVty support using IRB)
    ## - for IRB in a separate process with iVty: Extending irb, create
    ##   a socket for "back channel" eval with IRB, using some json
    ##   protocol for communicating with IRB. This socket may exist
    ##   on a remote host, if the IRB PTY was initialized e.g via 'ssh -t'
    ## - for any "calls to irb", the same-process instance and the
    ##   other-process instance should be accessed with a modular API
    ##   where the location of the "receiving IRB" would be orthogonal
    ##   to the procedures for run/eval in IRB
    debug "adding idle source for context"
    debug_event(context, __method__)

    src = GLib::Idle.source_new
    configure_source(context, src, priority, remove_on_nil, callback)
    return src
  end


  ## Initialize a new GLib::PollFD source for the provided context
  ##
  ## @param context (see #configure_context)
  ##
  ## @param fd [IO, Integer] an IO stream or literal file
  ## descriptor value. If an IO object is provided, the IO must have a
  ## non-nil IO#fileno
  ##
  ## @param priority (see #configure_context)
  ##
  ## @param remove_on_nil (see #configure_source)
  ##
  ## @param callback (see #configure_source)
  def map_fd_source(context, fd,
                    poll: Const::GIO_COND_READ, ret: poll,
                    priority: :default,
                    &callback)
    debug "adding fd source for context"
    debug_event(context, __method__)

    filedes = (IO === fd) ? fd.fileno : fd
    src = GLib::PollFD.new(filedes, poll, ret)
    configure_source(context, src, priority, callback)
    return src
  end


  ## Initialize a new GLib::Timeout (timer) kind of GLib::Source for the
  ## provided context, with the timer source activating for a provided
  ## number of miliseconds.
  ##
  ## @param context (see #configure_context)
  ##
  ## @param ms (Number) number of miliseconds in the activation of the
  ## timeout source
  ##
  ## @param priority (see #configure_context)
  ##
  ## @param remove_on_nil (see #configure_source)
  ##
  ## @param callback (see #configure_source)
  ##
  ## @see #map_seconds_timeout_source
  def map_timeout_source(context, ms,
                         priority: :default,
                         &callback)
    ## TBD usage testing towards an async, sleep/call kind of idle source
    ## (single use, non-blocking - create a thread, then yield to the
    ## callback after sleep if non-cancellable/not cancelled. TBD storage
    ## for the thread, after the caller returns)
    debug "adding timeout (miliseconds) source for context"
    debug_event(context, __method__)
    ## TBD non-blocking, async timer => action actuation,
    ## independent of the main event loop
    src = GLib::Timeout.source_new(ms)
    configure_source(context, src, priority, callback)
    return src
  end


  ## Initialize a new GLib::Timeout (timer)_ kind of GLib::Source for
  ## the provided context, activating for a provided number of seconds.
  ##
  ## @param context (see #configure_context)
  ##
  ## @param seconds (Number) number of seconds in the activation of the
  ## timeout source
  ##
  ## @param priority (see #configure_context)
  ##
  ## @param remove_on_nil (see #configure_source)
  ##
  ## @param callback (see #configure_source)
  ##
  ## @see #map_timeout_source
  def map_seconds_timeout_source(context, seconds,
                                 priority: :default,
                                 &callback)
    debug "adding timeout (seconds) source for context"
    debug_event(context, __method__)

    src = GLib::Timeout.source_new_seconds(seconds)
    configure_source(context, src, priority, callback)
    return src
  end


  ## @param context (see #configure_context)
  ##
  ## @param priority (see #configure_context)
  ##
  ## @param remove_on_nil (see #configure_source)
  ##
  ## @param callback (see #configure_source)
  def map_child_watch_source(context, pid,
                             priority: :default,
                             &callback)
    debug "adding child watch source for context"
    debug_event(context, __method__)

    ## FIXME add a main-looop exit handler to call
    ##  GLib::Spawn.close_pid
    ## or ensure that it's added to the docs that that should be called
    ## in the callback, after the process exits
    src = GLib::ChildWatch.source_new(pid)
    configure_source(context, src, priority, callback)
    return src
  end

  ## Configure all sources for the service's context.
  ##
  ## @abstract This is a prototype method. A configure method should be
  ## implemented in any subclass, independent of this method. If reached
  ## when $DEBUG is true, this method will emit a warning for purpose of
  ## debug.
  ##
  ## The #configure method in the implementing class will be called
  ## before the main loop begins iteration.
  ##
  ## Implementations may call e.g #map_idle_source in #configure, to
  ## define a callback block to be run in each iteration of the main
  ## loop.
  ##
  ## A source priority may also be configured on any sources added in
  ## #configure, e.g `source.priority = GLib::PRIORITY_DEFAULT`
  ##
  ## Soures added to the context will be applied in each iteration of
  ## the main loop.
  ##
  ## @see #map_idle_source
  ## @see #map_fd_source
  ## @see #map_timeout_source
  ## @see #map_seconds_timeout_source
  ## @see #map_child_watch_source
  def configure(context)
    Kernel.warn("prototype #{__method__} method reached for %p in %s" %
                [context, self], uplevel: 0) if $DEBUG
  end

  ## iterate once, for a loop on this context
  ##
  ## This method will be called for each main loop iteration, within the
  ## thread running the loop on the main context. That main loop thread
  ## will have been created via #context_main.
  ##
  ## Within the thread created in #context_main, this method will be
  ## called in a begin/rescue block for StandardError exceptions. On
  ## event of receiving an error not handled within the #context_dispatch
  ## method or within some source callback, the begin/rescue block for
  ## #context_main will exit the main loop and return from the main loop
  ## thread.
  ##
  ## This method can be overridden and/or extended, to provide
  ## custom framework dispatch in the service main event loop.
  ##
  def context_dispatch(context)
    context.iteration(context.blocking)
    ##
    ## an additional call for dispatching to GTK e.g
    ##
    ## main_iteration_do returns true if Gtk.main_quit was called
    ##
    ## NB applications may call Gtk.main_quit on app.quit
    ##
    # if Gtk.main_iteration_do(false); return; end
    ##
    ## TBD reentrancy for Gtk.main_iteration[_do] after error in some
    ## previous Gtk.main_iteration[_do]
  end

  ## handle an error received during main event loop dispatch.
  ##
  ## Once this method has been called, no further GLib::Source
  ## implementations will be handled in the main event loop. After this
  ## method returns, the main event loop thread will exit.
  ##
  ## This method will set the context's _cancellation_ object to a
  ## _cancelled_  state, then storing the exception as the _cancellation
  ## reason_ in cancellation object.
  ##
  ## This method may be overriden to provide any custom application
  ## logic on event of an error received in the main event loop. For
  ## example, if an application may require that the main event loop
  ## would continue after a known exception, the exception may be
  ## handled in the overriding method without setting a cancelled state
  ## to the context's cancellation object.
  ##
  ## Generally, any known exceptions should be handled internal to each
  ## source callback.
  ##
  ## @param context [ServiceContext] the context of the main event loop
  ## @param exception [StandardError] the exception received
  ## @see ServiceContext#cancellation
  ## @see ServiceCancellation#reason
  ## @see #map_idle_source
  def context_error(context, exception)
    ## the following should result in the main loop returning before any
    ## subsequent context#iteration call
    context.cancellation.cancel
    ## the next call is simply informative
    context.cancellation.reason = exception
    debug_event(context, exception)
  end

  ## an adaptation after `thread1_main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
  ##
  ## called under #main
  ##
  ## returns a thread that will run the main event loop, beginning not
  ## until #configure returns, then running until the block provided to
  ## #main returns.
  ##
  def context_main(context)
    main_mtx = context.main_mtx
    conf_mtx = context.conf_mtx

    Thread.new do
      debug "main context thread begins"
      debug_event(context, :main_run)

      main = GLib::MainLoop.new(context, false) ## false => not run
      @main = main

      ## hold on conf_mtx, while caller is configuring event sources
      conf_mtx.synchronize do
        Thread.exit if context.cancellation.cancelled?

        if ! context.acquire
          Kernel.warn("Unable to acquire context #{context} for #{self} thread #{Thread.current}",
                      uplevel: 0)
          Thread.exit
        end

        ## Iterate in the event loop until the main_mtx can be held, or
        ## until the cancellation object for this context is cancelled
        ##
        ## Once the mutex can be held here: Cleanup; Release the mutex
        ## if held, and return
        debug_event(context, :main_iterate)
        catch(:cancelled) do |tag|
          while ! main_mtx.try_lock
            if context.cancellation.cancelled?
              ## lock not held, but cancellation is indicated
              throw tag
            else
              context_dispatch(context)
            end
          end
        end
        begin
          debug_event(context, :main_context_end)
          debug "end of main context"
          ## cleanup
          main.quit
          # main.unref # no unref needed here
        ensure
          ## own thread may not have held the mutex, when this
          ## is reached under cancellation
          main_mtx.unlock if main_mtx.owned?
        end
      end ## conf_mtx
    end ## thread
  end

end ## Service

end ## PebblApp::GtkSupport scope
