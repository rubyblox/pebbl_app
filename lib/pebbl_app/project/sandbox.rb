## sandbox.rb --- module definition for PebblApp::Project::Sandbox

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory.
  require(__dir__ + ".rb")
}

require 'pebbl_app/project/project_module'

module PebblApp::Project::Sandbox
  include PebblApp::Project::ProjectModule

  defautoloads({
    'sandbox/spec_tool' =>
      %w(SpecTool FileNotFound GemDataError GemQueryError GemSyntaxError),
  })
end
