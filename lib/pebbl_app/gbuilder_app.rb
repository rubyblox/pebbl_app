## gbuilder_app.rb - Application extensions on GLib, GTK

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

require 'logger'
require 'gtk3'

module PebblApp

#class GLibApp < GLib::Application
## FIXME define in glib_app.rb
#

class GBuilderApp < Gtk::Application

  extend UIBuilder

  # attr_reader :gtk_loop # see ...

  ## utility method for procesing the +flags+ option under
  ## *+GBuilderApp#initialize+*
  ##
  ## When applied to that +flags+ value, this method must return an
  ## integer value, such that will be used in a call to
  ## *+Gio::Application#set_flags+*, before the *GBuilderApp* is
  ## registered to GTK. Provided with an appropriate +flags+ value, this
  ## will be managed internally during *GBuilderApp* initialization
  ##
  ## *Examples*
  ##
  ##    GBuilderApp.app_flag('is_service') ==
  ##       Gio::ApplicationFlags::IS_SERVICE.to_i => true
  ##
  ##   GBuilderApp.app_flag(:handles_open) ==
  ##       Gio::ApplicationFlags::HANDLES_OPEN.to_i => true
  ##
  ##   GBuilderApp.app_flag([:is_service, :handles_open])
  ##       => <Integer>

  def self.app_flag(datum)  ## FIXME move to GLibApp (glib_app.rb)
    name, value = false
    case datum
    when Array
      value = 0
      datum.each { |elt| value = (value | self.app_flag(elt)) }
    when Integer
      value = datum
    when Gio::ApplicationFlags
      value = datum
    when String
      ## NB except for FLAGS_NONE, the constants defined under this Gio
      ## Ruby module do not use any special prefix
      ## e.g
      ##  "is_service" => Gio::ApplicationFlags::IS_SERVICE,
      ##  :handles_open => Gio::ApplicationFlags::HANDLES_OPEN,
      name = datum.upcase.to_sym
    when Symbol
      name = datum.upcase
    when NilClass, FalseClass
      value = Gio::ApplicationFlags::FLAGS_NONE
    else
      raise ArgumentError.new("Unknown Gio::ApplicationFlags name #{datum.inspect}")
    end
    if !value
      if Gio::ApplicationFlags.const_defined?(name)
        value = Gio::ApplicationFlags.const_get(name)
      else
        raise ArgumentError.new("Unknown Gio::ApplicationFlags name #{datum.inspect}")
      end
    end
    return value
  end

  ## @param name [String] The application name (FIXME syntax check)
  ##
  ## @param logger [Logger | nil] *Logger* to use for Ruby logging in
  ##   this application instance. If +nil+, a *Logger* will be initialized
  ##   on +STDERR+, with a log level of +::LOG_LEVEL_DEFAULT+ and a
  ##   program name equal to +name+
  ##
  ## @param flags [Integer | String | Symbol | Array<Integer | String | Symbol>]
  ##  see ::app_flag for a description of the syntax and usage
  ##  of this parameter
  def initialize(name, logger: nil,
                 flags: Gio::ApplicationFlags::FLAGS_NONE)
    # @state = :initialized

    ## NB @logger will be used for the LoggerDelegate extension,
    ## providing instance-level access to the logger with an API
    ## similar to Logger, as wrapper functions onto the @logger itself
    ##
    @logger = (AppLog.app_log ||= AppLog.new())

    ## TBD
    # LogModule.logger ||= @logger
    # LogModule.manage_warnings

    super(name)

    ## FIXME move to GLibApp (glib_app.rb)
    fl_value = GBuilderApp.app_flag(flags)
    fl_obj = Gio::ApplicationFlags.new(fl_value)
    ## NB fl_obj would be a proxy object for an enum value,
    ## and should not need to be unref'd
    self.set_flags(fl_obj)

    ## ensure that a local Gtk::Builder is initialized for this
    ## application, via a class attr.
    ##
    ## This buider may be used for some template access or generally for
    ## Glade UI access. The builder - as a class property - would be
    ## used with the following extension modules
    ## - UIBuilder
    ## - ResourceTemplateBuilder
    ## - FileTemplateBuilder
    ##
    ## see also:
    ## ResourceTemplateBuilder.use_resource_bundle
    ##
    ## [FIXME] move this to the documentation for this method
    ## and see how it's formatted in RIView, while using all these
    ## YARD tags around - needs more project tooling. see also pkgsrc
    self.class.builder ||= Gtk::Builder.new
    # self.signal_connect("shutdown") {
    #   # FIXME - ensure any local method will be called for app shutdown procedures
    # }
  end

  def run()  ## FIXME move to GLibApp (glib_app.rb)
    @logger.debug("#{__method__} in #{Thread.current}")

    begin
      self.register()
    rescue Gio::IOError::Exists
      ## NB
      ## - there is no unregister method for Applications in GTK
      ## - this application has not been defined with a flag
      ##   G_APPLICATION_NON_UNIQUE, however that may be represented
      ##   in the Ruby API. If it was defined as such, TBD side effects
      @logger.fatal("Unable to register #{self}")
    ## NB DNW: calling Gtk.main after A) the app is closed, B) Gtk.main_quit
    ##
    ## FIXME define a service implementation of this app,
    ## such that can be used from IRB
    else
      ## TBD storing main_thread - see also the GMain loop API via Ruby ...
      @main_thread = Thread.current
      ## FIXME bind to an 'initialized' signal, with a proc
      ## that will @syncMtx.synchronize { @syncCv.signal }

      ## super(gtk_cmdline_args) # TBD
      @logger.debug("#{__method__} calling Gtk.main in #{Thread.current}")
      # @state = :run
      begin
        @sigtrap_trap_previous = Signal.trap("TRAP") do
          ## cf. devehlp @ GLib g_log_structured, G_BREAKPOINT documentation
          ## => SIGTRAP (some architectures)
          LogModule.with_system_warn {
            ## NB ensuring that the logger won't be called during a
            ## signal trap - the system could emit a warning then ...
            ##   >> "log writing failed. can't be called from trap context"
            ## ... such that may fail recursively, if the only warning
            ## handler would be trying to dispatch to a logger
            warn "Received SIGTRAP. Exiting in #{Thread.current.inspect}"
            Gtk.main_quit
            trap("TRAP",sigtrap_trap_previous)
            exit(SysExit::EX_SOFTWARE)
          }
        end
        sigtrap_int_previous = Signal.trap("INT") do
          LogModule.with_system_warn {
            warn "Received SIGINT. Exiting in #{Thread.current.inspect}"
            Gtk.main_quit
            trap("INT",sigtrap_int_previous)
            exit(SysExit::EX_IOERR)
          }
        end
        sigrap_abrt_previous = Signal.trap("ABRT") do
          LogModule.with_system_warn {
            warn "Received SIGABRT. Exiting in #{Thread.current.inspect}"
            Gtk.main_quit
            trap("ABRT",sigtrap_abrt_previous)
            exit(SysExit::EX_PROTOCOL)
          }
        end

        @logger.debug("In process #{Process.pid}")

        ## NB this will display information about exeptions raised
        ## within Ruby, including exceptions that are captured
        ## within some rescue form
        ##
        ## This is also reached from 'exit'
        ##
        ## This TracePoint is not reached for the peculiar
        ## NoMethodError denoted below - that might be emitted from C
        trace = TracePoint.new(:raise) do |pt|
          pt_exc = pt.raised_exception
          pt_path = pt.path
          ## exceptions to ignore
          ign_exc = [RDoc::Store::MissingFileError,
                     RubyLex::TerminateLineInput,
                     SyntaxError]
          unless (ign_exc.member?(pt_exc.class))
            puts("[debug] %s %s [%s] @ %s:%s" %
                 [pt.event, pt_exc.class,
                  pt_exc.message,
                  pt_path, pt.lineno])
          end
        end
        trace.enable

        Gtk.main() ## FIXME use GtkFramework


        ## FIXME in this source file, store every return value from
        ## signal_connect within an array of signal callback IDs.
        ## On each element of that array, call signal_handler_disconnect(elt).
        ## Call this array-walking method as a part of
        ## unref/free/pre-finalization routines, during exit.
      rescue => exc
        ## FIXME does not trap Ruby errors raised under Gtk.main,
        ## such that cause the application to exit without further
        ## action

        warn "Exception #{exc.class}: #{exc}"

       exc.backtrace.each { |info| warn "[backtrace] " + info.to_s } if exc.backtrace

      end
    end
    @logger.debug("#{__method__} returning in #{Thread.current}")
    if Thread.current.status == "aborting"
      ## NB This may be reached - on a Linux system - when ...
      ## 1) the app is run via run_threaded
      ## 2) SIGINT is sent to the ruby process, externally
      ## 3) a dialogue window is created
      ##
      ## - note that the SIGINT handler was not reached under
      ##   run_threaded, not until the dialogue window was created
      ## - that may be due to some peculiarities about where the trap
      ##   handler is defined, and how Gtk.main is run x threads
      ##
      ## TBD whether this or the handler is ever reached under
      ## run_threaded, on a BSD system
      warn "Uncaught thread abort. Exiting"
      Thread.current.backtrace_locations.each { |info|
        warn "[backtrace] " + info.to_s
      } if Thread.current.backtrace_locations
      exit(false)
    end
  end

  def run_threaded()  ## FIXME move to GLibApp (glib_app.rb)
    ## FIXME this thread appears to no longer run asynchronously,
    ## when launched under IRB
    ##
    ## The thread is returned to IRB and displayed as such,
    ## but the next IRB propmpt/input line does not appear until after
    ## the app has exited
    @logger.debug("#{__method__} from #{Thread.current}")
    NamedThread.new("%s#run @%x" % [self.class.name, self.object_id]) {
      run()
    }
  end

  def quit()
    @logger.debug("#{__method__} in #{Thread.current}")
    # @state = :quit
    self.windows.each { |w|
      @logger.debug("#{__method__} destroying window #{w} in #{Thread.current}")
      w.unmap
      w.destroy
    }
    super()
    @logger.debug("Gtk.main_quit in #{Thread.current}")
    ## NB this may be redundant here:
    Gtk.main_quit()
  end

  def add_window(window)
    @logger.debug("Adding window #{window} to #{self} (#{Thread.current})")
    super
  end

  def remove_window(window)
    @logger.debug("Removing window #{window} from #{self} (#{Thread.current})")
    super
  end

end

end ## PebblApp::GtkFramework module

# Local Variables:
# fill-column: 65
# End:
