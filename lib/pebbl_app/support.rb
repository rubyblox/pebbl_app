## PebblApp::Support module definition

require 'pebbl_app/project/project_module'

## prototyping - gem method for this individual module
require 'pebbl_app/project/spec_finder'

module PebblApp::Support
  ## configure this module for defautoload support
  include PebblApp::Project::ProjectModule
  self.source_path = __dir__

  ## return the first gem specification found within active
  ## gemspecs, for any gem providing this module's original
  ## source file under the gem's files list.
  ##
  ## this method may not return an expected value for any module
  ## including this module, unless overridden in the including
  ## module.
  ##
  ## @see PebblApp::Project::SpecFinder.find_for_file
  def self.gem
    return PebblApp::Project::SpecFinder.find_for_file(__FILE__)
  end

  ## support/const.rb will be required at the end of this source file

  defautoloads({
    "support/file_manager" =>
      %w(FileManager),
    "support/app_prototype" =>
      %w(AppPrototype),
    "support/app" =>
      %w(App),
    "support/config" =>
      %w(Config),
    "support/exceptions" =>
      %w(EnvironmentError),
    "support/files" =>
      %w(Files)
  })

end

## load all constants now
require_relative 'support/const'

# Local Variables:
# fill-column: 65
# End:
