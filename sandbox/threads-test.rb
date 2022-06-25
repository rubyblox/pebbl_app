## Service version 1.0.1

require 'glib2'
require 'gio2'

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


require 'logger'

## Base Formatter class for ServiceLogger, which is a Logger interface
## emulating Ruby/GLib logging
##
## FIXME use rainbow (gem) to add color tags to the logging, via a
## subclass of ServiceLogger
class ServiceLogFormatter

  ## Constant named after Logger::Formatter::Format
  ##
  ## This format string accepts the following arguments:
  ## pid, progrname, domain, severity, timestamp, message
  FORMAT = "(%s:%d): %s-%s **: %s: %s\n".freeze

  attr_reader :dt_format, :progname


  def initialize(dt_format: "%H:%M:%S.%6N".freeze,
                 progname:  File.basename($0))
    super()
    @progname = progname
    @dt_format = dt_format
  end

  def format_time(time = Time.now)
    time.strftime(self.dt_format)
  end

  ## This method provides a signature similar to Logger::Formatter#call
  def call(severity, time, domain, msg)
    log_msg = case msg
              when String
                msg
              when Exception
                if (bt = msg.backtrace)
                  "(%s) %s %s" [ msg.class, msg.message, bt[0] ]
                else
                  "(%s) %s" [ msg.class, msg.message ]
                end
              else
                msg.inspect
              end
    format(FORMAT, self.progname, Process.pid, domain, severity,
           format_time(time), log_msg)
  end
end

## @abstract Log device base class for ServiceLogger
class ServiceLogDev

end

## Log device provider for a console log stream
##
## This log device implementation does not use MonitorMixin and may be
## usable from within a signal trap context
class ConsoleLogDev < ServiceLogDev
  attr_reader :io
  def initialize(io = STDERR)
    super()
    @io = io
  end

  def write(text)
    begin
      @io.write(text)
    rescue
      warn "Error when writing log to #{io}: #{$!}"
    end
  end

  ## interface method for compatibility with Logger::LogDevice (no-op)
  def close
    return false
  end

  ## interface method for compatibility with Logger::LogDevice (no-op)
  def reopen
    return false
  end

end


