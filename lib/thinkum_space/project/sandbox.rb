## ruby.rb --- module definition for ThinkumSpace::Project::Ruby

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory.
  require(__dir__ + ".rb")
}

require 'thinkum_space/project/project_module'

module ThinkumSpace::Project::Ruby
  include ThinkumSpace::Project::ProjectModule

  defautoloads_file('ruby/spec_tool',
                    %w(SpecTool FileNotFound GemDataError GemQueryError GemSyntaxError))
  defautoloads_file('ruby/y_spec', %w(YSpec))

end
