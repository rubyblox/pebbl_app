## support.rb --- GApp::Support module definition

BEGIN {
  gem 'thinkum_space-project'
  require 'thinkum_space/project/project_module'

  ## ensure that the module and any autoloads in the module will
  ## be defined, when loading this source file individually
  require 'g_app'
}


## prototyping
require 'thinkum_space/project/spec_finder'

module GApp::Support
  include ThinkumSpace::Project::ProjectModule
  self.source_path = __dir__

  ## return the first gem specification found within active
  ## gemspecs, for any gem providing this module's original
  ## source file under the gem's files list.
  ##
  ## this method may not return an expected value for any module
  ## including this module, unless overridden in the including
  ## module.
  ##
  ## @see ThinkumSpace::Project::SpecFinder.find_for_file
  def self.gem
    return ThinkumSpace::Project::SpecFinder.find_for_file(__FILE__)
  end

  defautoloads({
    "support/app_module" =>
      %w(AppModule),
    "support/logging" =>
      %w(LoggerDelegate LogManager LogModule),
    "support/threads" =>
      %w(NamedThread),
    "support/sysexit" =>
      %w(SysExit),
    "support/glib_type_ext" =>
      %w(GTypeExt),
    "support/gtk_type_ext" =>
      ## FIXME => WidgetBuilder
      %w(UIBuilder TemplateBuilder
         ResourceTemplateBuilder FileTemplateBuilder),
    "support/gbuilder_app" =>
      %w(GBuilderApp),
    "support/basedir" =>
      %w(FileResourceManager)
  })

end

# Local Variables:
# fill-column: 65
# End:
