## projectkit.gemspec -- gemspec for ProjectKit

require_relative '../lib/thinkum_space/project/ruby/y_spec'
## ^ FIXME this is not portable outside of the original source tree

Gem::Specification.new do |s|

  name = File.basename(__FILE__).split("\.")[0]
  s.name = name

  projinf = File.expand_path("../project.yaml", __dir__)

  ThinkumSpace::Project::Ruby::YSpec.configure_gem(s, projinf)
  s.metadata['resource_root'] = __dir__

  s.files << %q(lib/projectkit/rspectool.rb)
end
