## Definition of PebblApp::Support::App

require 'pebbl_app/project/project_module'
require 'pebbl_app/support'

require 'forwardable'
require 'open3'
require 'optparse'

## :nodoc: Goals
## [X] provide support for pathname handling for applications
## [ ] provide support for parsing of application configuration data
##     in a YAML syntax, from directories configured per project
##     (e.g GEMFILE dir), per user (using XDG dirs) and per application
##     (also using XDG dirs)
## [ ] provide support for storing configuration data to a YAML syntax


module PebblApp::Support

  module AppPrototype

    ## :nodoc: FIXME none of the following methods have been defined with
    ## any particular attention for conventions on Microsoft Windows platforms,
    ## excepting the username method.
    ##
    ## Generally this assumes a POSIX-like ruby environment

    ## configure this application
    ##
    ## the provided argv may be destructively modified by this method
    def configure(argv: ARGV)
      config.configure(argv: argv)
    end

    ## activate the application
    ##
    ## The method provided here will pass the provided argv array to
    ## #configure.
    ##
    ## the provided argv may be destructively modified by this method
    def activate(argv: ARGV)
      configure(argv: argv)
      ## reduce memory usage, clearing the module's original autoloads
      ## definitions
      # PebblApp::Support.freeze unless self.config.option(:defer_freeze)
    end

    def self.included(whence)

      ## return the app name for this module
      ##
      ## If no app name has been configured as with app_name= then a
      ## default app name will be initialized from the module's name,
      ## with each Ruby namespace string "::" translated to a full stop
      ## character, ".".
      ##
      ## @return [String] an app name
      ##
      ## @see app_name=
      def app_name
        using = PebblApp::Project::ProjectModule
        const = PebblApp::Support::Const
        ## FIXME sets an instance variable - reimplement
        @app_name ||= using.s_to_filename(self.class, const::DOT)
      end

      ## configure an app name for this module
      ##
      ## @param name [String] the app name to use
      ##
      ## @return [String] the provided name
      ##
      ## @see app_name
      def app_name=(name)
        ## FIXME sets an instance variable - reimplement
        @app_name = name
      end

      def app_dirname
        app_name.downcase
      end

      def app_cmd_name
        ## FIXME this should be configured from app.yaml x Config
        return $0
      end

      def file_manager
        dirname = app_dirname
        # dirname = self.send(:app_dirname) ## also DNW
        @file_manager || FileManager.new(dirname)
      end

      def config
        @config ||= PebblApp::Support::Config.new() do
          ## defer access to the app_cmd_name field,
          ## which should be configured before #configure' is called
          self.app_command_name
        end
      end

      ## Forward to each reader-type public instance method from
      ## FileManager, excepting those methods hard-coded here
      ##
      ## Ensure that a file manager is initialized to the instance,
      ## before forwarding
      using = PebblApp::Support::FileManager
      using.public_instance_methods(false).
        difference([:app_name, :app_name=, :app_dirname, :app_cmd_name, :config]).
        each do |mtd|
          impl = using.instance_method(mtd)
          if impl.arity.eql?(0) && impl.parameters.empty?
            whence.define_method(mtd, lambda { self.file_manager.send(mtd) })
          end
        end

      class << whence
        extend Forwardable
        ## Forward to each class method defined originally on
        ## FileManager, from a method of the same name defined on the
        ## including class
        using = PebblApp::Support::FileManager
        using.methods(false).map do |mtd|
          if using.method(mtd).public?
            ##
            def_delegator(using, mtd)
          end
        end
      end

    end ## self.included

  end ## AppPrototype module
end
