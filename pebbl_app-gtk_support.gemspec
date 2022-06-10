## pebbl_app-gtk_support.gemspec

## this assumes that $LOAD_PATH is configured to include ./lib
## such that will be provided under the project Gemfile
require 'pebbl_app/project/y_spec'

Gem::Specification.new do |s|

  ## FIXME define support for gemspec extensions
  ## => glib-compile-resources, glib-compile-schemas
  ## and if any gettext support is available
  ##
  ## plus integration for configuring a resource root
  ## (defaulting to the gemspec dir) for a module denoted
  ## in a 'module' field of gemspec metadata
  ##
  ## subsq. using the module's resource root
  ## when determining a pathname for any glib reosurce bundle
  ## and any gconf schema ... files (needs API support @ gappkit)

  name = File.basename(__FILE__).split("\.")[0]
  s.name = name

  projinf = File.expand_path("project.yaml", __dir__)

  yspec = PebblApp::Project::YSpec.new(projinf)
  yspec.write_config(s)
  # s.metadata['resource_root'] = __dir__
end