## a Logger interface with a default formatter generally emulating
## Ruby/GLib logging, using the standard error stream for log output
## by default.
##
## @fixme Due to the Logger::LogDevice class' use of MonitorMixin, this
##  logger cannot be used within a signal trap context. MonitorMixin may
##   not be needed when logging directly to a file or other IO
class ServiceLogger < Logger

  class << self
    ## Return a unique instance name for an object
    ##
    ## If the object is a Module, Class, or Symbol, returns the string
    ## representation of the object.
    ##
    ## Otherwise, returns a concatenation of the name of the object's
    ## class and a hexadecimal representation of the object's `__id__`,
    ## as a string
    ##
    ## @param obj [Object] the object
    def iname(obj)
      case obj
        when Class, Symbol, Module
          return obj.to_s
        else
          format("%s 0x%06x", obj.class, obj.__id__)
      end
    end
  end

  ## Initialize a new ServiceLogger
  ##
  ## If logdev is provided as a ServiceLogDev, then this ServiceLogger
  ## should be usable within signal trap handlers. Otherwise, the actual
  ## logdev used will be a Logger::LogDevice encapsualting the logdev
  ## value provied here. In this instance, the ServiceLogger cannot be
  ## used within a signal trap handler.
  ##
  ## @param logdev [Object] the log device to use for this ServiceLogger
  ## @param level [Symbol, String] the initial Logger level for this
  ##  ServiceLogger
  ## @param domain [String] the log domain to use for this
  ##  ServiceLogger.
  ##
  ##  Internally, this value is mapped to the Logger _progname_
  ##  field.
  ##
  ##  If the provided formatter is a ServiceLogFormatter, then the
  ##  effective progname for this logger will be stored in the
  ##  formatter. This formatter's progrname will appear as the _command
  ##  name_ in log entries, while the domain provided here will be used
  ##  as a _log domain_, in log entires.
  ##
  ##  This mapping provides a form of semantic compatability after log
  ##  domains used for logging in GLib, furthermore in emulation of
  ##  logging support in Ruby/GLib
  ##
  ## @param rest_args [Hash] Additional arguments to be provided to
  ##  Logger#initialize
  ##
  def initialize(logdev = ConsoleLogDev.new(),
                 level: $DEBUG ? :debug : :info,
                 formatter: ServiceLogFormatter.new(),
                 domain: self.class.iname(self),
                 **rest_args)
    super(logdev, level: level, progname: domain, formatter: formatter,
          **rest_args)
    ## The Ruby Logger#initialize method wraps the logdev in a
    ## Logger::LogDevice for any logdev provided. This has a side
    ## effect that not any Ruby Logger can be used within a signal
    ## trap context, if using the logdev initialized in that method.
    ##
    ## This corresponds to the usage of MonitorMixin in the class
    ## Logger::LogDevice
    ##
    ## A conditional workaround, to permit logging from within a signal
    ## trap handler, such as when logging to console with this logger
    if (ServiceLogDev === logdev)
      instance_variable_set(:@logdev, logdev)
    end
  end


  ## return the logdev stored via Logger#initialize.
  ##
  ## If a ServiceLogDev was provided to ServiceLogger#initialize, then
  ## this should be eql to the provided logdev.
  ##
  ## Otherwise, the value returned here will be a Logger::LogDevice
  ## encapsulating the value provided as the logdev to
  ## ServiceLogger#initialize
  ##
  ## @return [ServiceLogDev, Logger::LogDevice, false] the log device
  ##  for this ServiceLogger, or false if no logdev has been initialized
  ##  to this ServiceLogger
  def logdev
    if instance_variable_defined?(:@logdev)
      instance_variable_get?(:@logdev)
    else
      false
    end
  end

  ## portability onto Ruby Logger, for the concept of a log domain in GLib
  alias :domain :progname
  alias :domain= :progname=

  def to_s
    "#<%s 0x%06x (%s) %s %s>" % [
      self.class, __id__, log_device, domain, level
    ]
  end
end


require 'forwardable'

## This class is an adaptation after [the Main Contexts tutorial]
## (https://developer.gnome.org/documentation/tutorials/main-contexts.html)
## in the [GNOME Developer Documentation]
## (https://developer.gnome.org/documentation/index.html).
##
## This implementation uses GLib context support in [Ruby-GNOME]
## (https://github.com/ruby-gnome/ruby-gnome/)
##
## The Service/ServiceContext framwork implements a cancellable main
## event loop model for GLib applications.
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

  attr_reader :logger
  self.extend Forwardable
  def_delegators(:@logger, :debug, :error, :fatal, :info, :warn)

  def initialize(logger: ServiceLogger.new) # , cancellation_tag: :cancel)
    @logger = logger
    # @cancellation_tag = cancellation_tag
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
        block.yield(main_thr) if block_given?
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
    context.iteration(context.blocking)
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
      debug "main context thread begins"
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


require 'forwardable'
require 'pebbl_app/support/signals'

