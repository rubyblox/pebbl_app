## gappkit.rb - baseline module definition and autoloads

## FIXME move to a separate gappkit gem,
## and add to a work area decl. for the riview app

gem 'thinkum_space-project'
require 'thinkum_space/project/project_module'

module GAppKit
  include ThinkumSpace::Project::ProjectModule

  defautoloads({
    "gappkit/logging" =>
      %w(LoggerDelegate LogManager LogModule),
    "gappkit/threads" =>
      %w(NamedThread), ## FIXME move to a generic appkit gem
    "gappkit/sysexit" =>
      %w(SysExit),
    "gappkit/glib_type_ext" =>
      %w(GTypeExt),
    "gappkit/gtk_type_ext" =>
      %w(UIBuilder TemplateBuildeer
         ResourceTemplateBuilder FileTemplateBuilder),
    "gappkit/gbuilder_app" =>
      %w(GBuilderApp),
    "gappkit/basedir" =>
      %w(FileResourceManager)
  })

end

# Local Variables:
# fill-column: 65
# End:
