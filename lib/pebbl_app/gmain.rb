## GApp version 1.2.0

require 'pebbl_app'
require 'pebbl_app/gtk_framework'

require 'forwardable'

require 'glib2'
require 'gio2'

module PebblApp

  class SynchronizationError < RuntimeError
  end


  ## Cancellable object class for asynchronous applications.
  ##
  ## This class uses a mutex internally, to synchronize the #reset and
  ## cancel methods within the Ruby application environment.
  ##
  ## No locking behavior is specified if this object is #cancelled or
  ## #reset in any call external to the Ruby application environment.
  ##
  class GAppCancellation < Gio::Cancellable
    ## informative tag for a cancellation event e.g the #reason may be
    ## set to an exception object
    attr_reader :reason

    def initialize()
      super()
      @mtx = Mutex.new
      self.reset
    end

    ## call a block within a scope in which the cancellation mutex for
    ## this object is owned by the current thread.
    ##
    ## After ensuring that the mutex is owned by this thread or newly
    ## acquired, the mutex will be yielded to the block.
    ##
    ## If the mutex was not already held in the current thread, the
    ## mutex will be unlocked on exit from the block
    ##
    ## If the mutex is not already owned or cannot be acquired, raises a
    ## SynchronizationError
    ##
    ## This method is used in #reset and #cancel on this Ruby class
    def with_cancel_lock(&block)
      ## Implementation note:
      ## - mutex.synchronize, mutex.lock cannot be called within a signal
      ##   trap context
      ## - mutex.try_lock does not illustrate the same limitation.
      ## - also checking for @mtx.owned here, albeit in no complete
      ##   emulation of recursive locking
      if (thr_owned = (mtx = @mtx).owned?) || mtx.try_lock
        begin
          block.yield(mtx)
        ensure
          mtx.unlock if (!thr_owned && mtx.owned?)
        end
      else
        raise SynchronizationError("Unable to acquite mutex on #{self}")
      end
    end

    ## reset this Cancellable object, with the object's cancellation mutex held
    ##
    ## @see #with_cancel_lock
    def reset()
      with_cancel_lock do
        super()
        @reason = false
      end
    end

    ## ensure that this Cancellable object is cancelled, also setting a
    ## reason for the cancellation.
    ##
    ## If the object is already cancelled: No subsequent cancellation will
    ## be applied unless recancel holds a truthy value.
    ##
    ## If the object is already cancelled and no subsequent cancellation
    ## is applied, the #reason for the cancellation will not be altered.
    ##
    ## @param reason [any] Reason for the cancellation, if available
    ##
    ## @param recancel [boolean] True to re-cancel and reset #reason when
    ##  already cancelled
    ##
    ## @see #with_cancel_lock
    def cancel(reason = false, recancel = false)
      with_cancel_lock do
        if !cancelled? || recancel
          super()
          @reason = reason
        end
      end
    end
  end

  ## see GApp
  class GAppContext < GLib::MainContext

    attr_reader :conf_mtx, :main_mtx, :cancellation

    ## If true (the default) then the GApp#context_dispatch method
    ## should block for source availability during main loop iteration
    attr_reader :blocking

    def initialize(blocking: true)
      super()
      ## in application with GApp subclasses, the main loop will run
      ## in a thread separate to the main thread, i.e the thread in which
      ## the GLib::MainContext was configured
      ##
      ## the conf_mtx value here is applied to prevent the loop from
      ## dispatching events until after all sources have been configured
      ## for the context
      @conf_mtx = Mutex.new
      @main_mtx = Mutex.new
      @cancellation = GAppCancellation.new
      ## used in GApp#context_dispatch
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
  ## The GApp/GAppContext framework implements a cancellable main
  ## event loop model for GLib applications.
  ##
  ## **Examples**
  ##
  ## An example is avaialble in the file sandbox/service-example.rb under
  ## the project root directory
  ##
  ## **Notes**
  ##
  ## - This `GApp` implementation requires a `GAppContext`. The
  ##   `GAppContext` class extends GLib::MainContext as to
  ##   provide mutex objects for synchronization in the _configure_  and
  ##   _application_ sections of the GApp#main method.
  ##
  ## - Applications defining a subclass e.g GAppImpl on GApp may
  ##   extend the `GAppContext` class, e.g as GAppImplContext. This
  ##   may be of use, for instance to provide a custom API in the
  ##   GAppImplContext. The custom API on the GAppImplContext may be
  ##   used, for example, in the SeviceImpl's #map_sources and #main methods,
  ##   for configuring sources/callbacks for the  GAppImplContext and
  ##   for any runtime logic in the #main thread.
  ##
  ##   The DispatchTest source code may provide an example of this
  ##   extensional logic.
  ##
  ## - An application extending `GApp` should provide at least a
  ##   #map_sources method and a #main method.
  ##
  ##   The #map_sources method should add any one or more GLib::Source
  ##   objects to the GAppContext provided to the method, also
  ##   configuring any properties on each source, e.g source priority.
  ##   Each GLib::Source object should provide a custom callback, such that
  ##   will be available in each iteration of the main loop initialized via
  ##   #context_main. This can be accomplished with #map_idle_source and
  ##   other Source-initializing methods on GApp.
  ##
  ##   The service main loop will run within a thread returned by
  ##   #context_main. The main loop will not begin in this thread, until
  ##   after the service's #map_sources method has returned.
  ##
  ##   The #main method in a subclass of `GApp` should call
  ##   `super(...) do |thread| ...` i.e calling GApp#main, there
  ##    providing a new GAppContext object and a custom block in the
  ##    call to `super`. This block should accept a single argument, the
  ##    main loop thread initialized for the call to GApp#main.
  ##
  ##   The call to GApp#main will initialize the main loop for the
  ##   service. This main loop will operate on the GAppContext for the
  ##   call to #main and all sources initialized under #map_sources.
  ##
  ##   It can be assumed that the main loop's thread will be in a running
  ##   state, when received to the block provided to GApp#main.
  ##   Internally, the thread will wait  until the #map_sources method on
  ##   the implementing class has returned, before beginning iteration in
  ##   the service main loop.
  ##
  ##   The block provided to `super(...`) should implement any
  ##   _Application Background Logic_ for the service. This would be
  ##   independent to any logic implemented via callbacks or any other
  ##   framework events in the service main loop.
  ##
  ##   After the block provided to GApp#main returns, the main loop
  ##   on the extending class will return, thus ending the runtime of the
  ##   main loop's thread.
  ##
  ##   If no block is provided to GApp#main, the service's main
  ##   loop will not be run.
  ##
  ## - GApp#main can be called more than once, within any one or more
  ##   consecutive threads. A new GAppContext object could be provided
  ##   in each call to GApp#main.
  ##
  ## - Once dispatching on event soures, the main loop created via
  ##   #context_main will continue until the _cancellation_ object for the
  ##   GAppContext (provided in FIXME needs illustration) has been set
  ##   to a _cancelled_ state, or until any uncaught error occurs during
  ##   event dispatch. After a cancellcation event, the main loop thread
  ##   will return normally. On event of error (FIXME needs docs)

  class GApp < App

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
      ## @see #map_sources_source
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

    ## A GApplication for this GApp
    attr_reader :gapp

    ## Logger for this GApp
    attr_reader :logger

    self.extend Forwardable
    def_delegators(:@logger, :debug, :error, :fatal, :info, :warn)

    def initialize(logger: PebblApp::AppLog.new)
      ## NB this class does not provide  any #configure method
      ## for application config or any #gapp initialization
      @logger = logger
    end

    def debug_event(context, tag)
      if $DEBUG && context.respond_to?(:log_event)
        context.log_event(tag)
      end
    end

    def context_new()
      GAppContext.new()
    end

    ## an adaptation after `main` in
    ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
    def main(context: context_new, argv: ARGV, &block)
      debug "main"

      configure(argv: argv) ## also called from App#main
      nm = self.app_name
      GLib::set_application_name(nm)

      debug "Init locals"
      ## Initialize and hold a mutex during configuration and application runtime
      main_mtx = context.main_mtx
      ## using a separate mutex for blocking the main loop
      ## during event source configuration
      conf_mtx = context.conf_mtx
      main_thr = false

      begin
        conf_mtx.lock

        begin
          debug "Configure sources"
          ## configure event sources for this instance of the implementing class
          self.map_sources(context)
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
    ## @param context [GAppContext] the context for the new source object
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
    ## GAppContext
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

      src = GLib::ChildWatch.source_new(pid)
      configure_source(context, src, priority, callback)
      return src
    end

    ## Configure all sources for the service's context.
    ##
    ## @abstract This is a prototype method. A map_sources method should be
    ## implemented in any subclass, independent of this method. If reached
    ## when $DEBUG is true, this method will emit a warning for purpose of
    ## debug.
    ##
    ## The #map_sources method in the implementing class will be called
    ## before the main loop begins iteration.
    ##
    ## Implementations may call e.g #map_idle_source in #map_sources, to
    ## define a callback block to be run in each iteration of the main
    ## loop.
    ##
    ## A source priority may also be configured on any sources added in
    ## #map_sources, e.g `source.priority = GLib::PRIORITY_DEFAULT`
    ##
    ## Soures added to the context will be applied in each iteration of
    ## the main loop.
    ##
    ## @see #map_idle_source
    ## @see #map_fd_source
    ## @see #map_timeout_source
    ## @see #map_seconds_timeout_source
    ## @see #map_child_watch_source
    def map_sources(context)
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
    ## @param context [GAppContext] the context of the main event loop
    ## @param exception [StandardError] the exception received
    ## @see GAppContext#cancellation
    ## @see GAppCancellation#reason
    ## @see #map_idle_source
    def context_error(context, exception)
      ## the following should result in the main loop returning before any
      ## subsequent context#iteration call
      context.cancellation.cancel(exception)
      debug_event(context, exception)
    end

    ## an adaptation after `thread1_main` in
    ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
    ##
    ## called under #main
    ##
    ## returns a thread that will run the main event loop, beginning not
    ## until #map_sources returns, then running until the block provided to
    ## #main returns.
    ##
    def context_main(context)
      main_mtx = context.main_mtx
      conf_mtx = context.conf_mtx

      Thread.new do
        debug "main context thread begins"
        debug_event(context, :main_run)

        if ! context.acquire
          ## TBD probably not compatible with g_application_run, which
          ## acquires a main context internally, from some unspecified source
          Kernel.warn("Unable to acquire context #{context} \
in #{self} thread #{Thread.current}", uplevel: 0)
          debug_event(context, :main_acquire_failed)
          ## exit before any mutex barriers
          Thread.exit
        end

        main = GLib::MainLoop.new(context, false) ## false => not run
        # @main = main ## not recommended to store this outside of #main
        ## hold for conf_mtx, while caller is configuring event sources
        conf_mtx.synchronize do

          ## Iterate in the event loop until the main_mtx can be held, or
          ## until the cancellation object for this context is cancelled.
          ##
          ## Once the mutex can be held here: Cleanup; Release the mutex
          ## if held, and return
          debug_event(context, :main_iterate)
          catch(:main) do |tag|
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

  end ## GApp

end ## PebblApp::GtkFramework scope
