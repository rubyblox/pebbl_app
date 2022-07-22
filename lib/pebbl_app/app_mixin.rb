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
  ## - app_name, app_name=
  ## - app_dirname
  ## - app_env_name
  ## - app_command_name
  ## - #file_manager and methods forwarding to the same
  ## - #config
  module AppMixin

    class << self
      ## @private Utility method for the mixin implementation of PebblApp::AppMixin
      def def_class_name_field(scope, name, &block)
        reader_name = name.to_sym
        classvar = ("@@" +  name.to_s).to_sym
        writer_name = (reader_name.to_s + "=").to_sym
        scope.define_method(writer_name,
                            ## not inherited properly for subclasses ...
                            -> (val) {
                              if scope.class_variable_defined?(classvar)
                                ## FIXME use a more specific exception class
                                raise RuntimeError.new(
                                  "Field is already bound in %s: %s" % [
                                  scope, reader_name
                                ])
                              else
                                scope.class_variable_set(classvar, val)
                              end
                            })
        ## the reader method will be returned, after definition
        scope.define_method(reader_name,
                            -> () {
                              if scope.class_variable_defined?(classvar)
                                scope.class_variable_get(classvar)
                              else
                                val = block.yield(name)
                                scope.class_variable_set(classvar, val)
                              end
                            })
      end
    end ## class <<

    def self.extended(whence)

      ## @!method app_name
      ##
      ## return an app name for this application class.
      ##
      ## Once set, this value may be used for deriving default values
      ## for each of the app_dirname and app_env_name fields. If a
      ## non-default value will be used, the value should be set with
      ## app_name= before any call to app_name.
      ##
      ##
      ## @return [String] the application name
      ##
      ## @see app_name=
      ##
      ## @see app_dirname
      ##
      ## @see app_env_name
      ##
      ## @see app_command_name
      ##
      ## @!method app_name=
      ## Set the application name for this application class
      ##
      ## This method may be called at most once, and must be called before
      ## any call to the app_name, app_dirname, or app_env_name reader
      ## methods
      ##
      ## If not set, the default value will be interpolated from the
      ## implementing class' name, using PebblApp::ProjectModule.s_to_filename
      ##
      ## @param name [String] the application name to use
      ##
      ## @see app_name
      AppMixin.def_class_name_field(whence.singleton_class, :app_name) do
        ## Fixme move this to the Gio::Application thing and rename => app_id
        PebblApp::ProjectModule.s_to_filename(whence.name, Const::DOT).freeze
      end


      ## @!method app_dirname
      ##
      ## Return a directory basename for application files for this
      ## applicaiton class
      ##
      ## @return [String] the basename
      ##
      ## @!method app_dirname=
      ## Set the directory basename for this application class
      ##
      ## This method may be called at most once, and must be called before
      ## any call to the app_dirname or app_env_name reader methods
      ##
      ## If not set, the default value will be interpolated as the
      ## string downcase representation of the app_name field
      ##
      ## @param name [String] the base directory name to use
      ##
      ## @see app_dirname
      AppMixin.def_class_name_field(whence.singleton_class, :app_dirname) do
        whence.app_name.downcase
      end


      ## @!method app_env_name
      ##
      ## Return a variable name prefix for environment variables
      ## configuring this application class
      ##
      ## @return [String] the environment variable name prefix
      ##
      ## @see app_env_name=
      ##
      ## @!method app_env_name=
      ## Set an environment variable name prefix for the application
      ## class
      ##
      ## This method may be called at most once, and must be called before
      ## any call to app_env_name
      ##
      ## If not set, the default value will be interpolated as the
      ## string upcase representation of the the first non-dot segment
      ## of the app_name field
      ##
      ## @param name [String] the envrionment variable name prefix to use
      ##
      ## @see app_env_name
      AppMixin.def_class_name_field(whence.singleton_class, :app_env_name) do
        whence.app_name.split(Const::DOT).last.upcase
      end

      ## @!method app_command_name
      ## Return a shell command name for this application
      ##
      ## @return [String] the shell command name
      ##
      ## @see app_command_name=
      ##
      ## @!method app_command_name=(name)
      ## This method may be called at most once, and must be called before
      ## any call to app_command_name.
      ##
      ## If not set, the default value will be interpolated as the
      ## file basename of the value of `$0`
      ##
      ## @param name [String] the command name to use
      ##
      ## @see app_command_name
      AppMixin.def_class_name_field(whence.singleton_class, :app_command_name) do
        File.basename($0)
      end

      whence.singleton_class.extend Forwardable
      ## Forward to each class method defined originally on
      ## FileManager, from a method of the same name defined on the
      ## including class
      PebblApp::FileManager.methods(false).map do |mtd|
        if PebblApp::FileManager.method(mtd).public?
          whence.singleton_class.def_delegator(PebblApp::FileManager, mtd)
        end
      end

    end ## AppMixin.extended


    def self.included(whence)
      ## Add all mixin class methods
      whence.extend self

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


    ## Return a FileManager, such that may be applied in computing any
    ## application filesystem directories for this app
    ##
    ## @return [FileManager] a FileManager instance
    def file_manager
      @file_manager ||= FileManager.new(self.class.app_dirname,
                                        self.class.app_env_name)
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

  end ## AppMixin
end
