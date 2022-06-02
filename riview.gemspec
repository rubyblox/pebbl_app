## riview.gemspec

## NB this_dir provides a value other than __dir__, as that
## would be a relative path under eval by 'gem build'
this_dir=File.dirname(File.expand_path(__FILE__))

Kernel.load(File.join(this_dir, '../project_tools.rb'))

lib_name = Project.filename_no_suffix(__FILE__)
module_file = File.join("lib", lib_name + ".rb")

Kernel.load(File.join(this_dir, module_file))

lib_module = ::RIView

resource_files = %w(ui/appwindow.glade ui/prefs.ui ui/docview.ui)

$GEMSPEC = Gem::Specification.new do |s|
  Project.gemspec_common_config(s, this_dir, lib_module,
                                extra_files: resource_files)
  s.add_runtime_dependency("gtk3")
  s.add_runtime_dependency("gappkit")
  s.add_runtime_dependency("rikit")
  #   s.add_development_dependency("projectkit")
end
