## yspec.rb --- YAML-based configuration tooling for gemspecs

## bootstrap module definition, without autoloads
if !defined?(::ThinkumSpace::Project)
  module ThinkumSpace
    module Project
    end
  end
end

require 'rubygems'
require 'pathname'

## psych will serve as a dependency for bootstrapping a gemspec, here
require 'psych'

## YAML encoding for gemspec configuration
##
## The class method YSpec.configure_gem(spec, pathname) may be used to
## configure a gemspec from YAML-encoded data at a provided pathanme.
## This method dispatches primarily on the instance method #write_config
##
## FIXME the YAML format used here needs documentation. For an example
## of the YAML syntax, refer to the file project.yaml in this source
## file's original source repository. See also: OpenSchema (JSON, YAML?)
##
## FIXME provide a read_config instance method and a dump_config
## instance method, for application in transferring data values from a
## gemspec to a Psych YAML object, subsequently to a YAML file. This
## would be complimentary to the #write_config instance method, there
## writing data to a gemspec from YAML. This method should be defined as
## corresponding to a method for editor support, such as for reviewing
## the generated YAML.
##
## When serializing to YAML, then for differentiating any gem-local data
## to any project-local data in YAML output, consider using one or both
## of a format configuration declaration and/or a general guess from
## configuration data initially read from any output YAML file.
##
class ThinkumSpace::Project::YSpec

  ## Constants forThinkumSpace::Project::YSpec
  module Const
    GEMS_FIELD		||= 'gems'.freeze
    FILENAME_FIELD	||= 'filename'.freeze
    SRC_FIELD		||= 'source_files'.freeze
    DOCS_FIELD		||= 'docs'.freeze
    RESOURCE_FIELD	||= 'resource_files'.freeze
    DEVO_FIELD		||= 'devo_depends'.freeze
    DEPS_FIELD		||= 'depends'.freeze
    BDEPS_FIELD		||= 'build_depends'.freeze
    ALLDEPS_FIELDS	||= [BDEPS_FIELD, DEPS_FIELD, DEVO_FIELD].freeze
    WWW_FIELD		||= 'homepage'.freeze
    WWW_URI_FIELD	||= 'homepage_uri'.freeze
    SRC_URI_FIELD	||= 'source_code_uri'.freeze
    CHANGES_URI_FIELD	||= 'changelog_uri'.freeze
    REQUIRE_FIELD	||= 'require_path'.freeze
    REQUIRE_ENUM_FIELD	||= 'require_paths'.freeze

    ## required fields for general iteration
    PRIMARY_DEFAULT ||= %w(version summary description authors email
                           licenses
                          ).map { |name| name.freeze }.freeze
    ## optional fields for general iteration
    OPTIONAL_DEFAULT ||= %w(required_ruby_version homepage
                            bindir executables extensions extension_dir
                           ).map { |name| name.freeze }.freeze
    ## metadta fields for general iteration
    ##
    ## FIXME this will discard some custom YAML data
    METADATA_DEFAULT ||= %w(module homepage_uri source_code_uri
                            changelog_uri allowed_push_host
                           ).map { |name| name.freeze }.freeze

    GEM_REQUIREMENT_DEFAULT ||= Gem::Requirement.default.to_s.freeze
  end

  ## pathname for serialized YAML data for this YSpec instance
  attr_accessor :pathname

  ## required primary fields to transfer from YAML into the gemspec
  attr_accessor :primary_fields

  ## optional primary fields to transfer from YAML into the gemspec
  attr_accessor :optional_fields

  ## optional metadata fields to transfer from YAML into the gemspec
  attr_accessor :metadata_fields

  ## a configurable map for YAML field names onto setter symbols for a
  ## gemspec.
  ##
  ## Each key in this map should provide a string field name for YAML
  ## encoding in some project data file. The corresponding key's value
  ## should be a symbol indicating a method on a gemspec. The named
  ## method on the gemspec should accept one argument, i.e field
  ## data that was decoded from YAML and should be set into a configured
  ## gemspec.
  ##
  ## This configuration data will be used within #write_config
  attr_reader :writers_cache

  ## a configurable map, using the same syntax as the writers_cache attribute
  attr_reader :readers_cache

  ## project data decoded from YAML
  attr_accessor :proj_data
  ## name of the active gemspec within a single data session
  attr_accessor :gem_name
  ## subset of proj_data for the active gemspec within a single data session
  attr_accessor :gem_data

  class << self
    ## configure a gem specification from YAML data at a provided
    ## pathname
    ##
    ## For purpose of constiency in the set of Gem source files
    ## distributed with the configured gems, the YAML file itself will
    ## be added as a file in the gemspec
    ##
    ## **Thread Safety Warning** The instance returned from this method
    ## does not provide thread-safe access for configuration data in the
    ## instance. The instance should not be accessed concurrently within
    ## any more than one thread.
    ##
    ## @return [YSpec] a singleton YSpec instance, such that may be
    ##         reused within any single thread, such as for any
    ##         subsequent gemspec configuration from the same YAML
    ##         project data
    def configure_gem(spec, pathname)
      singleton = self.new(pathname)
      singleton.write_config(spec)
      return singleton
    end
  end

  ## Initialize a new YSpec instance
  ##
  ## **Thread Safety Warning:** Concurrent access to a single YSpec
  ##  instance, as from multiple threads, is not supported.
  ##
  ## @param pathname [String, Pathname] pathname for a YAML file.
  ##        This file should provide configuration data for project and
  ##        gem scopes (FIXME this syntax needs documentation)
  ## @see #write_config
  def initialize(pathname)
    @pathname = Pathname(pathname)
    ## default field names for method calls under #write_config
    @primary_fields = Const::PRIMARY_DEFAULT
    @optional_fields = Const::OPTIONAL_DEFAULT
    @metadata_fields = Const::METADATA_DEFAULT
    ## configuration state data, local to one gemspec writer session
    # @gem_name = nil
    # @gem_data = nil
    # @proj_data = nil
    @writers_cache ||= {}
    @readers_cache ||= {}
  end


  ## returm a writer method name for the spec field denoted as name
  ##
  ## If no writer method name has been configured in #writers_cache,
  ## this will return a symbol derived from the provided name suffixed
  ## with the string "="
  ##
  ## @param name [String, Symbol] a field name for an object's class,
  ##        such that an instance method is available in that class as
  ##        the field name suffixed with "="
  ## @see #writers_cache
  def writer_for(name)
    @writers_cache[name.to_s.freeze] ||= (name.to_s + "=").to_sym
  end

  ## returm a reader method name for a named objet field
  ##
  ## If no reader method name has been configured in the #readers_cache,
  ## this will return the name as a symbol
  ##
  ## @see: #readers_cache
  def reader_for(name)
    @readers_cache[name.to_s.freeze] ||= name.to_sym
  end

  ##
  ## load the active project configuration from the YAML pathname
  ## provided to this instance
  ##
  def load_config()
    ## this asumes that @gem_name was set for a present writer session
    begin
      @proj_data = Psych.safe_load_file(@pathname)
      return self
    rescue Psych::SyntaxError => e
      msg_warn("Error in project data %s", e)
      raise e
    end
  end

  ## return the value of a named named field in active project data. If
  ## no matching configuration data is found within the project scope in
  ## the project data, invoke any provided fallback block or return a
  ## default value.
  ##
  ## If project data has not been initialized in this instance, this
  ## method will call #load_config on the instance before operating on
  ## the configured project data.
  ##
  ## If no matching field is found in the active project configuration
  ## data and if a block was provided, then that block will be called
  ## with the provided field name. The block's return value will then
  ## provide the return value for this method. Otheriwse, the value
  ## specified as default will be returned.
  ##
  ## @param field [String] field name for the project configuration data
  ## @param default [Any] default value if no project configuration data
  ##        has been provided for the named field and no block was
  ##        provided
  ## @param block [Proc] If a block is provided and no project data has
  ##        been configured for the named field, the block will be
  ##        invoked with the field name. The return value from the block
  ##        will then provide the return value for this method.
  ## @see #gem_field_value
  def project_field_value(field, default: false, &fallback)
    ## NB this method is used in the project Rakefile and thus cannot be
    ## usefully defined as a protected method
    load_config if !@proj_data
    if @proj_data.has_key?(field)
      @proj_data[field]
    elsif block_given?
      fallback.yield(field)
    else
      default
    end
  end


  ## return the value of a named named field in either the gem scope or
  ## the project scope, for a named gem in active project data. If
  ## no matching configuration data is found within the gem scope or the
  ## project scope in the project data, invoke any provided fallback
  ## block or return a default value.
  ##
  ## @param gem [String] the name of the gem being configured
  ## @param default [Any] default value if no gem or project
  ##        configuration data has been provided for the named field and
  ##        no block was provided
  ## @param block [Proc] If a block is provided and no gem or project
  ##        data has been configured for the named field, the block will
  ##        be invoked with the field name. The return value from the
  ##        block will then provide the return value for this method.
  ## @see #project_field_value
  def gem_field_value(gem, field, default: false, &fallback)
    load_config if !@proj_data
    load_gem_config(gem)
    if @gem_data.has_key?(field)
      return @gem_data[field]
    else
      project_field_value(field, default) do
        fallback.yield(field)
      end
    end
  end

  ## return the set of gem names configured under the active project
  ## data for this instance
  ##
  ## @return [Array<String>] array of gem names
  def gems()
    data = project_field_value(Const::GEMS_FIELD) do |f|
      ## fallback block, when no gems field is configured on the active
      ## project data. return a new, empty array
      return []
    end
    return data.keys
  end

  ## initialize any gem configuration data for a named gem, or emit a
  ## warning if no data is available for the gem
  ##
  ## In the YAML syntax applied here, the gem configuration data will be
  ## initialized for the named gem under a 'gems' mapping in the
  ## top-level project data.
  ##
  ## @param name [String] name of the gem to initialize for
  ##        configuration from active project data.
  def load_gem_config(name)
    @gem_name = name
    ## If no gem is found for the name in the active project data, a
    ## partial configuration may still be provied for the named gem,
    ## using any gem configuration fields defined at the project scope.
    all_gem_data = project_field_value(Const::GEMS_FIELD) do |field|
      ## fallback block, if no gems map is yet configured to the project
      ##
      ## this ensures that an empty table is initialized for
      ## unconfigured gem-specific data.
      msg_warn("No gem data found for gemspec %p in project data %p field at %p",
               name, field, @pathname)
      return (@gem_data = {})
    end
    ## FIXME store the all_gem_data value itself,
    ## access later via @gem_name as a key on that value
    @gem_data = all_gem_data[name]
    return self
  end

  ## write an active configuration to a provided gemspec
  ##
  ## It's assumed that the calling method will have configured the
  ## gemspec name for the provided gemspec. This gemspec name may then
  ## be used as a data key onto any project gem configuration data,
  ## within this method.
  ##
  ## **Known Limitation: Configuration requirements may vary**
  ##
  ## This method utilizes a YAML syntax for configuring gemspecs from a
  ## central project data source within a project source tree.
  ##
  ## Requirements for gemspec configuration methods may vary by
  ## development site.
  ##
  ## @param spec [Gem::Specification] the gemspec to configure.
  ##
  def write_config(spec)

    ## FIXME add gemspec grouping support, i.e grouping support for deps
    ## configuration in project gemspecs

    ##
    ## decode all YAML from @pathname as Ruby object data,
    ## initializing @proj_data from the decoded data
    ##
    self.load_config

    ##
    ## using a configured gemspec name, initialize configuration data for
    ## the gemspec in gemspec scope
    ##
    if (name = spec.name)
      load_gem_config(name)
    else
      msg_fail("gem specification has no name: %s", spec)
    end

    ##
    ## common data fields (required. gem field overrides project field)
    ##
    for field in @primary_fields
      set_field(field, spec)
    end

    ##
    ## common data fields (optional. gem field overrides project field)
    ##
    for field in @optional_fields
      set_field(field, spec, required: nil)
    end

    if (homepage = spec.homepage)
      ## transfer the gemspec's homepage into metadata, if set under
      ## optional fields
      set_direct_metadata(Const::WWW_FIELD, homepage, spec)
    elsif homepage = (@gem_data[Const::WWW_URI_FIELD] ||
                      @proj_data[Const::WWW_URI_FIELD])
      ## if configured only for homepage_uri in the project YAML,
      ## transfer the URI into the homepage field on the gemspec
      ## and set as metadata
      set_direct_field(Const::WWW_FIELD, spec, homepage)
      set_direct_metadata(Const::WWW_URI_FIELD, homepage, spec)
    end

    ##
    ## metadata fields (optional. gem field overrides project field)
    ##
    ## FIXME support a custom metadata map under both the project and gem scopes
    for md in @metadata_fields
      set_field_metadata(md, spec)
    end

    src_uri = (@gem_data[Const::SRC_URI_FIELD] ||
               @proj_data[Const::SRC_URI_FIELD])
    if src_uri
      set_direct_metadata(Const::SRC_URI_FIELD, src_uri, spec)
    elsif homepage
      set_direct_metadata(Const::SRC_URI_FIELD, homepage, spec)
    end

    changes_uri = (@gem_data[Const::CHANGES_URI_FIELD] ||
                   @proj_data[Const::CHANGES_URI_FIELD])
    if changes_uri
      set_direct_metadata(Const::CHANGES_URI_FIELD, changes_uri, spec)
    elsif src_uri
      set_direct_metadata(Const::CHANGES_URI_FIELD, src_uri, spec)
    elsif homepage
      set_direct_metadata(Const::CHANGES_URI_FIELD, homepage, spec)
    end

    ##
    ## add the project YAML file
    ##
    append_singleton_value(@pathname.basename.to_s, :files, spec)

    ##
    ## add the gemspec file
    ##
    append_singleton(Const::FILENAME_FIELD, :files, spec,
                     default: (name + ".gemspec"))

    ##
    ## source files (union of project, gem fields)
    ##
    append_enumerable(Const::SRC_FIELD, :files, spec)

    ##
    ## docs files (union of project, gem fields)
    ##
    append_enumerable(Const::DOCS_FIELD, :files, spec)

    ##
    ## resource files from YAML (union of project, gem fields)
    ##
    append_enumerable(Const::RESOURCE_FIELD, :files, spec)

    ##
    ## gemspec runtime and development dependencies
    ## (multi-source union of project, gem fields)
    ##
    ## Synopsis - YAML to gemspec map
    ##
    ##  'build_depends', 'depends' => runtime dependencies
    ##
    ##  'devo_depends' => development dependencies
    ##
    ##   Each named YAML field for deps must be encoded
    ##   using a seq (array) syntax in YAML.
    ##
    ##   Each value for each dep may be encoded as a string (name)
    ##   or as an array of strings (name and one or more version bounds)
    ##
    ## Syntax supported as the value for each dep encoded in YAML:
    ##
    ## "<gem>"
    ## - depends on <gem> at any version
    ##
    ## ["<gem>", "<version>", ...]
    ## - depends on <gem> at a version determined from the provided
    ##   version bounds onto available gem sources
    ## - at least one version bound must be specified
    ##
    ## Gem deps listed in YAML under the 'depends' and/or
    ## 'build_depends' fields will be translated to runtime dependencies
    ## in the gemspec
    ##
    ## Gem deps listed under the "devo_depends" field will be translated
    ## to development dependencies in the gemspec.
    ##
    ## Gem deps listd under the 'build_depends' field will also be
    ## stored in the gemspec under the 'build_depends' metadata field,
    ## as well as being interpolated as runtime dependencies for purposes
    ## of Ruby gemspec eval
    ##
    ## If a named dependency is listed more than once, and/or is listed
    ## in both gemspec scope and in project scope in the YAML, the first
    ## declaration will take precedence. Later declarations will be
    ## ignored and a warning message produced
    ##
    ## FIXME this needs something like an openschema documentation

    ## caching for the precedence conditional:
    alldeps = {}
    depname = false
    lastdep = false
    ## gemspec encoding for deps:
    Const::ALLDEPS_FIELDS.map do |field|
      callback_enumerable(field) do |value|
        ## FIXME document this in the YSpec YAML schema docs :
        ## first dep overides any later, in the gemspec encoding for a
        ## gem dependency of a provided name
        ##
        ## In this API, data in the gemspec scope is parsed first
        case value
        when Array
          depname = value[0]
        else
          depname = value
        end
        if alldeps.has_key?(depname)
          first_field = alldeps[depname][0]
          if ! ((first_field == Const::BDEPS_FIELD) && (field == Const::DEPS_FIELD))
            ## do not warn about gemspec dependencies duplicated
            ## when listed as both a build dependency and a runtime
            ## dependency in project.yaml
            ##
            ## for purposes of distribution in host package management
            ## systems, not all build dependencies may be runtime
            ## dependencies.
            ##
            ## for purposes of gemspec initialization from project.yaml:
            ## If a build dependency is configured for a gem,
            ## then it will indicate a runtime dependency for the gem,
            ## there being no singular distinction of "build" or "run"
            ## stages in this context.
            ##
            ## To provide information for host package developement tasks,
            ## each build dependency should be declared separate to each
            ## application runtime dependency in project.yaml
            ##
            ## The conditional form above may simply serve to prevent
            ## that any misleading warning message would be emitted
            ## under any duplication in the interpretation of
            ## application build dependencies and runtime
            ## dependencies both as gemspec runtime dependencies.
            ##
            unparsed = alldeps[depname][1].to_s
            msg_warn("Skipping duplicate %s dependency (%s): %p | \
first declared under %s as %p",
                     name, field, value,
                     first_field, unparsed)
          end
        else
          as_devo = (field == Const::DEVO_FIELD)
          ## FIXME capture any Gem::Requirement::BadRequirementError,
          ## then warn for the origin filename and dep value and raise
          lastdep = write_dep(value, spec, development: as_devo)
          ## lastdep will be the new Gem::Dependency object,
          ## as initialized and returned from write_dep
          alldeps[depname] = [field, lastdep]
        end
      end
    end

    ## post-parse, outside of the previous iterator.
    #
    ## determine the list of build dependencies from project.yaml and
    ## store in gem metadata
    ##
    ## This reuses the project.yaml field name Const::BDEPS_FIELD as a
    ## metadata field name onto the gemspec.
    ##
    ## The array value, if non-empty, will be translated to a string in
    ## YAML syntax before storing in gemspec metadata
    bdeps = []
    alldeps.map do |name, data|
      kind = data[0]
      if (kind == Const::BDEPS_FIELD)
        ## converting each initialized Gem::Dependency under build_depends
        ## to a string, before storing in the gemspec metadata
        gemdep = data[1]
        bdeps << gemdep
      end
    end
    ## FIXME revise the handling for build_depends here
    ## - add build_depends to the runtime dependencies only under some
    ##   conditional configuration in the environment
    ## - retain the behavior of not warning on runtime deps
    ##   duplicationg build deps
    ## - for gappkit and extensionss, define a class extending Gem::Specification
    ##   - extend #activate and extend #to_yaml
    ##   - for #activate under a "Building" environment ... TBD
    ##   - in #to_yaml : ensure that a 'require' call is added for the extending
    ##     Ruby source file (using the definition location of the gemspec's class,
    ##     for the filename relative to the first match in $LOAD_PATH e.g)
    ##     and ensure that the spec's actual class is used in the output source text
    ##
    ## for now ... store YAML in a metadata string (does not use an extension class)
    set_direct_metadata(Const::BDEPS_FIELD, bdeps.to_yaml(header: true), spec) if ! bdeps.length.eql?(0)

    ##
    ## set require_path, require_paths from YAML
    ##
    if gem_rf_path = (@gem_data[Const::REQUIRE_FIELD] ||
                      @proj_data[Const::REQUIRE_FIELD])
      set_direct_field(Const::REQUIRE_FIELD, gem_rf_path, spec)
    end

    append_enumerable(Const::REQUIRE_ENUM_FIELD, :require_paths, spec)

  end

  ##
  ## internal implementation methods
  ##
  protected

  ## raise an error, with a message string calculated from the provided
  ## str applied as a format string with the provided args
  ##
  ## @param str [String] format string
  ## @param args [Array<Any>] format arguments
  def msg_fail(str, *args)
    raise new str % args
  end

  ## produce a warning message, with a message string calculated from
  ## the provided str applied as a format string with the provided args.
  ##
  ## The warning message will be produced with Kernel.warn
  ##
  ## @param str [String] format string
  ## @param args [Array<Any>] format arguments
  ## @param uplevel [Integer] a non-negative integer to provide as the
  ##        uplevel value for Kernel.warn
  def msg_warn(str, *args, uplevel: 1)
    Kernel.warn(str % args, uplevel: uplevel)
  end

  ## add a dependency definition to a provided gemspec from a scalar or
  ## array type dependency declaration decoded from YAML
  ##
  ## This method accepts the following syntax for a dependency value:
  ##
  ## A single gem name, encoded as a string:
  ## > `"<name>"`
  ##
  ## An array of a gem name and one or more gem version bounds, each
  ## encoded as as a string:
  ## > ["<name>", "<version>" ...]
  ##
  ## If the depval is provided as a string, the value of the runtime
  ## constant Const::GEM_REQUIREMENT_DEFAULT will be used as a single
  ## version bound for the requirement.
  ##
  ## @param depval [String, Array<String>] the dependency declaration,
  ##        such as decoded from YAML
  ## @param spec [Gem::Specification] the gemspec receiving the
  ##        dependency definition
  ## @param development [boolean] true if the value indicates a
  ##        development dependency, else the value will be interpreted
  ##        as a runtime dependency
  def write_dep(depval, spec, development: false)
    case depval
    when Array
      name = depval[0]
      bounds = depval[1..]
      req = Gem::Requirement.new(bounds)
      group = development ? :development : :runtime
      dep = Gem::Dependency.new(name, req, group)
      spec.add_dependency(dep)
      return dep
    else
      ## depval is a string - dispatch to call on an array with defaults added
      self.write_dep([depval, Const::GEM_REQUIREMENT_DEFAULT],
                     spec, development: development)
    end
  end

  # def read_dep(dep)
  #   ## translate a gemspec's dependency object
  #   ## to a value for encoding in YAML
  #   ##
  #   ## FIXME this method would be integrated with a broader YAML-gen
  #   ## frameowrk in YSpec
  # end

  ## set a value onto a provided gemspec, using a setter method
  ## computed from #writer_for for the named set_field.
  ##
  ## @param set_field [Symbol] specification field name to use in the
  ##        call to #writer_for
  ## @param value [Any] Value to set with the provided writer method
  ## @param spec [Gem::Specification] gemspec to configure under the
  ##        provided set_field
  def set_direct_field(set_field, value, spec)
    setmtd = writer_for(set_field)
    spec.send(setmtd, value)
  end

  ## set any value for the named field in cached gem or project data,
  ## setting the value as a primary field with the #writer_for method
  ## for that field onto the provided gemspec.
  ##
  ## For the provided field, if that field is non-nil in the configured
  ## gem data, then the field's value in that gem data will be used.
  ## Else, if the field's value is non-nil in the configured project
  ## data, then the field's value will be used as determined in the
  ## project scope.
  ##
  ## If the value is denoted as required and is not found, a warning
  ## will be produced as by `Kernel.warn`. This assumes that the absence
  ## of a required value for this method would represent a continuable
  ## condition.
  ##
  ## @param field [String] field name for configuration dat
  ## @param spec [Gem::Specification] gemspec to configure under the
  ##        provided set_field
  ## @param required [Boolean] If a non-falsey value, then a warning
  ##        will be produced when this field is absent, nil, or false in
  ##        both of the gem and project contexts in the active
  ##        configuration data
  def set_field(field, spec, required: true)
    data = ( @gem_data[field] || @proj_data[field] )
    if data
      set_direct_field(field, data, spec)
    elsif required
      ## an error here might prevent normal bundle initialization.
      ## this will produce a warning instead
      msg_warn("No field data found for %p onto %p in project data at %p",
               field, @gem_name, @pathname)
    end
  end

  ## set the provided value as metadata for the named field, in the
  ## provided gemspec object
  def set_direct_metadata(field, value, spec)
    spec.metadata[field] = value
  end

  ## set any value for the named field in configured gem or project
  ## data, setting the value as metadata with the same field name in the
  ## provided gemspec object
  def set_field_metadata(field, spec)
    data = ( @gem_data[field] || @proj_data[field] )
    set_direct_metadata(field, data, spec) if data
  end

  ## add a single value to an enumerable field of the active gem
  ## specification
  def append_singleton_value(value, specfield, spec)
    readmtd = reader_for(specfield)
    data = spec.send(readmtd)
    data << value
  end

  ## add the value of a singleton field from gem and project data to the
  ## active gem specification.
  ##
  ## The field's value will be derived from the first of:
  ## 1. The field's value under configured gemspec data for the active
  ##    gemspec name.
  ## 2. The field value under top-level project data.
  ## 3. The value indicated as default.
  ##
  ## If no value can be determimed with gemspec data, project data, or
  ## the default value, then no value will be set for the field.
  ##
  ## @param field [String] field name for gem or project data
  ## @param specfield [String, Symbol] name of an enumerable gem
  ##        specification field
  ## @param spec [Gem::Specification] a Gem specification object
  ## @param default [Any] Default value for the field, if no value is
  ##        configured in gem or project data and if a non-falsey
  ##        default value is provided
  def append_singleton(field, specfield, spec, default: false)
    if @gem_data.has_key?(field)
      value = @gem_data[field]
    elsif @proj_data.has_key?(field)
      value = @proj_data[field]
    else
      value = default
    end
    append_singleton_value(value, specfield, spec) if value
  end

  ## append each element for an enumerable field value (if non-nil) in
  ## configured gem and project data, using the provided specfield for
  ## determining the name of a reader method nam.e onto an enumerable
  ## value in the provided gemspec
  ##
  ## The reader method's name for the gemspec will be calculated with
  ## the method #reader_for in this class, called on the provided
  ## specfield.
  ##
  ## If the named field is non-nil in either or both of configured
  ## project data and gem data, then the value as configured must
  ## represent an enumerable object. For each value in each such
  ## enumerable object, the value will be transferred verbatim to
  ## the provided gem specification, appending to an enumerable value
  ## denoted by the provided specfield.
  ##
  ## e.g usage
  ##
  ## > `append_enumerable(Const::SRC_FIELD, :files, spec)`
  ##
  ## @param field [String] field name for gem or project data
  ## @param specfield [String, Symbol] name of an enumerable gem
  ##        specification field
  ## @param spec [Gem::Specification] a Gem specification object
  ## @see #call_enumerable
  def append_enumerable(field, specfield, spec)
    readmtd = reader_for(specfield)
    data = spec.send(readmtd)
    if (configured = @proj_data[field])
      configured.each do |value|
        data << value
      end
    end
    if (configured = @gem_data[field])
      configured.each do |value|
        data << value
      end
    end
  end

  ## append any data from an enumerable field value as configured in gem
  ## and project data, using a single callout method onto an enumerable
  ## value in the provided gemspec.
  ##
  ## This method will be applied for each element for the named field in
  ## configured gem and project data. If non-nil, the value for the
  ## named field must be provided as an enumerable value in either or
  ## both of the gem and project scopes in the configuration data.
  ##
  ## e.g usage
  ##
  ## > `call_enumerable(Const::DEPS_FIELD, :add_runtime_dependency, spec)`
  ## >
  ## > `call_enumerable(Const::DEVO_FIELD, :add_development_dependency, spec)`
  ##
  ## **Known Limitations**
  ##
  ## This method may be suitable for storing literal values from some
  ## enumerable field to the provided gemspec.
  ##
  ## For any method call on the gemspec that must receive more than one
  ## parameter from each element in the enumerable field, TBD (FIXME)
  ##
  ## Alternately, for any value from the configured project data that
  ## must be applied to the gemspec via some non-field callback method,
  ## e.g `Gem::Specification#add_runtime_dependency` TBD (FIXME)
  ##
  ## **Deprecation**
  ##
  ## This method is now unused in YSpec. Refer to #callback_enumerable
  ##
  ## @param field [String] field name for gem and project data
  ## @param speccall [String, Symbol] name of the callout method for the
  ##        provided gem specification. The named method should return
  ##        an enumerable value in that gemspec. A symbol speccall is
  ##        preferred.
  ## @param spec [Gem::Specification] a Gem specification object
  ## @see #append_enumerable
  def call_enumerable(field, speccall, spec, &transform)
    callmtd  = speccall.to_sym
    if (configured = @proj_data[field])
      configured.each do |value|
        spec.send(callmtd, value)
      end
    end
    if (configured = @gem_data[field])
      configured.each do |value|
        spec.send(callmtd, value)
      end
    end
  end

  def callback_enumerable(field, &callback)
    raise "No callback provided for field #{field.inspect}" unless callback
    if (configured = @proj_data[field])
      configured.each do |value|
        callback.call(value)
      end
    end
    if (configured = @gem_data[field])
      configured.each do |value|
        callback.call(value)
      end
    end
  end

end
