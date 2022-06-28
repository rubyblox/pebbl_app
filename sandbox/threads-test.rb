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
## **New Feature:** Now using Pastel (gem) to add color tags to the
## logging
## - can be enabled/non-enabled per each formatter
## - in a ServiceLogger using a default ConsoleLogDev instance, this
##   feature will be enabled if STDERR is a tty stream
class ServiceLogFormatter

  module Const
    ## Format control string for log formatting
    ##
    ## This format string accepts the following arguments:
    ## reset string, pid, progname, domain, severity, timestamp, message
    FORMAT ||= "%s(%s:%d): %s-%s %s: %s\n".freeze
    ## Default timestamp format string for log messages
    DT_FORMAT ||= "%H:%M:%S.%6N".freeze
  end

  attr_reader :dt_format, :progname, :pastel, :pastel_sev

  def initialize(dt_format: Const::DT_FORMAT,
                 progname: File.basename($0).freeze,
                 pastel: false, pastel_sev: false)
    super()
    @progname = progname
    @dt_format = dt_format
    case pastel
    when Kernel.const_defined?(:Pastel) && (Pastel === pastel)
      ## an existing Pastel instance
      @pastel = pastel
    when Hash
      require 'pastel'
      ## args for a new Pastel instance
      @pastel = Pastel.new(**pastel)
    when nil, false
      @pastel = false
    else
      ## create a new instance, enabled
      require 'pastel'
      @pastel = Pastel.new(enabled: true)
    end
    if pastel
      @pastel_sev = (pastel_sev || Hash.new)
    end
  end

  def format_severity(severity)
    if pastel
      sev = severity.to_s.upcase.to_sym
      ## The defaults here would assume a dark console background
      case sev
      when :WARN, :WARNING
        sev = (pastel_sev[:WARN] ||= pastel.yellow.bold.detach)
      when :INFO, :MESSAGE
        sev = (pastel_sev[:INFO] ||= pastel.green.bold.detach)
      when :ERROR
        sev = (pastel_sev[:ERROR] ||= pastel.red.bold.detach)
      when :FATAL, :CRITICAL
        sev = (pastel_sev[:FATAL] ||= pastel.magenta.bold.detach)
      when :DEBUG
        sev = (pastel_sev[:DEBUG] ||= pastel.cyan.bold.detach)
      else
        sev = (pastel_sev[:UNKNOWN] ||= pastel.bold.detach)
      end
      sev.call(severity)
    else
      ## no pastel formatting
      severity
    end
  end

  def format_time(time)
    ts = time.strftime(dt_format)
    if pastel
      return pastel.blue(ts)
    else
      return ts
    end
  end

  def format_message(msg)
    case msg
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
  end


  ## This method provides a signature similar to Logger::Formatter#call
  def call(severity, time, domain, msg)
    if pastel
      ## reset all terminal escape codes before the next log entry
      reset = (@reset ||= pastel.reset.detach.call)
    else
      reset = "".freeze
    end
    format(Const::FORMAT, reset,
           self.progname, Process.pid, domain,
           format_severity(severity),
           format_time(time), format_message(msg))
  end
end

## @abstract Log device base class for ServiceLogger
class ServiceLogDev

end

## Log device provider for a console log stream
##
## This log device implementation does not use MonitorMixin and may be
## usable from within a signal trap context
##
## @see ServiceLogger
## @see ServiceLogFormatter
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


