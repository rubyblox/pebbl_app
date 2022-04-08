## rbproject.rb

class Encoding
end

class YamlEncoding < Encoding
end

class GemspecEncoding < Encoding
end

class SerializationDesc
  attr_reader :object_class
  attr_reader :fields
  ## attr_reader: dest_encoding

  def initialize(object_class)
    @object_class = object_class
    @fields = {}
  end

  def add_field(name, mapping)
    ## NB => FieldDesc
  end
  def remove_field(name)
  end
end


## @abstract
class FieldDesc
  ## NB if using psych for YAML parsing,
  ## can access a Psych::Parser or
  ## Psych::Emitter directly - really a lot
  ## to go through, for a trivial (??)
  ## project data serialization thing
  attr_reader :value_get_method
  attr_reader :value_set_method

  def initialize(name)
    @name = name
    @serialization_desc = serialization_desc
  end
end

## TBD APIs for marshalling/unmarshalling
## onto any non-binary syntax, w/o any too
## hip fluff to it

class ValueFieldDesc < FieldDesc
end

class CollectionFieldDesc < FieldDesc
# i.e FieldDesc for add/get/remove accessors

end


class MarshalBroker
  ## NB for generalized objet [un]marshaling
  ## not exclusively under Ruby's Marshal module

  attr_reader :object_class
  attr_reader :marshal_fields

  def initialize(object_class)
    @object_class = object_class
  end

  def load_field(desc, obj, source)
    raise NotImpementedError("not implemented: #{self.class}.load_field")
  end

  def load_object(source)
    ## NB this assumes a 'source' representing an
    ## intermediate value, such as from YAML.load,
    ## rather than a stream. FIXME This diverges
    ## from the semnatics of write_object, which
    ## accesses a stream directly
    ##
    ## NB this may not be immediately applicable
    ## for Ruby Marsh.{load|dump} depending on
    ## whether the syntax allows for iteration
    ## onto specific object fiels, and how
    ## that would be integrated into object
    ## serialization (by class)
    inst = @object_class::allocate
    marshal_fields.each do |f|
      v = load_field(f, inst, source)
      ## e.g set_<thing> or add_<thing>s
      m_store = f.value_set_method(inst)
      inst.call(m_store, v)
    end
    return inst
  end

  ## NB this requires that the following
  ## will be implemented for a class, and stored in a FieldDesc f
  ## f.value_load_method
  ## f.value_set_method
  ## f.value_get_method
  ## f.value_write_method
  ##
  ## ideally, the _set* and _get* methods could be
  ## implemented as inst. accessors on the ObjectClass
  ##
  ## the load_method and write_method should each be
  ## implemented external to the class, as under
  ## each {Marshal broker} x {Field desc}

  def write_field (desc, obj, dest)
    raise NotImpementedError("not implemented: #{self.class}.write_field")
  end


  def write_object(obj, dest)
    marshal_fields.each do |f|
      ## e.g get_<thing><s>
      write_field(f, obj, dest)
      ## or ..
      # m_val = f.value_get_method(obj)
      # v = obj.call(m_val)
      # write_field(f, v, obj, dest)
  end

end

class YAMLMarshalBroker < MarshalBroker
  ## FIXME obsolete prototype

  ## NB selective encoding/decoding for YAML serialization
  ## of a single Ruby class - selective in that this does
  ## not assume that every field of an instance of the
  ## class will be serialized

  ## @param source [object] object initialized from YAML...
  def load_field(desc, obj, source)
  end

  ## @param dest [stream] TBD
  def write_field (desc, obj, dest)
    ## NB the set of fields in an object would
    ## typically be written as a YAML "dictionary"
    ## - TBD arbitrary nesting depth on DEST

    ## FIXME here is where there must be some dispatching
    ## on 'desc', as to whether the field is to be encoded
    ## as a collection field or a normal value field
    dest.print(desc.field_name + ": ")
    if desc.instance_of? CollectionFieldDesc
      dest.puts ## newline
    end
    val = desc.value_get_method
    ## FIXME cannot call only YAML.dump here,
    ## it adds a new "---" document leader in
    ## each call. Same as <obj>.to_yaml.
    ##
    ## TBD is there way to initialize a YAML + options
    ## object?
    ## - TBD use Psych ...
    ## - Test ruby struct encoding
    ##   - nothing too expansive for project file interchange ...
    YAML.dump(val, dest)
  end

  def write_object(object, dest)
    c = object.class
    dest.puts "--- !ruby/object:#{c.name}"
    super(object, dest)
end
end


class RBYMarshalBroker < YAMLMarshalBroker
end


class GemfileMarshalBroker < MarshalBroker
end

class JSONMarshalBroker < MarshalBroker
end



