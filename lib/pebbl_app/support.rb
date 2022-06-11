## PebblApp::Support module definition

BEGIN {
  gem 'pebbl_app-support'
  require 'pebbl_app/project/project_module'

}

## prototyping - gem method for this individual module
require 'pebbl_app/project/spec_finder'

module PebblApp::Support
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

  defautoloads({
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

# Local Variables:
# fill-column: 65
# End:
