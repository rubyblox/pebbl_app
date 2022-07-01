## riview.rb - baseline module definition and autoloads

## @private yard parser tries to document this 'require' call
##  due to the comment line just above
require 'rubygems'

gem 'pebbl_app-support'
require 'pebbl_app/project_module'

module RIView
  include PebblApp::ProjectModule

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
