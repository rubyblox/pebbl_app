## projectkit.gemspec

## NB this_dir provides a value other than __dir__, as that
## would be a relative path under eval by 'gem build'
this_dir=File.dirname(File.expand_path(__FILE__))

Kernel.load(File.join(this_dir,'../project_tools.rb'))
lib_name = Project.filename_no_suffix(__FILE__)
module_file = File.join("lib", lib_name + ".rb")
Kernel.load(File.join(this_dir, module_file))

lib_module = ::ProjectKit

$GEMSPEC = Gem::Specification.new do |s|
  Project.gemspec_common_config(s, this_dir, lib_module)
end