## an adaptation after
## https://developer.gnome.org/documentation/tutorials/main-contexts.html
class DispatchTest < Service
  self.extend Forwardable

  attr_reader :data, :handlers
  def_delegators(:@handlers, :set_handler, :with_handler)

  ## Create a new DispatchTest, using a new instance of TestData and a
  ## log initialized for a debug level of information.
  def initialize()
    super()
    self.logger.level = "DEBUG"
    self.logger.domain = ServiceLogger.iname(self)
    @handlers = PebblApp::Support::SignalHandlerMap.new
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
    debug("do_work continuing")
    data.log_event(:loop_cont)
    ## pause a second, for purpose of tests
    sleep 1
  end

  def configure(context)
    src = map_idle_source(context) do
      ## each idle source's callback will be called
      ## in each main loop iteration
      if context.cancellation.cancelled?
        ## returning false from the source callback - source will be removed
        GLib::Source::REMOVE ## 'return' DNW here ...
      else
        ## Similar to the original example
        ## in the GLib documentaiton, this
        ## modular API will dispatch to a
        ## method outside of this
        ## callback/context model,
        ## mainly #do_work
        debug("In callback => do_work")
        data.log_event(:callback)
        do_work(data)
        GLib::Source::CONTINUE
      end
    end
    src.priority = GLib::PRIORITY_DEFAULT
  end

  ## partial emulation of `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## see superclass docs
  def main(wait = 5)
    initial_debug = $DEBUG
    $DEBUG = true

    begin
      data = self.data
      context = TestContext.new(data)

      ## temporary value, initializing the variable
      main_thread = Thread.current

      interrupt_tag = :trap
      hdlr_base = proc { |sname|
        ## append a value to the work log
        context.log_event([:signal, sname])
      }
      hdlr_cancel = proc { |sname|
        warn("Handling signal #{sname}")
        ## cancel the main event loop, then join the main thread
        ## such that the main thread should return after the cancellation
        hdlr_base.yield(sname)
        context.cancellation.cancel
        ## joining the main thread in any throw/exit handler should help
        ## to ensure a clean exit for the main thread.
        ##
        ## This assumes that the main thread will exit the main loop and
        ## return, once the context's cancellation object is set to
        ## cancelled, such as in Service#context_main
        main_thread.join if main_thread
      }
      int_hdlr  = proc { |sname|
        ## cancel, join the main thread, then throw
        ## as to return to the calling thread
        hdlr_cancel.yield(sname)
        ## the following will override the return value from this method:
        throw(interrupt_tag, sname)
      }
      term_hdlr = proc { |sname|
        ## cancel, join the main thread, then exit
        hdlr_cancel.yield(sname)
        exit(0)
      }
      urgent_hdlr = proc { |sname|
        ## cancel, join the main thread, then exit immediately
        hdlr_cancel.yield(sname)
        exit!(0)
      }
      usr1_hdlr = proc { |sname|
        ## log the present state of the event log
        info("Handling signal #{sname}")
        hdlr_base.yield(sname)
        info("Running")
        self.data.work_log.each do |data|
          info("[event] %s : %s" % data)
        end
      }

      ##
      ## not tested on Microsoft Windows platforms,
      ##
      ## TBD support under MinGW
      ## - assuming a GTK3 stack for MinGW, or at least glib2, gio2
      ##
      handlers.set_handler("INT", &int_hdlr)
      handlers.set_handler("TERM", &term_hdlr)
      handlers.set_handler("QUIT", &urgent_hdlr)
      handlers.set_handler("URG", &urgent_hdlr)
      handlers.set_handler("USR1", &usr1_hdlr)
      begin
        ## The SIGINFO signal may not be supported on all operating
        ## systems - is supported on FreeBSD, commonly available with
        ## Ctrl-t at a PTY, when this signal has an active handler
        ##
        ## Some applications, e.g ddpt, will implement a similar handler
        ## for USR1 on other operating systems (e.g Linux) as similar to
        ## the application's behavior when receiving an INFO signal
        ## on FreeBSD
        ##
        ## So, this uses the usr1_hdlr for both, not calling a compiler
        ## to test for signal availabilty before runtime ...
        handlers.set_handler("INFO", &usr1_hdlr)
      rescue ArgumentError
        ## nop
      end

      cancellation = context.cancellation
      cancellation.reset
      cancellation.signal_connect_after("cancelled") do
        debug("Cancellation reached")
        context.log_event(:cancellation)
      end

      catch(interrupt_tag) do
        handlers.with_handlers do ## outside of the main block
          super(context) do |main|
            ## This block will be run in the current thread,
            ## i.e outside of the event loop
            ##
            ## The event loop will exit after this block exits

            ##  set the value of main_thread for Thread.join in handlers
            main_thread = main

            ## simulating a duration in application runtime,
            ## while the main loop runs
            sleep wait
            ## logging before return
            debug("Done")
            context.log_event(:ext_return)
          end
        end ## with_handlers
        return context.data ## not returned on event of interrupt
      ensure
        $DEBUG = initial_debug
      end  ## catch interrupt_tag
    end
  end
end
