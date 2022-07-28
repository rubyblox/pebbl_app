## pebbl-app_proto_vtytest.gemspec

## this assumes that $LOAD_PATH is configured to include ./lib
## such that will be processed in the project Gemfile
require 'pebbl_app/y_spec'

Gem::Specification.new do |s|

  name = File.basename(__FILE__).split("\.")[0]
  s.name = name
  s.loaded_from = __FILE__

  config = File.expand_path("project.yaml", __dir__)

  PebblApp::YSpec.configure_gem(s, config)

end
