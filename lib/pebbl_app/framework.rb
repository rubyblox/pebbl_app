## abstract Framework class for application support

#require 'pebbl_app'
require 'pebbl_app/project'

#require 'singleton'

module PebblApp

  ## @abstract bawe class for Framework implementations
  class Framework
  end

  class FrameworkError < RuntimeError
  end
end
