## yspec.rb --- YAML-based configuration tooling for gemspecs

module ThinkumSpace
  module Project
    module Ruby
    end
  end
end

## here, psych becomes a dependency for bootstrapping a gemspec
require 'psych'

class ThinkumSpace::Project::Ruby::YSpec

  module Const
    PRIMARY_DEFAULT = %w(version summary description authors email licenses)
    OPTIONAL_DEFAULT = %w(required_ruby_version require_paths homepage
                          bindir executables)
    METADATA_DEFAULT = %w(module homepage_uri source_code_uri
                          changelog_uri allowed_push_host)
  end

  ## pathname for serialized YAML data for this YSpec instance
  attr_accessor :pathname

  ## required primary filelds to transfer from YAML into the gemspec
  attr_accessor :primary_fields

  ## optional primary filelds to transfer from YAML into the gemspec
  attr_accessor :optional_fields

  ## optional metadata filelds to transfer from YAML into the gemspec
  attr_accessor :metadata_fields

  class << self
    def configure_gem(spec, pathname)
      singleton = self.new(pathname)
      singleton.write_config(spec)
    end
  end

  ## Initialize a new YSpec instance
  def initialize(pathname)
    @pathname = pathname
    @primary_fields = Const::PRIMARY_DEFAULT
    @optional_fields = Const::OPTIONAL_DEFAULT
    @metadata_fields = Const::METADATA_DEFAULT
  end

  def write_config(spec)

    if ! (name = spec.name)
      raise new "THe provided gem specification has no name: #{spec}"
    end

    projdata = Psych.load_file(@pathname)

    if ! (gemdata = projdata['gems'][name])
      warn "No gem data found for gemspec #{name} in #{projinf}"
    end

    ##
    ## common data (required, optional) (gem field overrides project field)
    ##
    for field in @primary_fields
      data = ( gemdata[field] || projdata[field] )
      if data
        setmtd = field + "="
        spec.send(setmtd.to_sym, data)
      else
        warn "No #{field} data found for gemspec #{name}"
      end
    end

    for field in @optional_fields
      data = ( gemdata[field] || projdata[field] )
      if data
        setmtd = field + "="
        spec.send(setmtd.to_sym, data)
      end
    end

    if (homepage = spec.homepage)
      spec.metadata['homepage_uri'] = homepage
    end

    ##
    ## metadata (gem field overrides project field)
    ##
    for md in @metadata_fields
      data = ( gemdata[md] || projdata[md] )
      (spec.metadata[md] = data) if data
    end

    if homepage && !(src_uri = spec.metadata['source_code_uri'])
      spec.metadata['source_code_uri'] = homepage
    end

    if src_uri && !(changes_uri = spec.metadata['changelog_uri'])
      spec.metadata['changelog_uri'] = src_uri
    end

    ##
    ## source files (union of roject, gem fields)
    ##
    if (files = projdata['source_files'])
      files.each do |f|
        spec.files << f
      end
    end

    if (files = gemdata['source_files'])
      files.each do |f|
        spec.files << f
      end
    end


    ##
    ## resource files (union of project, gem fields)
    ##
    if (files = projdata['resource_files'])
      files.each do |f|
        spec.files << f
      end
    end

    if (files = gemdata['resource_files'])
      files.each do |f|
        spec.files << f
      end
    end

    ##
    ## runtime dependencies (union of project, gem fields)
    ##
    if (deps = projdata['depends'])
      deps.each do |inf|
        spec.add_runtime_dependency(inf)
      end
    end

    if (deps = gemdata['depends'])
      deps.each do |inf|
        spec.add_runtime_dependency(inf)
      end
    end

    ##
    ## development dependencies (union of project, gem fields)
    ##
    if (deps = projdata['devo_depends'])
      deps.each do |inf|
        spec.add_development_dependency(inf)
      end
    end

    if (deps = gemdata['devo_depends'])
      deps.each do |inf|
        spec.add_development_dependency(inf)
      end
    end

  end

end
