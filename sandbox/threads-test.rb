## Service version 1.0.1

if ! Kernel.const_defined?(:Gtk)
  if ! ENV['DISPLAY']
    Kernel.warn("No display", uplevel: 0)
    exit
  end
  require 'gtk3'
end


class ServiceContext < GLib::MainContext

  attr_reader :conf_mtx, :main_mtx, :cancellation

  def initialize()
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
    @cancellation = Gio::Cancellable.new
  end

end


## This class is an adaptation after [the Main Contexts tutorial]
## (https://developer.gnome.org/documentation/tutorials/main-contexts.html)
## in the [GNOME Developer Documentation]
## (https://developer.gnome.org/documentation/index.html).
##
## This implementation uses GLib context support in [Ruby-GNOME]
## (https://github.com/ruby-gnome/ruby-gnome/)
##
##
## **Example: DispatchTest**
##
## In the DispatchTest example, the class DispatchTest extends Service,
## there overriding the #configure and #main methods on Service
##
## The #main method in DispatchTest calls the superclass' #main method
## via `super`, there providing a custom ServiceContext instance and
## a local block to the `super` call. The block implements a custom
## application logic independent to the service main loop. This block
## will be called in the same thread as #main.
##
## In application with he #main method on Service, the DispatchTest
## event loop will exit, after control has exited the block provided to
## the Service #main method.
##
## The #configure method in the DispatchTest example will add a
## GLib::Idle kind of GLib::Source to the context object provided to the
## method.
##
## This #configure method uses #map_idle_source to add a callback on the
## the idle source and to add the source to the provided context. The
## #configure method then sets a source priority on the source object
## returned by #map_idle_source. In the DispatchTest example, the idle
## source's callback block will call the implementing class' `do_work`
## method. This callback should be reached in each normal iteration of
## the application's main loop.
##
## The `DispatchTest#main` method provides a five second wait in the
## local block, to simulate a duration in application runtime. Semantically,
## the implementation provides an example of event dispatch outside of a
## main application thread, using an extension on GLib::MainContext.
##
## The `main` method on `DispatchTest` produces some output on the
## standard error stream, for purpose of illustration in the test.
##
## Using the DispatchTest example:
## ~~~~
## require_relative 'thread-test.rb'
##
## # Initialize a new DispatchTest
## test = DispatchTest.new
##
## # call #main
## test.main
##
## # review the event log in the DispatchTest's data object
## test.data.work_log
##
## # call main again
## test.main
##
## # interrupt the main thread, such as with "Ctl-C"
## # under interactive eval (user input)
##
## # review the event log after interrupt
## test.data.work_log
##
##
## ~~~~
##
## Notes
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
## - An appplications extending `Service` should provide at least a
##   #configure method and a #main method.
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
##   `super`. This will initialize the main loop for the service, using
##   any sources initailized under #configure. The main loop will run
##   until the block provided to `super(...)` has returned.
##
##   The block provided to `super(...`) should implement any
##   _Application Background Logic_ for the service, independent to any
##   logic implemented via callbacks or framework events in the
##   service main loop.
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

  def debug(message)
    STDERR.puts message if $DEBUG
  end

  def debug_event(context, tag)
    if $DEBUG && context.respond_to?(:log_event)
      context.log_event(tag)
    end
  end

  ## an adaptation after `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
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
        block.yield if block_given?
      end ## main_mtx

      # context.unref # no unref needed here
      main_thr.join
      return true
    end ## conf_mtx
  end

  ## initialize a GLib::Idle source for a provided GLib::MainContext,
  ## creating a callback on that idle source as to dispatch
  ## to the provided block
  ##
  ## The callback will be called in each iteration of the main loop
  ## for the provided main context
  ##
  ## returns the new GLib::Idle source, as added to the context
  ##
  ## applications may set a source priority on the returned source
  ##
  def map_idle_source(context, &block)
    debug "dispatch setting callback"
    debug_event(context, :dispatched)

    src = GLib::Idle.source_new
    src.set_callback(&block)
    ## add the source and its callback to the provided main context
    src.attach(context)
    debug "callback set"
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
  ## the main loop. See #map_idle_source
  ##
  def configure(context)
    Kernel.warn("prototype #{__method__} method reached for %p in %s" %
                [context, self], uplevel: 0) if $DEBUG
  end

  ## iterate once, for a loop on this context
  ##
  ## called within the thread running the loop on the main context
  ##
  ## This method can be overridden and/or extended, to provide
  ## custom framework dispatch in the service main loop.
  ##
  def context_dispatch(context)
    context.iteration(false) ## do not block if no events available
    ##
    ## an additional call for dispatching to GTK e.g
    ##
    ## main_iteration_do returns true if Gtk.main_quit was called
    ## at least, if internal to the Gtk event loop dispatch
    ##
    # if Gtk.main_iteration_do(false); return; end
    ##
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

    thr = Thread.new do
      debug "... main thread begins"
      debug_event(context, :main_run)

      main = GLib::MainLoop.new(context, false) ## false => not run
      @main = main

      ## hold on conf_mtx, while caller is configuring event sources
      conf_mtx.synchronize do
        Thread.exit if context.cancellation.cancelled? ## should exit from here

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
          debug ".. end of main context"
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
    return thr
  end

