## pebbl_app-support.gemspec

require_relative 'lib/pebbl_app/project/y_spec'

Gem::Specification.new do |s|

  name = File.basename(__FILE__).split("\.")[0]
  s.name = name

  projinf = File.expand_path("project.yaml", __dir__)

  PebblApp::Project::YSpec.configure_gem(s, projinf)
  # s.metadata['resource_root'] = __dir__

end