## Logger interface for ServiceLogDev and ServiceLogFormatter instances
##
## **Log Device**
##
## ServiceLogger will use a ConsoleLogDev as the default log device.
##
## This class of log device does not utilize MonitorMixin and can be
## used within signal trap handlers, as well as in other runtime
## contexts.
##
## By default, the ConsoleLogDev will be initialized onto the STDERR
## stream.
##
## ServiceLogger also provides support for using a Logger::LogDevice as
## a logdev for a ServiceLogger. If a Logger::LogDevice or any value not
## a ServiceLogDev is provided as the logdev for ServiceLog#initialize,
## then the ServiceLogger will use a Logger::LogDevice. However, if
## using a Logger::LogDevice then the containing ServiceLogger cannot be
## used within signal trap contexts.
##
## @fixme The Logger::LogDevice support is retained for general
## compatibility with Ruby's Logger. This API may provide support for
## log rotation in file-based logging. It will provide an
## incompatibility with applications requiring that the logger would be
## usable within a signal trap context.
##
## **Log Formatter**
##
## ServiceLogger will use a ServiceLogFormatter for log formatting, by
## default.
##
## The ServiceLogFormatter instance for a ServiceLogger can be initialized
## to use Pastel as a utility for adding terminal escape strings for
## colors, to the log text. This feature is generally constant to each
## individual ServiceLogFormatter, but can be configured when each
## ServiceLogFormatter is initialized.
##
## By default, the SericeLogFormatter will use Pastel when the STDERR
## stream represents a TTY device in the host operating system. This
## corresponds to the default logdev when creating a ServiceLogger.
##
##
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
  ## If logdev provided is a ServiceLogDev, then this ServiceLogger
  ## can be used within signal trap handlers. Otherwise, the actual
  ## logdev used will be a Logger::LogDevice encapsualting the logdev
  ## value provied here. In this instance, the ServiceLogger cannot be
  ## used within a signal trap handler.
  ##
  ## @param logdev [Object] the log device to use for this
  ##  ServiceLogger.
  ##
  ## @param level [Symbol, String] the initial Logger level for this
  ##  ServiceLogger.
  ##
  ## @param formatter [ServiceLogFormatter, Logger::Formatter] the log
  ## formatter to use for this ServiceLogger.
  ##
  ## @param domain [String] the log domain to use for this
  ##  ServiceLogger.
  ##
  ##  Internally, this ServiceLogger _domain_ attribute is mapped to the
  ##  Logger _progname_ attribute
  ##
  ##  If the provided formatter is a ServiceLogFormatter, then the
  ##  effective _progname_ for the running process will be stored in the
  ##  formatter. The formatter's progrname will then appear as the
  ##  _command name_ in log entries.  The _domain_ provided here
  ##  will be used  as a _log domain_ in log entires, supplemental
  ##  to the _command name_ used in the formatter.
  ##
  ##  This mapping provides a form of semantic compatability after _log
  ##  domains_ used for logging in GLib and in Ruby/GLib
  ##
  ## @param rest_args [Hash] Additional arguments to be provided to
  ##  Logger#initialize
  ##
  def initialize(logdev = ConsoleLogDev.new(STDERR),
                 level: $DEBUG ? :debug : :info,
                 formatter: ServiceLogFormatter.new(pastel: STDERR.tty?),
                 domain: ServiceLogger.iname(self),
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
    if (ServiceLogDev === logdev) || (Logger::LogDevice === logdev)
      instance_variable_set(:@logdev, logdev)
    end
  end


  ## return the logdev for this ServiceLogger
  ##
  ## If a ServiceLogDev or Logger was provided to
  ## ServiceLogger#initialize, then this should be eql to the provided
  ## logdev.
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

end


## Data object class for the DispatchTest example
class TestData

  ## a hash table of Time values and event tags, used for internal
  ## logging in the DispatchTest example
  attr_reader :work_log

  def initialize()
    super()
    @work_log = {}
  end


  ## log an event of the provided tag value using the provided time
  ## as when storing the entry in #work_log
  def log_event(tag, time = Time.now)
    self.work_log[time] = tag
  end
end

## a ServiceContext for the DispatchTest example, storing an arbitrary
## data value.
##
## In the DispatchTest example, the data value will typically be a
## TestData instance. The data value to the TestContext will be
## initialied as the data value in the DispatchTest instance.
##
## The availability of this value in the TestContext will permit for
## forwarding to the TestData#log_event method from within context
## methods
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
    @handlers = PebblApp::Support::SignalMap.new
    @data = TestData.new
  end

  ## emulating `my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
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
    map_idle_source(context, priority: :default) do
      ## each idle source's callback will be called
      ## in each main loop iteration
      if context.cancellation.cancelled?
        ## when the the source callback returns false => source will be removed
        ##
        ## this has not yet been reached under tests
        debug("In callback (cancelled)")
      else
        ## Similar to the original example in the GLib documentaiton,
        ## this modular API will dispatch to a method outside of this
        ## callback/context model, mainly #do_work
        debug("In callback => do_work")
        data.log_event(:callback)
        do_work(data)
        # debug("Testing error handling") if $DEBUG_ERROR_HANDLING
        # raise "Test" if $DEBUG_ERROR_HANDLING
      end
    end
  end

  ## a partial adaptation after `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
  ##
  ## @see Service#main
  def main(wait = 5)
    initial_debug = $DEBUG
    $DEBUG = true

    begin
      data = self.data
      context = TestContext.new(data)

      ## temporary value, initializing the variable
      main_thread = Thread.current

      interrupt_tag = :trap
      hdlr_base = proc { |sname, nxt|
        ## append a value to the work log
        context.log_event([:signal, sname])
      }
      hdlr_cancel = proc { |sname, nxt|
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
      term_hdlr = proc { |sname, nxt|
        ## cancel, join the main thread, then throw
        ##
        ## the thrown value will provide the return value for this method
        ##
        ## this provides a "throw, not exit" behavior on the assumptions
        ## that the caller of this method will handle any exit preocedures
        hdlr_cancel.yield(sname)
        throw(interrupt_tag, sname)
      }
      int_hdlr  = proc { |sname, nxt|
        ## cancel, join the main thread, then exit
        hdlr_cancel.yield(sname)
        exit(0)

      }
      quit_hdlr = proc { |sname, nxt|
        ## cancel, join the main thread, then exit immediately
        hdlr_cancel.yield(sname)
        exit!(0)
      }
      usr1_hdlr = proc { |sname, perv|
        ## log the state of the event log, to the service log
        info("Handling signal #{sname}")
        hdlr_base.yield(sname)
        info("Running")
        self.data.work_log.each do |data|
          info("[event] %s : %s" % data)
        end
      }

      ##
      ## signal trap calls - not tested on Microsoft Windows platforms
      ##
      ## TBD support for signal handling in Ruby via MinGW
      ##
      ## TBD handling the TSTP signal with somethhing like interactive
      ## job control (may need more C API calls)
      ##
      if $DEBUG
        ## swapped signal handling for INT, TERM
        ## e.g to have SIGINT via Ctrl-c end the main method
        ## without ending the process. Useful for interactive eval
        handlers.set_handler("INT", &term_hdlr)
        handlers.set_handler("TERM", &int_hdlr)
      else
        ## normal signal handling for INT, TERM
        handlers.set_handler("INT", &int_hdlr)
        handlers.set_handler("TERM", &term_hdlr)
      end
      handlers.set_handler("QUIT", &quit_hdlr)
      handlers.set_handler("USR1", &usr1_hdlr)
      begin
        ## FreeBSD and OSX offer a SIGINFO signal.
        ## This signal is not implemented on Linux.
        ##
        ## More detail, via Safari Books Online:
        ## https://learning.oreilly.com/library/view/advanced-programming-in/9780321638014/ch10.html
        ##
        ## For an example, the ddpt program handles SIGUSR1 (on Linux)
        ## similar to SIGINFO (on FreeBSD) when running under a verbose
        ## option. Similarly, this method handles SIGINFO (when available)
        ## with the same callback as for SIGUSR1.
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
