## module definition for PebblApp

module PebblApp
  class << self
    ## a rudimentary relative autoloads method
    ##
    ## this method provides some bootstrap support for autoload calls in
    ## this module
    ##
    ## @param name [Symbol, String] name of the symbol for which to
    ##        define an autoload in this module
    ##
    ## @param file [String] pathname for the autoload definition,
    ##        as an absolute pathname or relative to the directory of
    ##        the source file defining this module.
    ##
    ##        If the file does not exist when this method is called,
    ##        no autoload definition will created. If $DEBUG has a
    ##        truthy value at the time of call, a warning will be
    ##        emitted as to indicate the absence of the source file.
    def autoload(name, file)
      path = File.expand_path(file, __dir__)
      if File.exists?(path)
        ## The File.exists? test is used here, as this source file may
        ## be distributed in separate Ruby gems, such that each gem
        ## would not provide the entire source tree of the original
        ## development project.
        super(name, path)
      else
        Kernel.warn(
          "Not defining autoload for %s::%s - file not found: %s" % [
            self, name, file
          ]) # if $DEBUG
      end
    end ## self.autoload method
  end ## class << self

  autoload(:AppConfigError, 'pebbl_app/app_mixin.rb')
  autoload(:AppMixin, 'pebbl_app/app_mixin.rb')
  autoload(:App, 'pebbl_app/app.rb')
  autoload(:Const, 'pebbl_app/const.rb')
  autoload(:Files, 'pebbl_app/files.rb')
  autoload(:FileManager, 'pebbl_app/file_manager.rb')
  autoload(:Framework, 'pebbl_app/framework.rb')
  autoload(:EnvironmentError, 'pebbl_app/exceptions.rb')
  autoload(:FreezeUtil, 'pebbl_app/freeze_util.rb')
  autoload(:LoggerMixin, "pebbl_app/logger_mixin.rb")
  autoload(:AppLoggerMixin, "pebbl_app/logger_mixin.rb")
  autoload(:Project, 'pebbl_app/project.rb')
  autoload(:ProjectModule, 'pebbl_app/project_module.rb')
  autoload(:Shell, 'pebbl_app/shell.rb')
  autoload(:SignalMap, 'pebbl_app/signals.rb')
  autoload(:YSpec, 'pebbl_app/y_spec.rb')

  %i(ConfigurationError Conf).each do |cls|
    autoload(cls, 'pebbl_app/conf.rb')
  end

  %i(IVarUnbound AttrProxy).each do |cls|
    autoload(cls, 'pebbl_app/attr_proxy.rb')
  end

  %i(AppLogFormatter AppLogDev StreamLogDev ConsoleLogDev
     ProcessLogDev MultilogDev AppLog).each do |cls|
    autoload(cls, 'pebbl_app/app_log.rb')
  end

  ## distributed with the pebbl_app-gtk_suport gem
  ## (require separately)
  # autoload(:GtkFramework, 'pebbl_app/gtk_framework.rb')

end
