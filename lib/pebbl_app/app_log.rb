## AppLog and related classes - Logging in PebblApp

require 'pebbl_app'

require 'logger'

module PebblApp

  ## Base Formatter class for AppLog
  ##
  ## **New Feature:** Using Pastel (gem) to add color tags to the
  ## logging
  ## - can be enabled per each formatter
  class AppLogFormatter

    module Const
      ## Format control string for log formatting
      ##
      ## used in #call
      ##
      ## This format string accepts the following arguments:
      ## Reset string, pid, progname, timestamp, log domain, severity, message
      FORMAT ||= "%s(%s:%d) %s %s %s: %s\n".freeze

      ## Default timestamp format string for log messages
      ##
      ## used in #format_time
      DT_FORMAT ||= "%H:%M:%S.%6N".freeze
    end

    ## Timestamp format for this formatter
    ##
    ## By default, this attribute is initialized to the value of Const::DT_FORMAT
    attr_reader :dt_format

    ## program name to use for this formatter
    ##
    ## By default, this attribute is initialized to the File.basename of
    ## the value of `$0`
    attr_reader :progname

    ## true if Pastel is enabled for this formatter
    ##
    ## @see #pastel_formats
    ## @see #format_severity
    ## @see #format_time
    attr_reader :pastel

    ## hash table for Pastel formats to use with timestamp and severity
    ## strings, or false if pastel is not enabled for this formatter.
    attr_reader :pastel_formats

    ## Create a new AppLogFormatter
    ##
    ## @param dt_format [String] Time format string for #format_time
    ##
    ## @param progname [String] Progran name for #call
    ##
    ## @param pastel [boolean] True if Pastel should be enabled for this
    ## log formatter
    ##
    ## @param pastel_formats [Hash, false] If Pastel should enabled for
    ## this formatter, a custom `pastel_formats` cache may be provided as
    ## to configure the logging styles used in #format_severity and in
    ## #format_time
    ##
    ## @see AppLog
    def initialize(dt_format: Const::DT_FORMAT,
                   progname: File.basename($0).freeze,
                   pastel: false, pastel_formats: false)
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
        @pastel_formats = (pastel_formats || Hash.new)
      end
    end


    ## format a log severity for #call
    ##
    ## If Pastel is enabled for this log formatter, the timestamp will be
    ## logged with a format from the `pastel_formats` table for this
    ## formatter.
    ##
    ## The following entries are supported in `pastel_formats`
    ##
    ## `:SEV_WARN`
    ## : format for _warn_ or _warning_ severity. Default: Yellow, bold
    ## `:SEV_INFO`
    ## : format for _info_ and _message_ severity. Default: Green, bold
    ## `:SEV_ERROR`
    ## : format for _error_ severity. Default: Red, bold
    ## `:SEV_FATAL`
    ## : format for _fatal_ and _critical_ severity. Default: Magenta, bold
    ## `:SEV_DEBUG`
    ## : format for _debug_ severity. Default: Cyan, bold
    ## `:SEV_UNKNOWN`
    ## : format for other severity. Default: Bold
    ##
    ## @param severity [String, Symbol] input severity for a log message
    ## @return [String] output severity for the log message
    def format_severity(severity)
      if pastel
        sev = severity.to_s.upcase.to_sym
        ## The defaults here would assume a dark console background
        case sev
        when :WARN, :WARNING
          sev = (pastel_formats[:SEV_WARN] ||= pastel.yellow.bold.detach)
        when :INFO, :MESSAGE
          sev = (pastel_formats[:SEV_INFO] ||= pastel.green.bold.detach)
        when :ERROR
          sev = (pastel_formats[:SEV_ERROR] ||= pastel.red.bold.detach)
        when :FATAL, :CRITICAL
          sev = (pastel_formats[:SEV_FATAL] ||= pastel.magenta.bold.detach)
        when :DEBUG
          sev = (pastel_formats[:SEV_DEBUG] ||= pastel.cyan.bold.detach)
        else
          sev = (pastel_formats[:SEV_UNKNOWN] ||= pastel.bold.detach)
        end
        sev.call(severity)
      else
        ## no pastel formatting
        severity
      end
    end

    ## format a timestamp for #call
    ##
    ## This method will use the #dt_format timestamp format string
    ## for the formatter, to produce a timestamp string.
    ##
    ## If Pastel is enabled for this log formatter, the timestamp string
    ## will be logged with a format from the `:TIME` entry of the
    ##`pastel_formats` table - by default, Blue.
    ##
    ## @param time [Time] the Time for the log message
    ## @return [String]  the timestamp
    def format_time(time)
      ts = time.strftime(dt_format)
      if pastel
        fmt = (pastel_formats[:TIME] ||= pastel.blue.detach)
        fmt.call(ts)
      else
        return ts
      end
    end

    ## format a log message for #call
    ##
    ## @param msg [String, Exception. Object] the data to log
    ##
    ##  If the msg is provided as a String, the string will be used
    ##  verbatim
    ##
    ##  If the msg is provided as an Exception, the class and message for
    ##  the exception will be used. If the Exception has a backtrace, the
    ##  first element of the backtrace will be suffixed to the message
    ##
    ##  If the msg is provided as any other class of object, the `inspect`
    ##  string for the object wil be used as the log message
    def format_message(msg)
      case msg
      when String
        msg
      when Exception
        if (bt = msg.backtrace)
          "(%s) %s %s" [ msg.class, msg.message, bt.first ]
        else
          "(%s) %s" [ msg.class, msg.message ]
        end
      else
        msg.inspect
      end
    end


    ## This method provides a signature similar to Logger::Formatter#call
    ##
    ## This will use the methods  #format_severity, #format_time, and
    ## #format_message in formatting a log message string for the provided
    ## argument values.
    ##
    ## @param severity [String, Symbol] log severity for the log message
    ##
    ## @param time (see #format_time)
    ##
    ## @param domain [String, Symbol] log domain for the log message
    ##
    ## @param msg (see #format_message)
    ##
    ## @see AppLog
    def call(severity, time, domain, msg)
      if pastel
        ## reset all terminal escape codes before the next log entry
        reset = (@reset ||= pastel.reset.detach.call)
      else
        reset = "".freeze
      end
      format(Const::FORMAT, reset,
             self.progname, Process.pid,
             format_time(time), domain,
             format_severity(severity),
             format_message(msg))
    end
  end

  ## @abstract Log device base class for AppLog
  class AppLogDev

  end

  class StreamLogDev < AppLogDev

    attr_reader :io

    def initialize(io)
      super()
      @io = io
    end

    ## interface method for compatibility with Logger::LogDevice
    ##
    ## This method writes the provided text to the #io stream for this
    ## StreamLogDev
    def write(text)
      begin
        @io.write(text)
      rescue
        warn "Error when writing log to #{io}: #{$!}"
      end
    end
  end

  ## Log device provider for a console log stream
  ##
  ## This log device implementation does not use MonitorMixin and may be
  ## used within a signal trap context.
  ##
  ## @see AppLog
  ## @see AppLogFormatter
  class ConsoleLogDev < StreamLogDev

    def initialize(io = STDERR)
      super(io)
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


  require 'open3'
  require 'shellwords'

  ## Class of LogDev utilizing an input stream onto an external process
  ##
  class ProcessLogDev < StreamLogDev

    attr_reader :command, :pid, :thread

    ## @param command [String, Array<String>] Shell command to use when
    ## initializing the logging process
    ##
    ## @param fallback [Io, String, Pathname, false] If a non-falsey
    ##  value, this indicates a fallback stream to use for logging on
    ##  event of failure in initializing the logging process. If an Io
    ##  stream, the Io will be used a fallback. If a String or Pathname,
    ##  then on event of failure in initializnig the logging process, a
    ##  new stream  will be opened for that filename. If a falsey value,
    ##  a stream will be opened on IO::NULL on event of failure in the
    ##  logging process.
    def initialize(command,
                   fallback: STDERR)
      ## no io initially ...
      super(false)
      ## @command should be initialized as an Array<String>-like Enumerable
      if (Enumerable === command)
        @command = command
      else
        @command = Shellwords.split(command)
      end
      @fallback = fallback
      @pid = 0
    end

    ## FIXME #close, #reopen

    ## Initialize the logging process for this ProcessLogDev
    ##
    def initialize_process()
      ## Implementation Notes
      ##
      ## - Needs test with rsyslog, see also vagrant x FreeBSD container envts
      ##   Usage case:
      ##    (A) nginx container, forwarding requests via Passenger
      ##    (B) MariaDB container, for ..
      ##    (C) Ruby container, receiving requests from Passenger,
      ##        and accessing MariaDB (non-embedded)
      ##
      ## - On failure, multilog would write any text to stderr
      ##
      ## - On success, multilog does not use stderr or stdout streams
      ##
      ## - This method is implemented to retain an stdin pipe with the
      ##   subprocess, if the process was successfully opened.
      ##
      ## - Any initial stderr and stdout text from the log process will be
      ##   redirected to the same pipe. This pipe will be accessed if on
      ##   event of failure in initializing the logging process. The pipe
      ##   will be closed before exit from this method.
      ##
      ## - Undocumented feature: @fallback
      ##
      ##   FIXME should be updated to accept a fallback IO, by default STDERR
      ##
      ##   Applied on event of a failure in opening the logging process.
      ##
      ##   If not a falsey value, then this log device will defer to
      ##   logging to IO::NULL. Else, the log device will defer to logging
      ##   to STDERR. This is to ensure firstly that some io stream is
      ##   available for this log device. Secondly, if @fallback is
      ##   non-falsey, the redirection to STDERR may serve to ensure that
      ##   any log output to this log device may not be discarded on event
      ##   of faiure with the log process.
      ##
      begin
        p_in, p_xout, p_thr = Open3.popen2(* @command)
        pid = p_thr.pid
        begin
          exited = Process.waitpid(pid, Process::WNOHANG)
        rescue SystemCallError
          exited = -1
        end
        if exited
          Kernel.warn("Failed to open shell command: %s" % [
            Shellwords.join(@command) ], uplevel: 0)
          err = String.new
          err_read = false
          begin
            err_read = p_xout.read_nonblock(1024, err, exception: false)
          rescue
            Kernel.warn("Error reading output from shell command: #{$!}",
                        uplevel: 0)
          else
            if err_read
              err.each_line do |txt|
                Kernel.warn("out: #{txt}")
              end
            end
          ensure
            p_in.close
            p_xout.close
          end
          if @fallback
            Kernel.warn("Reverting to fallback stream for logging: #{fallback.inspect}",
                        uplevel: 0)
            case @fallback
            when IO
              ## should not cause issues in finalization, at least for fd streams.
              ##
              ## If the @fallback is a stream opened on some file
              ## descriptor, generally #dup would result in an IO with a
              ## new file descriptor.
              ##
              ## Known limitation: if the @fallback is a StringIO, the
              ## io used here will use the same string as the initial
              ## StringIO
              ##
              @io = @fallback.dup
            else
              @io = File.open(@fallback, "wb")
            end
          else
            Kernel.warn("Reverting to #{IO::NULL} for logging", uplevel: 0)
            @io = File.open(IO::NULL, "wb")
          end
          p_in = @io
          finalizer = lambda {
            p_in.close
          }
          ObjectSpace.define_finalizer(self, finalizer)
          @pid = -1
        else
          Kernel.warn("Opened #{@command.first} (#{pid}): \
#{Shellwords.join(@command).inspect}") if $DEBUG
          @io = p_in
          @pid = pid
          @thread = p_thr
          finalizer = lambda {
            p_in.close
            p_thr.terminate
          }
          ObjectSpace.define_finalizer(self, finalizer)
        end
        return p_thr
      ensure
        p_xout.close if p_xout
      end
    end

    def process_failed?()
      @pid < 0
    end

    def process_running?()
      if process_failed?
        return false
      elsif (@pid > 0)
        ! Process.waitpid(@pid, Process::WNOHANG)
      end
    end

    def process_uninitialized?()
      @pid.eql?(0)
    end

    def ensure_process()
      if process_uninitialized?
        initialize_process
      end
    end

    def write(text)
      ## by default, deferring initialization for the logging process
      ## until the first call to #write
      ensure_process
      super(text)
    end

  end

  ## Log device for direct write to a [multilog]
  ## (https://cr.yp.to/daemontools/multilog.html) process
  ##
  ## multilog is typically avaialble via the daemontools package,
  ## in host package management systems
  ##
  class MultilogDev < ProcessLogDev

    def initialize(logdir, multilog: "multilog".freeze,
                   fallback: STDERR)
      ## relying on the super method to parse the multilog cmd
      super(multilog, fallback: fallback)
      @logdir = logdir
      ## adding the logdir to the parsed multilog cmd
      self.command.push(logdir)
    end

    def write(text)
      ## multilog will write to the log after receiving newline
      if text.end_with?("\n".freeze)
        txt = text
      else
        txt = text + "\n".freeze
      end
      super(txt)
    end
  end


  ## Logger interface for AppLogDev and AppLogFormatter instances
  ##
  ## **Log Device**
  ##
  ## AppLog will use a ConsoleLogDev on STDERR as the default log
  ## device.  This class of log device does not utilize MonitorMixin and
  ## can be used within signal trap handlers, as well as in other runtime
  ## contexts.
  ##
  ## AppLog also provides support for using a Logger::LogDevice as
  ## a logdev for a AppLog. If a Logger::LogDevice or any value not
  ## either a AppLogDev or File::NULL is provided as the logdev for
  ## AppLog#initialize, then the AppLog will use a
  ## Logger::LogDevice. If using a Logger::LogDevice then the containing
  ## AppLog cannot be used within signal trap contexts.
  ##
  ##
  ## **Log Formatter**
  ##
  ## By default, AppLog will use a AppLogFormatter for log
  ## formatting
  ##
  ## The AppLogFormatter instance for a AppLog can be initialized
  ## to use Pastel. Applied within a AppLogFormatter, Pastel would
  ## provide a utility for adding terminal escape strings for color
  ## encoding in the log text. This may generally be of use for logs
  ## produced on a pseudterminal device or TTY. This feature is generally
  ## constant to each individual AppLogFormatter, but can be
  ## configured when each AppLogFormatter is initialized.
  ##
  ## By default, the SericeLogFormatter will use Pastel when the STDERR
  ## stream represents a TTY or PTY device. This corresponds to the
  ## default logdev used when creating a AppLog.
  ##
  ## **Emulation of Ruby/GLib Logging**
  ##
  ## The AppLog, AppLogFormatter, and AppLogDev API was
  ## designed as to provide a Logger-like API with a logger output format
  ## resembling the GLib::Log support in Ruby-GNOME
  ##
  class AppLog < Logger

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

      def tty_logdev?(logdev)
        case logdev
        when StreamLogDev
          io = logdev.io
          (IO === io) && io.tty?
        else
          false
        end
      end
    end

    ## Initialize a new AppLog
    ##
    ## If logdev provided is a AppLogDev, then this AppLog
    ## can be used within signal trap handlers. Otherwise, the actual
    ## logdev used will be a Logger::LogDevice encapsualting the logdev
    ## value provied here. In this instance, the AppLog cannot be
    ## used within a signal trap handler.
    ##
    ## @param logdev [Object] the log device to use for this
    ##  AppLog.
    ##
    ## @param level [Symbol, String] the initial Logger level for this
    ##  AppLog.
    ##
    ## @param formatter [AppLogFormatter, Logger::Formatter] the log
    ## formatter to use for this AppLog.
    ##
    ## @param domain [String] the log domain to use for this
    ##  AppLog.
    ##
    ##  Internally, this AppLog _domain_ attribute is mapped to the
    ##  Logger _progname_ attribute
    ##
    ##  If the provided formatter is a AppLogFormatter, then the
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
                   formatter: AppLogFormatter.new(pastel: AppLog.tty_logdev?(logdev)),
                   domain: AppLog.iname(self),
                   **rest_args)
      if (AppLogDev === logdev) || (Logger::LogDevice === logdev)
        ## a workaround to preventing Logger from initializing a new LogDevice
        super_logdev = File::NULL
      else
        super_logdev = logdev
      end
      super(super_logdev, level: level, progname: domain, formatter: formatter,
            **rest_args)
      ## The Ruby Logger#initialize method wraps the logdev in a
      ## Logger::LogDevice for any logdev provided, unless the logdev is
      ## provided as File::NULL. Corresponding to the application of
      ## MonitorMixin in the class Logger::LogDevice, this has a side
      ## effect that not any Ruby Logger except for a File::NULL logger
      ## can be used within a signal trap context, if using the logdev
      ## initialized in that method.
      ##
      ## A conditional workaround - this permits for logging from within a
      ## signal trap handler, if the logdev is a AppLogDev
      if (AppLogDev === logdev) || (Logger::LogDevice === logdev)
        instance_variable_set(:@logdev, logdev)
      end
    end


    ## return the logdev for this AppLog
    ##
    ## If a AppLogDev or Logger was provided to
    ## AppLog#initialize, then this should be eql to the provided
    ## logdev.
    ##
    ## Otherwise, the value returned here will be a Logger::LogDevice
    ## encapsulating the value provided as the logdev to
    ## AppLog#initialize
    ##
    ## @return [AppLogDev, Logger::LogDevice, false] the log device
    ##  for this AppLog, or false if no logdev has been initialized
    ##  to this AppLog
    def logdev
      if instance_variable_defined?(:@logdev)
        instance_variable_get(:@logdev)
      else
        false
      end
    end

    ## portability onto Ruby Logger, for the concept of a log domain
    alias :domain :progname
    alias :domain= :progname=

    def to_s
      "#<%s 0x%06x (%s) %s %s>" % [
        self.class, __id__, log_device, domain, level
      ]
    end
  end

end ## PebblApp
