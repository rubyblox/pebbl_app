## GMain version 1.2.0

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
  class GMainCancellation < Gio::Cancellable
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

  ## A Proxy mixin for GMain context impelementations
  ##
  ## This mixin provides common storage and initialization behaviors for
  ## each of the GMainContext and DefaultContext classes.
  ##
  ## Applications using GTK may generally make use of the DefaultContext
  ## class. This class may provide some compatibility with handling for
  ## GLib::MainContext data in the GTK main event loop
  ##
  ## Applications using GLib directly may make use of the GMainContext
  ## class, such that provides a subclass of GLib::MainContext
  ##
  module ContextProxy

    ## Initialize method forwarding for the `cancellation` value in this
    ## implementation.
    def self.included(whence)
      whence.extend Forwardable
      whence.def_delegators(:@cancellation, :cancel, :cancelled?, :reset)
    end

    ## attribute accessors for common mutex, condition variable, and
    ## cancellation data used in each context class
    attr_reader :main_mtx, :main_cv, :cancellation

    ## trivial barrier flag
    attr_accessor :configured


    def initialize()
      super()
      @configured = false

      ## in application with GMain subclasses, the main loop will run
      ## in a thread separate to the main thread, i.e the thread in which
      ## the GLib::MainContext was configured
      ##
      ## the main_mtx and main_cv may are used generally for
      ## synchronization between the #main thread and the main loop
      ## thread
      @main_mtx = Mutex.new
      @main_cv = ConditionVariable.new
      @cancellation = GMainCancellation.new
      ## used in GMain#context_dispatch
    end


    def cancel(reason)
      @cancellation.cancel(reason)
    end
  end

  ## A ContextProxy implementation extending GLib::MainContext
  ##
  ## For applications using Gtk, see also: DefaultContext
  class GMainContext < GLib::MainContext
    include ContextProxy

    ## Return this context
    ##
    ## This method is generally compatibile with DefaultContext#context
    def context()
      return self
    end
  end

  ## A ContextProxy implementation forwarding to a default
  ## GLib::MainContext
  ##
  ## This class' constructor will use the GLib::MainContext.default that
  ## was active at the time when the constructor method was called for
  ## this DefaultContext.
  ##
  ## The behaviors are unspecified if an application changes the default
  ## GLib::MainContext at any time after a DefaultContext is initailized.
  ##
  ## This class has been implemented with a goal of compatibility with
  ## the Gtk main event loop.
  ##
  ## @see GMainContext
  class DefaultContext
    include ContextProxy

    ## Return the forwarded GLib::MainContext for this instance
    attr_reader :context

    self.extend Forwardable
    GLib::MainContext.instance_methods(false).each do |mtd|
      def_delegator(:@context, mtd)
    end


    def initialize()
      super()
      ## NB the value returned by GLib::MainContext.default
      ## may not be consistent with a single process session
      ##
      ## This is part of a workaround, absent of an API onto
      ##  g_main_context_push_thread_default
      @context = GLib::MainContext.default
    end

  end ## DefaultContext

  ## This class is an adaptation after [the Main Contexts tutorial]
  ## (https://developer.gnome.org/documentation/tutorials/main-contexts.html)
  ## in the [GNOME Developer Documentation]
  ## (https://developer.gnome.org/documentation/index.html).
  ##
  ## This implementation uses GLib::MainContext support in [Ruby-GNOME]
  ## (https://github.com/ruby-gnome/ruby-gnome/)
  ##
  ## The GMain/GMainContext framework implements a cancellable main
  ## event loop model for GLib applications.
  ##
  ## **Examples**
  ##
  ## An example is avaialble in the file sandbox/service-example.rb under
  ## the project root directory
  ##
  ## **Notes**
  ##
  ## - This `GMain` implementation requires a `GMainContext`. The
  ##   `GMainContext` class extends GLib::MainContext as to
  ##   provide a mutex objects and condition variable for
  ##   synchronization in the _configure_  and _application_ sections of
  ##   the GMain#main method.
  ##
  ## - Applications defining a subclass e.g GMainExt on GMain may
  ##   extend the GMainContext class, e.g as GMainContextExt. This
  ##   may be of use, for instance to provide a custom API in the
  ##   GMainContextExt implementation. The custom API on the
  ##   GMainContextExt may be of use, for example, in the GMainExt's
  ##   #map_sources method as when configuring sources and callbacks
  ##   for the GMainContextExt, and may be of use in the #main method of
  ##   the GMainExt, for general application purposes.
  ##
  ##   The DispatchTest source code (service-example.rb) may provide an
  ##   example of this extensional logic.
  ##
  ## - An application extending `GMain` should provide at least a
  ##   #map_sources method and a #main method.
  ##
  ##   The #map_sources method should add any one or more GLib::Source
  ##   objects to the GMainContext provided to the method, also
  ##   configuring any properties on each source, e.g source priority.
  ##   Each GLib::Source object should provide a custom callback, such that
  ##   will be available on activation of the source, in each iteration
  ##   of the main loop initialized via #context_main.
  ##
  ##   A GLib::Source object can be initialized and configured to a
  ##   GMainContext, using  GMain.map_idle_source and other
  ##   GLib::Source-initializing class methods on GMain.
  ##
  ##   The #main method in a subclass of `GMain` should call
  ##   `super(...) do |thread| ...` i.e calling GMain#main, there
  ##   providing a new GMainContext object and a custom block in the
  ##   call to `super`.
  ##
  ##   The block provided to GMain#main should accept a single
  ##   argument. The block will receive the main loop thread
  ##   initialized for the call to GMain#main.
  ##
  ##   The call to GMain#main will initialize the main loop for the
  ##   GMain. This main loop will operate on the GMainContext for the
  ##   call to #main and all sources initialized under #map_sources.
  ##
  ##   It can be assumed that the main loop's thread will be in a running
  ##   state, when received to the block provided to GMain#main.
  ##   Internally, the thread will wait  until the #map_sources method on
  ##   the implementing class has returned, before beginning iteration in
  ##   the GMain main loop.
  ##
  ##   The block provided to `super(...`) should implement any
  ##   _Application Background Logic_ for the GMain object. This would be
  ##   independent to any logic implemented via callbacks or any other
  ##   framework events in the GMain main loop.
  ##
  ##   It should be assumed that the GMain main loop may have begun
  ##   iteration, once the block provided to GMain#super is reached
  ##
  ## - The GMain main loop will run within a thread returned by
  ##   #context_main. The main loop will not begin in this thread until
  ##   after the GMain#map_sources method has returned. The main loop
  ##   will continue iteration until the cancellation for the
  ##   GMainContext of the main loop has been set to a cancelled state,
  ##   or if the main loop's thread exits on event of error
  ##
  ## - GMain#main can be called more than once, within any one or more
  ##   consecutive threads.
  ##
  ##   A new GMainContext object should be provied for each consecutive
  ##   call to GMain#main
  ##
  class GMain

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
      ## - GMain.map_idle_source
      ## - GMain.map_fd_source
      ## - GMain.map_timeout_source
      ## - GMain.map_seconds_timeout_source
      ## - GMain.map_child_watch_source
      ##
      ## @param context [GMainContext] the context for the new source object
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
        if DefaultContext === context
          ## using the forwarded context, if it was not received here
          context = context.context
        end

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

        source.priority = GMain.source_priority_int(priority)
        ## add the source and its callback to the provided main context
        source.attach(context)
        return source
      end

      ## initialize a GLib::Idle kind of GLib::Source for a provided
      ## GMainContext
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
        AppLog.debug "adding idle source for context #{context}" if $DEBUG
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
      ##
      ## @see GMain.io_condition_int
      def map_fd_source(context, fd,
                        poll: Const::GIO_COND_READ, ret: poll,
                        priority: :default,
                        &callback)
        AppLog.debug "adding fd source for context" if $DEBUG
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
      ## @see map_seconds_timeout_source
      def map_timeout_source(context, ms,
                             priority: :default,
                             &callback)
        AppLog.debug "adding timeout (miliseconds) source for context" if $DEBUG
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
      ## @see map_timeout_source
      def map_seconds_timeout_source(context, seconds,
                                     priority: :default,
                                     &callback)
        AppLog.debug "adding timeout (seconds) source for context" if $DEBUG

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
        AppLog.debug "adding child watch source for context" if $DEBUG
        src = GLib::ChildWatch.source_new(pid)
        configure_source(context, src, priority, callback)
        return src
      end

    end ## class << self

    ## @private main context for this GMain, or nil/false if not running
    attr_accessor :running

    def debug_event(context, tag)
      ## The original use for this method was in inspecting the event
      ## flow in the sandbox/service-example.rb demonstration
      ##
      ## This method has been retained in the interest of it being any
      ## potential use for later debugging, such as for any extensions
      ## on this main context implementation.
      ##
      ## This method should generally not be reached unless the
      ## application is running under $DEBUG.
      ##
      ## This method will not be called on every iteration of the main
      ## loop under $DEBUG, but may be called a small number of times
      ## before iteration in the main loop.
      ##
      ## If an extending class would need to record every iteration of
      ## the main loop, the extending class should be able to implement
      ## the behavior with an extension on the context_dispatch method
      ## in some subclass of ContextProxy - i.e as a subclass of
      ## DefaultContext or of GMainContext. An instance of the extending
      ## context class should then be produced with the context_new
      ## method in the class extending GMain
      if context.respond_to?(:log_event)
        context.log_event(tag)
      end
    end

    ## Return a new GMainContext instance.
    ##
    ## See also: DefaultContext
    def context_new()
      GMainContext.new()
    end

    def debug(*args)
      AppLog.debug(*args) if $DEBUG
    end

    ## an adaptation after `main` in
    ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
    def main(context = context_new, &block)

      if @running
        critical("#{self.class}##{__method__} already running: #{@running}")
        return -1
      end

      debug "main"

      debug "Init locals"
      ## Initialize and hold a mutex during configuration and application runtime
      main_mtx = context.main_mtx
      ## condition variable for synchronization after map_sources
      main_cv = context.main_cv
      main_thr = false

      main_mtx.synchronize do
        begin
          debug "Configure sources"
          ## configure event sources for this instance of the implementing class
          self.map_sources(context)
          context.configured = true
          ## the context_main thread will be created
          ## after this mutex is released
          # main_thr = context_main(context)
        rescue
          debug_event(context, $!) if $DEBUG
          context.cancel($!)
          main_thr.exit if main_thr
          return false
        ensure
          debug "cv broadcast"
          main_cv.broadcast
        end
      end ## main sync for initial conf

      @running = context

      cancellation = context.cancellation
      cancellation.signal_connect_after("cancelled") do
        if (running = @running) && (running == context)
          @running = false
        end
      end

      ## start the main context thread
      ##
      ## starting the main thread here, this may obviate any need for
      ## the previous mutex.synchronize
      main_thr = context_main(context)

      ret = false

      ## yield to the provided block
      ##
      ## the main loop may have begun iteration,
      ## parallel to this section
      begin
        catch(:main) do
          AppLog.debug "yielding to block in main thread"
          ret = block.yield(main_thr) if block_given?
        end
      ensure
        ## cleanup after the main loop
        context.cancellation.cancel
        main_mtx.synchronize do
          ## this will run only after the main loop has released main_mtx.
          ##
          debug "post-loop in main thread"
          main_thr.join
        end
      end

      debug "returning in main thread"
      return ret
    end

    ## Configure all sources for the GMain's context.
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
    ## @see map_idle_source
    ## @see map_fd_source
    ## @see map_timeout_source
    ## @see map_seconds_timeout_source
    ## @see map_child_watch_source
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
    ## custom framework dispatch in the GMain main event loop.
    ##
    ## If an overriding method has detected that the main loop should
    ## exit, the method may throw to the :main_iterate tag. After the
    ## throw, the main loop thread will return.
    ##
    def context_dispatch(context)
      context.iteration(!context.cancellation.cancelled?)
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
    ## @param context [GMainContext] the context of the main event loop
    ## @param exception [StandardError] the exception received
    ## @see GMainContext#cancellation
    ## @see GMainCancellation#reason
    ## @see #map_idle_source
    def context_error(context, exception)
      ## the following should result in the main loop returning before any
      ## subsequent context#iteration call
      context.cancel(exception)
      debug_event(context, exception) if $DEBUG
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
      main_cv = context.main_cv

      Thread.new do
        debug "main context thread begins" if $DEBUG
        debug_event(context, :main_run) if $DEBUG

        if ! context.acquire
          Kernel.warn("Unable to acquire context #{context} \
in #{self} thread #{Thread.current}", uplevel: 0)
          debug_event(context, :main_acquire_failed) if $DEBUG
          ## exit before any mutex barriers
          Thread.exit
        end

        main_mtx.synchronize do
          debug "main loop pre-cv wait" if $DEBUG
          cv_reached = false
          if ! context.configured
            ## block for configuration section if not configured
            cv_reached = main_cv.wait(main_mtx)
            debug "reached cv #{cv_reached.inspect}" if $DEBUG
          end

          cancellation = context.cancellation

          debug "main loop post-cv wait" if $DEBUG
          ## run until cancelled
          begin
            ## iterating in the event loop until the cancellation
            ## object for this context is cancelled.
            debug_event(context, :main_iterate) if $DEBUG
            catch(:main_iterate) do |tag|
              while self.running
                if cancellation.cancelled?
                  throw tag
                else
                  ## dispatch for this iteration of the main loop
                  context_dispatch(context)
                end
              end
            end
          ensure
            debug_event(context, :main_context_end) if $DEBUG
            debug "end of main context" if $DEBUG
            ## cleanups
            context.release
            main_cv.broadcast if cv_reached
          end
        end ## conf_mtx
      end ## thread
    end ## context_main

    def quit(reason = :quit)
      if (running = @running)
        ## the context should be of a type ContextProxy, or otherwise
        ## responding to a cancel(reason) call
        running.cancel(reason)
      else
        false
      end
    end

  end ## GMain

end ## PebblApp::GtkFramework scope