class RbProject


  ## project yaml fields to not add to 'extra data'.
  ##
  ## if 'true', use a method on the project class
  ## having the same name as the denoted field
  ##
  ## if a symbol, use a method by the name
  ## provided in that symbol
  ##
  ## @see ACCESSOR_DEFAULT
  ## FIXME reimplement with ACCESSOR_MAP_DEFAULT and an accessor
  ACCESSOR_MAP = { "name" => true,
                   "version" => true
                   "lib_files" => true
                   "license" => true
                 }

  ## default accessor for yaml => project mapping
  ## @see ACCESSOR_MAP
  ##
  ## FIXME trvial add/get accessors
  ##  DNW onto the add/remove syntax
  ACCESSOR_DEFAULT = :extra_field


  ## @see ::from_file
  PROJECT_FILE_SUFFIX = ".yprj"


  def self.pop_field(whence, name, default = false)
    ## utility for self.from_yaml
    if ( whence.exists?(name) )
      value = whence[name]
      whence.delete[name]
      return value
    elsif default
      return default
    else
      raise "No field #{name} found in #{whence}"
    end
  end

  def self.from_yaml(text)
    text_dup = text.dup
    ## NB At least a project name is required
    ## for the initializer
    name = self.pop_field(text_dup, "name")
    proj = self.new(name)
    text_dup.each do |k,v|
      ## map subsequent text fields into instance fields
      method = proj.get_method_from_yaml_field(k)
      proj.send(method,v)
    end
  end


  def self.find_project_file(name, project_root: Dir.pwd
                            suffix: PROJECT_FILE_SUFFIX)
    exp = File.expand_path(name,project_root)
    proj_f = exp + suffix
    File.exists(proj_f) && ( return proj_f )
    proj_f = exp
    File.exists(proj_f) && ( return proj_f ) ||
      raise "No project file found: #{name} \
in #{project_root} for suffix #{suffix}"
  end

  def self.from_file(name, project_root: Dir.pwd
                    suffix: PROJECT_FILE_SUFFIX)
    # proj = RbProject.new(name)
    ## ... load the project file
    porj_f = self.find_project_file(name,
                                    project_root: project_root,
                                    suffix: suffiX)
    proj_data = YAML.safe_load_file(proj_f)
    return self.from_yaml(proj_data)
  end


  attr_accessor :name ## string  attr_accessor :version ## string
  attr_accessor :summary ## string
  attr_accessor :description ## string
  attr_accessor :authors ## [string]
  attr_accessor :license ## TBD - string or [??]
  attr_accessor :lib_files ## []
  attr_accessor :doc_files ## []
  attr_accessor :test_files ## []
  ## ^ FIXME implement add/remove accessors for each []


  def initialize(name, fields*)
    @name = name
  end

  ## @see ACCESSOR_DEFAULT
  def extra_field=(name,value)
    if @extra_data
      @extra_data[name] = value
    else
      @extra_data = { name => value }
    end
  end

  def extra_field_remove(name)
    if @extra_data
      @extra_data.remove(name)
    end
  end

  def extra_data()
    @extra_data
  end


  ## @return [Symbol] a method name onto this *Project*
  ## @see #get_method_to_yaml_field
  ## @see ::from_)yaml
  def get_method_from_yaml_field(name)

    ## FIXME trvial set/get accessors
    ##  DNW onto the add/remove syntax

    if ACCESSOR_MAP.includes?(name)
      use_field = ACCESSOR_MAP[name]
      method_naem = false
      if (use_field == true)
        method_name = name.to_sym
      else
        method_name = use_field
      end
      return method_name
    else
      return ACCESSOR_DEFAULT
    end
  end

  ## @return [String] YAML field name
  ## @see #get_method_from_yaml_field
  def get_method_to_yaml_field(name)
    ## TBD how "name": is arrived at
    ##
    ## FIXME define ::to_yaml && usage
    ## NB v = proj.send(...)
    if ACCESSOR_MAP.value?(name)
      return ACCESSOR_MAP.key(name)
    else
      return name.to_s
    end
  end


  def gemspec_new()
    ## TBD project yaml syntax for any one to many mapping
    ## of project => gemfile+
    s = Gem::Specification.new(self.name, self.version)

    ## process any project => gemfile field mappings
    ## (FIXME)

    ## lastly:
    return s
  end

  def ruby_source_files()
    ## trivial, inextensible project => source file mapping
    return self.some_libdir + self.some_name + ".rb"
  end

  def gem_version()
    ## TBD: derive version from newest Git tag for the project file
    ## and all source files?
    return @version
  end

  def gem_package_tasks(gemspec)
    return Rake::GemPackageTask.new(gemspec)
  end
end

# Local Variables:
# fill-column: 65
# End:
