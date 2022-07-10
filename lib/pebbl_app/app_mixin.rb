## Definition of PebblApp::AppMixin

require 'pebbl_app'

require 'forwardable'
require 'open3'
require 'optparse'

module PebblApp

  ## Generalized App support for PebblApp
  ##
  ## Methods for Application Initialization:
  ## - #configure, see #config
  ## - #start
  ## - #main
  ##
  ## Methods for Application Metadata, defined when this module is
  ## included in an impelemnting class:
  ## - #app_name, #app_name=
  ## - #app_dirname
  ## - #app_command_name
  ## - #file_manager and methods forwarding to the same
  ## - #config
  module AppMixin

    class << self
      def pop_opt(name, opts, &fallback)
        kwd = name.to_sym
        if opts.include?(kwd)
          opts.delete(kwd)
        elsif block_given?
          fallback.yield
        end
      end
    end ## class <<

    def self.included(whence)
      whence.extend Forwardable

      def initialize(*args)
        opts = args.last
        if Hash === opts
          @app_name = AppMixin.pop_opt(:app_name, opts) do
            PebblApp::ProjectModule.s_to_filename(self.class, Const::DOT).freeze
          end
          @app_dirname = AppMixin.pop_opt(:app_dirname, opts) do
            (@app_name && @app_name.downcase)
          end
          @app_env_name = AppMixin.pop_opt(:app_env_name, opts) do
            (@app_dirname && @app_dirname.split(Const::DOT).last.upcase)
          end
          if opts.empty?
            ## remove the option hash from args, before forwarding
            ## to any actual class constructor
            args.pop
          end
        end
        super(*args)
      end

      ## Return the SignalMap for this application
      ##
      ## @see #set_sys_trap
      ## @see #bind_sys_trap
      ## @see #with_sys_trap
      def sys_trap_bindings
        @sys_trap_bindings ||= SignalMap.new
      end

      ## Bind a callback for later signal trap binding
      ##
      ## After the signal trap binding is activated, then when the named
      ## signal is received by this process, the callback proc will
      ## receive two args: The signal name and any previous signal trap
      ## binding for that signal.
      ##
      ## If the previous signal handler should be evaluated within the
      ## new signal trap handler, a proc for the handler may be
      ## retrieved by passing the previous signal binding (second
      ## arg to the callback) to the method SignalMap.proc_for_handler.
      ##
      ## **Limitations on Signal Trap Callbacks**: As a known feature, the
      ## callback should avoid making any calls to Mutex#synchronize or
      ## Mutex#lock
      ##
      ## (forwarding method)
      ##
      ## @param name (see SignalMap#set_handler)
      ## @param block (see SignalMap#set_handler)
      ## @see #sys_trap_bindings
      ## @see #with_sys_trap for reentrant evaluation with signal trap handlers
      ## @see #bind_sys_trap for other evaluation with signal trap handlers
      def set_sys_trap(name, &block)
        sys_trap_bindings.set_handler(name, &block)
      end

      ## Evaluate the block within a duration in which all signal
      ## handlers defined via #bind_sys_trap will be active as
      ## signal trap handlers for this process.
      ##
      ## If a signal cannot be bound for any of the handlers, a warning
      ## will be emitted.
      ##
      ## On normal return or on non-local return via throw or error, any
      ## signal handlers as previously initialized in the process will be
      ## restored.
      ##
      ## **Thread Safety Advisory:** This method operates on signal
      ## bindings in the operting system's process scope and should
      ## be called from at most one thread in each process.
      ##
      ## (forwarding method)
      ##
      ## @see SignalMap#with_handlers
      ## @see #sys_trap_bindings
      ## @see #bind_sys_trap for other evaluation with signal trap handlers
      def with_sys_trap(&block)
        sys_trap_bindings.with_handlers(&block)
      end

      ## Bind all signal trap handlers defined with #set_sys_trap
      ##
      ## If a block is provided, two args will be yielded to that block,
      ## for each binding: A signal name provided to set_sys_trap
      ## and any previous trap for that signal.
      ##
      ## If any previous trap binding should be handled after this call,
      ## a proc can be retrieved for each previous binding by passing the
      ## binding's object to the method SignalMap.proc_for_handler
      ##
      ## (forwarding method)
      ##
      ## @see SignalMap#bind_handlers
      ## @see #sys_trap_bindings
      ## @see #with_sys_trap for reentrant evaluation with signal trap handlers
      def bind_sys_trap(&block)
        sys_trap_bindings.bind_handlers(&block)
      end

      ## Handle the SIGINT signal. This method may be called within a
      ## signal trap handler for the active process.
      ##
      ## This method calls #quit on the implementing application
      ##
      ## @see #map_sys_trap
      def handle_int_trap(previous)
        AppLog.warn("Interrupt trap")
        quit
      end

      ## Handle the SIGTERM signal. This method may be called within a
      ## signal trap handler for the active process.
      ##
      ## This method calls #quit and then `exit`
      ##
      ## @see #map_sys_trap
      def handle_term_trap(previous)
        AppLog.warn("Terminating on signal")
        quit
        exit
      end

      ## Handle the SIGQUIT signal. This method may be called within a
      ## signal trap handler for the active process.
      ##
      ## This method calls #quit and then `exit`
      ##
      ## @see #map_sys_trap
      def handle_quit_trap(previous)
        AppLog.warn("Quitting on signal")
        quit
        exit
      end

      ## Handle the SIGUSR1 signal. This method may be called within a
      ## signal trap handler for the active process.
      ##
      ## Where supported, this method may also be reached from a signal
      ## trap handler for the SIGINFO signal
      ##
      ## As with other signal trap handlers, this method may be
      ## overidden in an implementing class, e.g to present informative
      ## output about an application's runtime state via AppLog
      ##
      ## This default method will produce no output
      ##
      ## @see #map_sys_trap
      def handle_usr1_trap(previous)
        ## nop
      end

      ## Configure a default set of signal trap bindings for the
      ## implementing class.
      ##
      ## @see #set_sys_trap
      ## @see #bind_sys_trap
      ## @see #handle_int_trap
      ## @see #handle_term_trap
      ## @see #handle_quit_trap
      ## @see #handle_usr1_trap
      def map_sys_trap()
        set_sys_trap("INT") do |signal, previous|
          handle_int_trap(previous)
        end
        set_sys_trap("TERM") do |signal, previous|
          handle_term_trap(previous)
        end
        set_sys_trap("QUIT") do |signal, previous|
          handle_quit_trap(previous)
        end
        set_sys_trap("USR1") do |signal, previous|
          handle_us1_trap(previous)
        end
        ## FIXME use extconf.rb to determine if this host implements SIGINFO
        set_sys_trap("INFO") do |signal, previous|
          handle_usr1_trap(previous)
        end
      end

    end ## included


    ## configure this application
    ##
    ## This method definmes any signal trap bindings with #map_sys_trap,
    ## then applies those trap bindings with #bind_sys_trap.
    ##
    ## This method will then forward argv to the `configure` method on
    ## the #config object for the implementing class.
    ##
    ## The provided argv may be destructively modified by this method
    def configure(argv: ARGV)
      map_sys_trap
      bind_sys_trap
      # AppLog.info("configure for AppMixin")
      config.configure(argv: argv)
    end

    ## prototype method, should be overridden in implementing classes
    ##
    ## called from #main, after #configure
    ##
    ## @see GtkApp#start
    def start()
      Kernel.warn("Reached prototype #{__method__} method", uplevel: 0)
    end

    ## prototype method, may be overridden in an implementing class
    ##
    ## This method will exit the process, without cleanups for threads
    ## or other resources
    ##
    ## The #quit method in an implemneting class may be reached from a
    ## signal trap callback bound with the default #map_sys_trap method
    ##
    def quit()
      exit
    end

    ## return an app name for this application
    ##
    ## If no app name has been configured then a
    ## default app name will be interpolated from the implementing
    ## class' name, using PebblApp::ProjectModule.s_to_filename
    ##
    ## If an implementing class overrides this method, the
    ## implementation should ensure that other values derived from this
    ## method will be updated in the implementing class
    ##
    ## @return [String] an app name
    ##
    ## @see #app_dirname
    ##
    ## @see #app_env_name
    ##
    ## @see #app_command_name
    def app_name
      @app_name ||=
      PebblApp::ProjectModule.s_to_filename(self.class, Const::DOT).freeze
    end

    ## Return a directory basename for application files
    ##
    ## An implementing class overriding this method should ensure that
    ## the value stays synchronized with the app_dirname field in the
    ## file_manager for the extending instance.
    ##
    ## Generally, if the file manager's @app_dirname is changed before
    ## this variable is accessed for read, then the updated value should
    ## be reflected on first read for this method.
    ##
    ## @return [String] the basename
    def app_dirname
      if name = @app_dirname
        name
      elsif (mgr = @file_manager)
        ## not bound locally, but a file manager has been initialized.
        ## forward to the file manager and bind here
        @app_dirname ||= mgr.app_dirname
      else
        app_name.downcase
      end
    end

    ## Return a variable name prefix for environment variables for this
    ## application
    ##
    ## An implementing class overriding this method should ensure that
    ## the value stays synchronized with the app_env_name field in the
    ## file_manager for the extending instance.
    ##
    ## Generally, if the file manager's @app_env_name is changed before
    ## this variable is accessed for read, then the updated value should
    ## be reflected on first read for this method.
    ##
    def app_env_name
      if name = @app_env_name
        name
      elsif (mgr = @file_manager)
        ## not bound locally, but a file manager has been initialized.
        ## forward to the file manager and bind here
        @app_env_name = @file_manager.app_env_name
      else
        app_dirname.split(Const::DOT).last.upcase
      end
    end

    ## Return a shell command name for this application
    ##
    ## @return [String] the shell command name
    def app_command_name
      @app_command_name ||= File.basename($0)
    end

    ## Return a FileManager, such that may be applied in computing any
    ## application filesystem directories for this app
    ##
    ## @return [FileManager] a FileManager instance
    def file_manager
      @file_manager ||= FileManager.new(app_dirname, app_env_name)
    end

    ## Return this app's Conf object
    ##
    ## @return [Conf] the Conf object
    def config
      @config ||= Conf.new() do
        ## defer access to the app_command_name field,
        ## which should be configured before #configure' is called
        self.app_command_name
      end
    end

    ## Forwarding to each reader-type public instance method from
    ## FileManager, excepting those methods hard-coded here
    ##
    ## Ensure that a file manager is initialized to the instance,
    ## before forwarding
    PebblApp::FileManager.public_instance_methods(false).
      difference([:app_name, :app_env_name, :app_dirname, :app_command_name, :config]).
      each do |mtd|
        impl = PebblApp::FileManager.instance_method(mtd)
        if impl.arity.eql?(0) && impl.parameters.empty?
          self.define_method(mtd, lambda { self.file_manager.send(mtd) })
        end
      end

    class << self
      extend Forwardable
      ## Forward to each class method defined originally on
      ## FileManager, from a method of the same name defined on the
      ## including class
      PebblApp::FileManager.methods(false).map do |mtd|
        if PebblApp::FileManager.method(mtd).public?
          def_delegator(PebblApp::FileManager, mtd)
        end
      end
    end

  end ## AppMixin
end
