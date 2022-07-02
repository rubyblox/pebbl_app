## LoggerMixin for PebblApp

require 'pebbl_app'

module PebblApp

  ## Logger support
  ##
  ## This module can be applied via 'include'. Once included, the module
  ## will define a `logger` attribute reader on the `@logger` instance
  ## variable. The methods `debug`, `error`, `fatal`, `info` and
  ## `warn` will be defined in the including namespace, forwarding to
  ## the `@logger` instance variable.
  ##
  ## The including class should ensure that a Logger is initialized as
  ## @logger
  module LoggerMixin
    def self.included(whence)
      ## Logger for this class
      whence.attr_reader :logger
    end
    def debug(message)
      if instance_variable_defined?(:@logger)
        log = instance_variable_get(:@logger)
        log.add(Logger::DEBUG, message)
      else
        Kernel.warn(message, uplevel: 1)
      end
    end
    def error(message)
      if instance_variable_defined?(:@logger)
        log = instance_variable_get(:@logger)
        log.add(Logger::ERROR, message)
      else
        Kernel.warn(message, uplevel: 1)
      end
    end
    def fatal(message)
      if instance_variable_defined?(:@logger)
        log = instance_variable_get(:@logger)
        log.add(Logger::FATAL, message)
      else
        Kernel.warn(message, uplevel: 1)
      end
    end
    def info(message)
      if instance_variable_defined?(:@logger)
        log = instance_variable_get(:@logger)
        log.add(Logger::INFO, message)
      else
        Kernel.warn(message, uplevel: 1)
      end
    end
    def warn(message)
      if instance_variable_defined?(:@logger)
        log = instance_variable_get(:@logger)
        log.add(Logger::WARN, message)
      else
        Kernel.warn(message, uplevel: 1)
      end
    end

  end ## LoggerMixinin

  module AppLoggerMixin
    def self.included(whence)
      def debug(message)
        if instance_variable_defined?(:@app_log)
          log = instance_variable_get(:@app_log)
          log.add(Logger::DEBUG, message)
        else
          Kernel.warn(message, uplevel: 1)
        end
      end
      def error(message)
        if instance_variable_defined?(:@app_log)
          log = instance_variable_get(:@app_log)
          log.add(Logger::ERROR, message)
        else
          Kernel.warn(message, uplevel: 1)
        end
      end
      def fatal(message)
        if instance_variable_defined?(:@app_log)
          log = instance_variable_get(:@app_log)
          log.add(Logger::FATAL, message)
        else
          Kernel.warn(message, uplevel: 1)
        end
      end
      def info(message)
        if instance_variable_defined?(:@app_log)
          log = instance_variable_get(:@app_log)
          log.add(Logger::INFO, message)
        else
          Kernel.warn(message, uplevel: 1)
        end
      end
      def warn(message)
        if instance_variable_defined?(:@app_log)
          log = instance_variable_get(:@app_log)
          log.add(Logger::WARN, message)
        else
          Kernel.warn(message, uplevel: 1)
        end
      end
    end ## AppLoggerMixin included

    def self.extended(whence)
      class << whence
        def debug(message)
          if class_variable_defined?(:@@app_log)
            log = class_variable_get(:@@app_log)
            log.add(Logger::DEBUG, message)
          else
            Kernel.warn(message, uplevel: 1)
          end
        end
        def error(message)
          if class_variable_defined?(:@@app_log)
            log = class_variable_get(:@@app_log)
            log.add(Logger::ERROR, message)
          else
            Kernel.warn(message, uplevel: 1)
          end
        end
        def fatal(message)
          if class_variable_defined?(:@@app_log)
            log = class_variable_get(:@@app_log)
            log.add(Logger::FATAL, message)
          else
            Kernel.warn(message, uplevel: 1)
          end
        end
        def info(message)
          if class_variable_defined?(:@@app_log)
            log = class_variable_get(:@@app_log)
            log.add(Logger::INFO, message)
          else
            Kernel.warn(message, uplevel: 1)
          end
        end
        def warn(message)
          if class_variable_defined?(:@@app_log)
            log = class_variable_get(:@@app_log)
            log.add(Logger::WARN, message)
          else
            Kernel.warn(message, uplevel: 1)
          end
        end
      end
    end ## AppLoggerMixin extended
  end
end
