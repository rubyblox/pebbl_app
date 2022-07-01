## Definition of PebblApp::App

require 'pebbl_app/framework'

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
  class App


    ## configure this application
    ##
    ## This method forwards argv to the `configure` method on this
    ## application's #config object
    ##
    ## The provided argv may be destructively modified by this method
    def configure(argv: ARGV)
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

    ## activate the application
    ##
    ## The method provided here will pass the provided argv array to
    ## #configure.
    ##
    ## the provided argv may be destructively modified by this method
    def main(argv: ARGV)
      configure(argv: argv)
      start()
    end

    ## return the app name for this module
    ##
    ## If no app name has been configured as with app_name= then a
    ## default app name will be initialized from the module's name,
    ## with each Ruby namespace string "::" translated to a full stop
    ## character, "."
    ##
    ## @return [String] an app name
    ##
    ## @see app_name=
    def app_name
      @app_name ||=
        PebblApp::ProjectModule.s_to_filename(self.class, Const::DOT)
    end

    ## configure an app name for this module
    ##
    ## @param name [String] the app name to use
    ##
    ## @return [String] the provided name
    ##
    ## @see app_name
    def app_name=(name)
      @app_name = name
    end

    ## Return a directory basename for application files
    ##
    ## This default method returns a downcased from for the #app_name
    ##
    ## @return [String] the basename
    def app_dirname
      app_name.downcase
    end

    ## Return a shell command name for this application
    ##
    ## @return [String] the shell command name
    def app_command_name
      return $0
    end

    ## Return a FileManager, such that may be applied in computing any
    ## application filesystem directories for this app
    ##
    ## @return [FileManager] a FileManager instance
    def file_manager
      dirname = app_dirname
      # dirname = self.send(:app_dirname) ## also DNW
      @file_manager || FileManager.new(dirname)
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
      difference([:app_name, :app_name=, :app_dirname, :app_command_name, :config]).
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

  end ## App
end
