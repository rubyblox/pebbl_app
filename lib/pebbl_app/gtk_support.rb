## PebblApp::GtkSupport module definition

BEGIN {
  gem 'pebbl_app-support'
  require 'pebbl_app/project/project_module'
}

## prototyping - gem method for this individual module
require 'pebbl_app/project/spec_finder'

module PebblApp::GtkSupport
  include PebblApp::Project::ProjectModule
  self.source_path = __dir__

  ## return the first gem specification found within active
  ## gemspecs, for any gem providing this module's original
  ## source file under the gem's files list.
  ##
  ## this method may not return an expected value for any module
  ## including this module, unless overridden in the including
  ## module.
  ##
  ## @see PebblApp::Project::SpecFinder.find_for_file
  def self.gem
    return PebblApp::Project::SpecFinder.find_for_file(__FILE__)
  end

  defautoloads({
    "gtk_support/gtk_app_prototype" =>
      %w(GtkAppPrototype),
    "gtk_support/gtk_config" =>
      %w(GtkConfig),
    "gtk_support/exceptions" =>
      %w(ConfigurationError),
    "gtk_support/gir_proxy" =>
      %w(InvokerP FuncInfo),
    "gtk_support/logging" =>
      %w(LoggerDelegate LogManager LogModule),
    "gtk_support/threads" =>
      %w(NamedThread),
    "gtk_support/sysexit" =>
      %w(SysExit),
    "gtk_support/glib_type_ext" =>
      %w(GTypeExt),
    "gtk_support/gtk_type_ext" =>
      ## FIXME => WidgetBuilder
      %w(UIBuilder TemplateBuilder
         ResourceTemplateBuilder FileTemplateBuilder),
    "gtk_support/gbuilder_app" =>
      %w(GBuilderApp),
    "gtk_support/basedir" =>
      %w(FileResourceManager)
  })

end

# Local Variables:
# fill-column: 65
# End:
