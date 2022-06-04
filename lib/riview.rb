## riview.rb - baseline module definition and autoloads

require 'rubygems'

gem 'thinkum_space-project'
require 'thinkum_space/project/project_module'

module RIView
  include ThinkumSpace::Project::ProjectModule

  RESOURCE_ROOT ||=
    Gem::Specification::find_by_name(self.to_s.downcase).full_gem_path.freeze

  defautoloads({
    "riview/riview_app" =>
      %w(RIViewApp RIViewWindow TreeBuilder),
    "riview/dataproxy" =>
      %w(DataProxy)
  })

end

# Local Variables:
# fill-column: 65
# End:
