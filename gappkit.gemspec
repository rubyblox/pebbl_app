## gappkit.gemspec

## FIXME projectkit refactoring (projectutils/projectkit)

## here, psych becomes a dependency for bootstrapping a gemspec
require 'psych'

Gem::Specification.new do |s|

  projinf = File.expand_path("project.yaml", __dir__)
  projdata = Psych.load_file(projinf)

  name = File.basename(__FILE__).split("\.")[0]
  s.name = name

  if ! (gemdata = projdata['gems'][name])
    raise "No gem data found for gemspec #{name} in #{projinf}"
  end

  ##
  ## common data (gem field overrides project field)
  ##
  for field in %w(version summary description authors emails licenses)
    data = ( gemdata[field] || projdata[field] )
    if data
      setmtd = field + "="
      s.send(setmtd.to_sym, data)
    else
      warn("No %s data found for gemspec %s"  % [field, name])
    end
  end

  ##
  ## metadata (gem field overrides project field)
  ##
  for md in %w(module)
    data = ( gemdata[md] || projdata[md] )
    (s.metadata[md] = data) if data
  end

  ##
  ## resource files (common project, gem fields)
  ##
  if (files = projdata['resource_files'])
      files.each do |f|
        s.files << f
      end
  end

  if (files = gemdata['resource_files'])
       files.each do |f|
        s.files << f
      end
  end

  s.metadata['resource_root'] = __dir__

  ##
  ## runtime dependencies (common project, gem fields)
  ##
  if (deps = projdata['depends'])
    deps.each do |inf|
      s.add_runtime_dependency(inf)
    end
  end

  if (deps = gemdata['depends'])
    deps.each do |inf|
      s.add_runtime_dependency(inf)
    end
  end

  ##
  ## development dependencies (common project, gem fields)
  ##
  if (deps = projdata['depends'])
    deps.each do |inf|
      s.add_development_dependency(inf)
    end
  end

  if (deps = gemdata['depends'])
    deps.each do |inf|
      s.add_development_dependency(inf)
    end
  end

end
