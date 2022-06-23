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
## Using the DispatchTest example:
## ~~~~
## require_relative 'thread-test.rb'
##
## test = DispatchTest.new
## data = test.main
## ~~~~
##
## Notes
##
## - Service#main can be called more than once, within any one or more
##   consecutive threads
##
## - The context provided to #main should be created newly for each call
##   to #main
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

  ## an adapted emulation of `main` in
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
        block.yield if block_given?
      end ## main_mtx

      # context.unref # n/a
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

  ## prototype method, should be implemented in any subclass
  ##
  def map_sources(context)
    Kernel.warn("prototype #{__method__} method reached for %p in %s" %
                [context, self], uplevel: 0) if $DEBUG
  end

  ## iterate once, for a loop on this context
  ##
  ## called within the thread running the loop on the main context
  ##
  def context_dispatch(context)
    context.iteration(true) ## true i.e a blocking iteration
    ## an additional call for dispatching to GTK e.g
    # Gtk.main_iteration_do(false) if Gtk.events_pending
  end

  ## an adaptated emulation of `thread1_main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## called under #main
  ##
  ## returns the new thread
  ##
  ## @fixme should allow a block, for additional actions in the main
  ##        loop dispatch, e.g `Gtk.main_iteration_do(false) if Gtk.events_pending`
  def context_main(context)
    main_mtx = context.main_mtx
    conf_mtx = context.conf_mtx

    thr = Thread.new do
      debug "... main thread begins"
      debug_event(context, :main_run)

      main = GLib::MainLoop.new(context, false) ## false => not run
      @main = main

      ## block on conf_mtx, while caller is configuring event sources
      conf_mtx.synchronize do
        Thread.exit if context.cancellation.cancelled?

        ## Iterate in the event loop until the mutex provided by the
        ## caller can be held in the dispatch loop, or until
        ## the cancellation object for this context is cancelled
        ##
        ## Once the mutex can be held here: Cleanup; Release the mutex
        ## if held, and return
        debug_event(context, :main_iterate)
        catch(:cancelled) do |tag|
          while ! main_mtx.try_lock
            if context.cancellation.cancelled?
              ## lock held, but cancellation is indicated
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
          # main.unref # n/a
        ensure
          ## own thread may not have held the mutex, when this
          ## is reached under cancellation
          ## (odd, but seen under tests - see signal handler?)
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
  ## called under a callback initialized in #map_sources
  ##
  def do_work(data)
    STDERR.puts "do_work continuing"
    data.log_event(:loop_cont)
    ## pause a second, for purpose of tests
    sleep 1
  end

  def map_sources(context)
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
