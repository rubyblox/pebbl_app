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

      whence.extend Forwardable
      whence.def_delegators(:@logger, :debug, :error, :fatal, :info, :warn)
    end
  end

end
