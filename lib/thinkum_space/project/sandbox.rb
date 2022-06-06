## sandbox.rb --- module definition for ThinkumSpace::Project::Sandbox

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory.
  require(__dir__ + ".rb")
}

require 'thinkum_space/project/project_module'

module ThinkumSpace::Project::Sandbox
  include ThinkumSpace::Project::ProjectModule

  defautoloads({
    'sandbox/spec_tool' =>
      %w(SpecTool FileNotFound GemDataError GemQueryError GemSyntaxError),
  })
end