end


class TestData
  attr_reader :work_log

  def initialize()
    super()
    @work_log = {}
  end

  def log_event(tag, time = Time.now)
    self.work_log[time] = tag
  end
end

class TestContext < ServiceContext
  attr_reader :data

  def initialize(data)
    super()
    @data = data
  end

  ## for purposes of test
  def log_event(tag)
    self.data.log_event(tag)
  end
end

## an inelegant adaptation after
## https://developer.gnome.org/documentation/tutorials/main-contexts.html
class DispatchTest < Service

  attr_reader :data

  def initialize()
    @data = TestData.new
  end

  ## emulating `my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## add to the ostruct.work_log, dependent on the ostruct.cancelled flag
  ## in the ostruct
  ##
  ## called under a callback initialized in #configure
  ##
  def do_work(data)
    STDERR.puts "do_work continuing"
    data.log_event(:loop_cont)
    ## pause a second, for purpose of tests
    sleep 1
  end

  def configure(context)
    src = map_idle_source(context) do
      ## each idle source's callback will be called
      ## in each main loop iteration
      if context.cancellation.cancelled?
        return false
      else
        ## could implement do_work here.
        ##
        ## this modular API will dispatch
        ## to a method outside of this
        ## callback,
        STDERR.puts "In callback => do_work"
        data.log_event(:callback)
        do_work(data)
      end
    end
    src.priority = GLib::PRIORITY_DEFAULT
  end

  ## partial emulation of `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## see superclass docs
  def main()
    initial_debug = $DEBUG
    $DEBUG = true
    begin
      data = self.data
      context = TestContext.new(data)

      cancellation = context.cancellation
      cancellation.reset
      cancellation.signal_connect_after("cancelled") do
        STDERR.puts("Cancellation reached")
        context.log_event(:cancellation)
      end

      super(context) do
        ## block to run outside of the event loop
        ## ... to which effect, the event loop will exit
        ## after this block exits

        orig_int_handler = Signal.trap("INT") do
          ## initailize a signal handler,
          ## e.g for Ctrl-C in irb
          ## for the duration of this method
          STDERR.puts "Cancelled by signal"
          context.log_event(:signal_int)
          context.cancellation.cancel
        end

        begin
          ## simulating a duration in application runtime,
          ## while the main loop runs
          sleep 5
          STDERR.puts "Done"
          context.log_event(:ext_return)
        ensure
          Signal.trap("INT", orig_int_handler)
        end
      end
      return context.data
    ensure
      $DEBUG = initial_debug
    end
  end
end
