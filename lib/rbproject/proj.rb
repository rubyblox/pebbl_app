## proj.rb

=begin Project docs

In this source file, at this revision:

- FieldDesc, with implementation classes
  ScalarFieldDesc, SequenceFieldDesc,
  MappingFieldDesc
  - FIXME move into module Config - see configfile.rb

- YAMLScalarExt and YAMLIncludeFile classes
  - FIXME move into module Config::YAML - see configfile.rb

- YAMLExt (mixin module for +extend+)
  - defining an init_yaml_tag class method
    in any class extending the module, e.g
    for usage in setting a YAML_TAG constant
    in any class requiring specialized
    processing under the Psych API onto YAML.
    This class method will set *Psych.load_tags*
    and *Psych.dump_tags+ per the class identity
    and the tag value for the method
  - FIXME move into module Config::YAML - see configfile.rb

- CollectionAttrs (mixin module for +extend+)
  - defining attr_seq and attr_map class methods
    in any class extending the module

- Proj (applicaiton data class)

FIXME All definitions excepting 'Proj' should be moved into
indindividual { gem, file } locations

FIXME an additional mixin module could be defined in an
extension onto the CollectionAttrs module, such that the
new extension would also operate to provide for field
desc init, pursuant to any procedures for limting field
serialization onto YAML && generic YAML 'mapping' encoding
for application data interchange. This may be developed
after the *FieldDesc* API design would be in any first
major revision.

=end

=begin Some notes onto psych

* For AST=>Ruby transformation, note usage of
  an optional :init_with method onto a TBD (o : Node ??),
  such as from Psych::Visitors::ToRuby#visit_Psych_Nodes_Mapping
  calling Psych::Visitors::ToRuby#init_with for the dispatch handling
  #under a "struct tag", or #revive calling #init_with generally under
  an "object tag" not mapping to "Complex", "Rational", or "Hash"
  src @ psych:lib/psych/visitors/to_ruby.rb

  The <object>#init_with method would be provided with an object of type
  Psych::Coder. That object would be initialized with any tag for the
  node to which the <object> is mapped during deserialization. The
  'map' field of the Coder would contain e.g instance value members


=end

require('psych')

module FieldMap
  ## assumption: Any class including this class would be a direct
  ## or indirect subclass of FieldDesc
  attr_reader :external_class
  attr_reader :external_name

  def initialize(in_class, name, external_class, external_name)
    super(in_class, name)
    @external_class = external_class
    @xternal_name = external_name
  end

  def send_value(external_instance, **values)
    external_instance.call(external_name, **values)
  end
end


## _ad hoc_ field description for Ruby classes
##
## Used in *Proj* under serialization to YAML
class FieldDesc

  ## the name of the class for which this *FieldDesc*
  ## was created
  ##
  ## @return [Class] the class
  attr_reader :in_class

  ## the generalized field name for this *FieldDesc*
  ##
  ## @return [Symbol] the generalized field name
  attr_reader :name

  ## the name of the instance variable for this
  ## *FieldDesc*
  ##
  ## @return [Symbol] the instance variable name
  attr_reader :instance_var

  ## a symbol describing the type of the FieldDesc,
  ## for purpose of control flow dispatching, or
  ## +nil+ if no type has declared
  attr_reader :type


  ## create a +FieldDesc+ for the generalized field +name+ in the
  ## class +in_class+.
  ##
  ## As well as binding the values for the *#in_class* and *#name*
  ## reader methods, this constructor will also initialize a
  ## value for the *#instance_var* reader method/
  ##
  ## @param in_class [Class] the class containing the named field
  ## @name [String or Symbol] the generalized name of the field.
  ##  This name, when prefixed with +'@'+ will be used as an
  ##  instance variable name for acessing the generalized field
  ##  under instances of the denoted class
  ##
  ## @see #value_in?
  ## @see #get_value
  ## @see #set_value
  def initialize(in_class, name)
    @in_class = in_class
    @name = name.to_sym
    @instance_var = ( '@' + name.to_s ).to_sym
  end


  ## return true, if the *#instance_var* is defined as an
  ## intstance variable in +instance+
  ##
  ## @see #instance_var
  def value_in?(instance)
    instance.instance_variable_defined?(@instance_var)
  end


  ## if the *#instance_var* is initialized to a value
  ## in +instance+, return that value, else return +default+
  ##
  ## @see #instance_var
  def get_value(instance, default=false)
    if value_in?(instance)
      instance.instance_variable_get(@instance_var)
    else
      return default
    end
  end

  ## set the *#instance_var* to the provided +value+
  ## in a specified +instance+
  ##
  ## @see #instance_var
  def set_value(instance, value)
    instance.instance_variable_set(@instance_var,value)
  end
  alias :init_field :set_value
end


class ScalarFieldDesc < FieldDesc

  def initialize(in_class, name)
    super
    @type = :scalar
  end
end

class ScalarFieldMap < ScalarFieldDesc
  extend FieldMap

  def export(internal_instance, external_instance)
    if value_in?(internal_instance)
      if block_given?
        yield lambda {|val| send_value(external_instance,val)}
      else
          value = get_value(internal_instance)
          send_value(external_instance, value)
      end
    end
  end
end

## superclass for *FieldDesc* types representative of
## enumerable field values
##
## @see SequenceFieldDesc
## @see MappingFieldDesc
class EnumerableFieldDesc < FieldDesc
end

## class for *FieldDesc* types representative of
## generally Array-like field values
class SequenceFieldDesc < EnumerableFieldDesc

  def initialize(in_class, name)
    super(in_class, name)
    @type = :sequence
  end

  ## store a value uniquely in the field of the instance
  def add_value(instance, value)
    if value_in?(instance)
      seq = get_value(instance)
      found = seq.find { |elt| elt == value }
      if found
        return seq
      else
        seq.push(value)
      end
    else
      set_value(instance,[value])
    end
  end
  alias :init_field :add_value

  # def remove_value(instance, value)
  # end
end


class SequenceFieldMap < SequenceFieldDesc
  extend FieldMap

  def export(internal_instance, external_instance)
    if value_in?(internal_instance)
      if block_given?
        yield lambda { |elt| send_value(external_instance, elt) }
      else
        get_value(internal_instance).each do |elt|
          send_value(external_instance, elt)
        end
      end
    end
  end
end


## class for *FieldDesc* types representative of
## generally Hash-like field values
##
## @see Proj#load_yaml_field
## @see Proj#load_yaml_stream
class MappingFieldDesc < EnumerableFieldDesc
  def initialize(in_class, name)
    super
    @type = :mapping
  end

  ## store each pair of key, value bindings from
  ## a provided hash +map+
  ##
  ## @param instance [any] an object of the type
  ##  denoted in the *#in_class* field of this
  ##  *FieldDesc*
  ##
  ## @param map [Hash] a set of key, value bindings
  ##  to store in the corresponding field of the
  ##  instance
  ##
  ## @see #store_value
  def store_values(instance, map)
    map.each do |k,v|
      store_value(instance, k, v)
    end
  end
  alias :init_field :store_values

  ## store a single key, value binding
  ##
  ## @param instance [any] an object of the type
  ##  denoted in the *#in_class* field of this
  ##  *FieldDesc*
  ##
  ## @param key [any]
  ##
  ## @param value [any]
  ##
  ## @see #store_values
  def store_value(instance, key, value)
    if value_in?(instance)
      h = instance.instance_variable_get(@instance_var)
      h[key]=value
    else
      set_value(instance,{key => value})
    end
  end

  # def remove_key(instance, key)
  # end
end

class MappingFieldMap < MappingFieldDesc
  extend FieldMap

  def export(internal_instance, external_instance)
    ## FIXME ...

    if value_in?(internal_instance)
      if block_given?
        ## assumption: The calling method will access and
        ## transform the internal field data for the instance
        ##
        ## The lambda yielded to the block in the calling method
        ## should be called with each key, value pair to send
        ## to the external instance
        ##
        ## NB usage case - implementation for the metadata field
        ## mapping from an RbProject onto gemspec metdatada
        yield lambda { |k,v| send_value(external_instance, k, v) }
      else
        ## NB usage case for external mapping to
        ## Gem::Specification instance methods
        ## #add_development_dependency and
        ## #add_runtime_dependency from each
        ## of RbProject fields :development_depends
        ## and :runtime_depends
        value = get_value(internal_instance)
        value.each { |k,v| send_value(external_instance, k, v) }
      end
    end
  end
end



# class ObjectFieldDesc < MappingFieldDesc
# ## NB
# ## - dispatch to Psych YAML handling (tags && init_with/encode_with methods)
# ## - tag semantics onto Psych.load_tags && Psych.dump_tags
# end

## mixn module for usage under +extend+
module YAMLExt

  def self.extended(extclass)

    ## Create a tag value representative of the class, and store
    ## for interoperability under *Psych.dump* and *Psych.load*
    ## methods.
    ##
    ## @param tag [String or nil] The tag. If not provided, a tag
    ##  value will be constructed from the class name. If the
    ##  class defines a +VERSION+ field, the class name will be
    ##  concatenated with a suffix evaluated of
    ##  +@#{VERSION}+. Otherwise, the class name will be used
    ##  without version qualification.
    ##
    ## @return [String] the tag value, subsequent of storage for
    ##  class designators of the +class_inst+ under
    ##  +Psych.load_tags+ and +Psych.dump_tags+
    ##
    ## @see #init_with
    ## @see #encode_with
    ## @see Psych::Visitors::ToRuby#deserialize
    ## @see Psych::Visitors::YAMLTree#accept
    ##
    def extclass.init_yaml_tag(tag=nil)
      if tag
        use_tag = tag.to_s
      else
        class_name = self.name
        if self.const_defined?("VERSION")
          use_tag = "#{class_name}@#{self::VERSION}"
        else
          use_tag = class_name
        end
      end
      ## FIXME at DEBUG log level, log the tag being used and the
      ## extclass
      Psych.load_tags[use_tag] = class_name
      Psych.dump_tags[self] = use_tag
      return use_tag
    end
  end
end

##
## Generic extension for special-usage scalar encoding in YAML
##
class YAMLScalarExt

  extend YAMLExt
  YAML_TAG = init_yaml_tag("ext")

  ## If the +coder+ has a type +scalar+, return the
  ## scalar value stored to the *Coder*, else raise
  ## an exception
  ##
  ## @param coder [Psych::Coder] a *Coder* instance
  ##
  ## @return [String] the scalar value stored
  ##  to the coder instance
  def self.coder_value(coder)
    if (coder.type == :scalar)
      return coder.scalar
    else
      ## FIXME use a more exacting exception type here
      raise "Unsupported coder type :#{coder.type} in #{coder}"
    end
  end

  ## the scalar value to be rendered to YAML for this
  ## +YAMLScalarExt+
  attr_reader :value

  def initialize(value)
    @value = value
  end

  ## Initialize this instance, per data fields provided
  ## in a +Coder+
  ##
  ## This method provides for interoperability with the Psych
  ## API, as under *Psych.load*
  ##
  ## @param coder [Psych::Coder] a *Coder* instance providing
  ##  a scalar value, generally as would be decoded from
  ##  a YAML stream
  ## @see #encode_with
  ## @see Psych.load
  def init_with(coder)
    @value = YAMLScalarExt.coder_value(coder)
  end

  ## Configure a *Coder* for scalar encoding, using the +@value+
  ## stored in this instance. If no +@value+ is stored, raises
  ## an exception
  ##
  ## This method provides for interoperability with the Psych
  ## API, as under *Psych.dump*
  ##
  ## @see #init_with
  ## @see Psych.dump
  def encode_with(coder)
    if @value
      coder.scalar=@value
    else
      raise "no value configured in #{self} when configuring coder #{coder}"
    end
  end
end


## YAML Extension for providing a filename
## to a corresponding 'include' directive
## under a key/value pair of a YAML mapping
##
## @see YAMLScalarExt
## @see Proj
##
## @fixme the placement of the key/value pair +!<ext> include:
##  !<file> ...+ in the YAML output stream:
##  - needs an OrderedHash data type ... for output, at least,
##    such as in *Proj#encode_with*
##  - under interpretation as per (FIXME Needs documentation),
##    may affect the values or previous and subsequent _mapping
##    fields_ for an object serialized onto YAML
##  - FIXME may be addressed with regards to the effective
##    mashup of _configuration API_ and _application data API_
##    forms in the *Proj* class
class YAMLIncludeFile < YAMLScalarExt

  ## the YAML tag to use when processing instance of this class
  ## with the Psych API
  extend YAMLExt
  YAML_TAG = init_yaml_tag("file")

  alias :filename :value

  ## Return an absolute pathname constructed of the filename
  ## stored under the instance +@value+
  ##
  ## If the pathname is a relative pathname, it will resolved as
  ## relative to either +basedir+ or -- if +basedir+ is nil --
  ## then the current working directory of the calling Ruby
  ## environment.
  def host_filename(basedir = nil)
    @value && File.expand_path(@value,basedir)
  end
end

=begin

# Illustration - using YAMLScalarExt and YAMLIncludeFile
# to encode an 'include' section within a YAML mapping

Psych.dump({ YAMLScalarExt.new("include") =>
            YAMLIncludeFile.new("a/b/c/common.yprj")})
=> "---\n!<ext> include: !<file> a/b/c/common.yprj\n"


Psych.load("---
!<ext> include: !<file> a/b/c/common.yprj
")
=> {#<YAMLScalarExt:0x000056409705e7a8 @value="include"> =>
    #<YAMLIncludeFile:0x000056409705e528
      @value="a/b/c/common.yprj">}

=end


## mixin module providing class methods *attr_seq* and *attr_map*
##
## example:
##   def AppData
##     extend CollectionAttrs
##     attr_seq :xrefs
##     attr_map :config
##   end
##
## In this example, the `@xrefs` instance variable
## will be assumed to have an Array type, when bound.
##
## The @config instance variable will be assumed to
## have a Hash type, when bound.
##
## Methods defined in this example, onto the @xrefs
## instance variable:
## - +:add_xref+ to add a unique element to @xrefs
## - +:remove_xref+ to remove an element from @xrefs
## - +:xrefs+ to access the value of @xrefs, if bound,
##   otherwise returning false
## - +:xrefs=+ to set the value of @xrefs, as an Array
##   or nil
##
##
## Methods defined in this example, onto the @config
## instance variable:
## - +:set_config (key,value)+ to add a key, value pair for a
##    unique key onto the @config hash
## - +:remove_config (key)+ to remove a key and value pair
##    from the @config hash
## - +:config ()+ to retrieve the @config hash, if bound,
##   otherwise initializing @config with an empty Hash
##   and returning the Hash newly stored in the instance
##   variable
## - +:config_map= (map)+ to set the value of @config,
##   as a Hash or nil
##
## @fixme needs a more thorough example
module CollectionAttrs

  def self.extended(extclass)
    # define methods for adding and removing elements to the
    # value of an instance field, as well as conventional
    # attribute accessor methods for retrieving the
    # value of the field or setting the value of the field as a
    # sequence
    #
    # for a +field+ name +:attrs+ this will define the methods
    # - +:add_attr+ to add a unique element to @attrs
    # - +:remove_attr+ to remove an element from @attrs
    # - +:attrs+ to access the value of @attrs, if bound,
    #   otherwise returning false
    # - +:attrs=+ to set the value of @attrs, as an Array
    #   or nil
    #
    # @param field [Symbol] field name, such that will be assumed
    #  to represent an instance variable name e.g +@field+
    #
    # @param trim_plural [any] If true, any "s" suffix will be
    #  trimmed from the field name, when constructing the name
    #  for each of the +add_thing+ and +remove_thing+ methods. If
    #  false, the field name will be used verbatim, when
    #  constructing the name of each of these methods.
    #
    # @see #attr_map Define accessor methods for a Hash-like
    # field
    #
    def extclass.attr_seq(field, trim_plural: true,
                          add_name: nil, rem_name: nil,
                          get_name: nil, set_name: nil)
      use_name = field.to_s
      inst_var = ('@' + use_name).to_sym
      ## NB The verb_sfx would generally be the use_name trimmed
      ## of any simple plural suffix "s", e.g such as to define
      ## methods :add_obj, :remove_obj for an instance variable
      ## named :@objs
      ##
      ## NB Insofar as determining the plural suffix, this is not a
      ## complex lexical scanner
      ##
      ## FIXME this does not provide any RDoc/YARD documentation
      verb_sfx = ( trim_plural && use_name[-1] == "s" ) ?
        use_name[...-1] : use_name
      add_name ||= ('add_' + verb_sfx).to_sym
      rem_name ||= ('remove_' + verb_sfx).to_sym
      get_name ||= use_name.to_sym
      set_name ||= (use_name + '=').to_sym

      ## FIXME at DEBUG log level, log each method name,
      ## the instance variable name, and extclass

      define_method(add_name) { |value|
        if instance_variable_defined?(inst_var) &&
            ( stored = instance_variable_get(inst_var) )
          stored.find { |elt| elt == value } ||
            stored.push(value)
        else
          instance_variable_set(inst_var, [value])
        end }

      define_method(rem_name) { |value|
        if instance_variable_defined?(inst_var) &&
            ( stored = instance_variable_get(inst_var) )
          stored.delete(value)
        end }

      define_method(get_name) {
        instance_variable_defined?(inst_var) &&
          instance_variable_get(inst_var) }

      define_method(set_name) {|value|
        instance_variable_set(inst_var, value) }

    end ## def attr_seq


    # define methods for adding and removing elements to the
    # value of an instance field, as well as conventional
    # attribute accessor methods for retrieving the
    # value of the field or setting the value of the field as a
    # *Hash*
    #
    # for a +field+ name +:map+ this will define the methods
    # - +:set_map (key,value)+ to add a key, value pair for a
    #    unique key onto the @map hash
    # - +:remove_map (key)+ to remove a key and value pair
    #    from the @map hash
    # - +:map ()+ to retrieve the @map hash, if bound,
    #   otherwise initializing @map with an empty Hash
    #   and returning the Hash newly stored in the instance
    #   variable
    # - +:map_map= (map)+ to set the value of @map,
    #   as a Hash or nil
    #
    # @param field [Symbol] field name
    #
    # @see extclass.attr_seq Define accessor methods for asn
    #  Array-like field
    def extclass.attr_map(field, add_name: nil, rem_name: nil,
                          get_name: nil, set_name: nil)
      use_name = field.to_s
      inst_var = ('@' + use_name).to_sym
      add_name ||= ('set_' + use_name).to_sym
      rem_name ||= ('remove_' + use_name).to_sym
      get_name ||= use_name.to_sym
      set_name ||= (use_name + '_map=').to_sym

      ## FIXME at DEBUG log level, log each method name,
      ## the instance variable name, and extclass

      ## NB this o.set_thing(key,value) semantics
      ## may be less than ideal for a hash field
      ##
      ## the hash field can be accessed directly
      ## e.g  o.thing[key] = value
      define_method(add_name) { |key, value|
        if instance_variable_defined?(inst_var)
          h = instance_variable_get(inst_var)
          h[key] = value
        else
          instance_variable_set(inst_var, { key => value })
        end }

      define_method(rem_name) { |key|
        if instance_variable_defined?(inst_var) &&
            ( stored = instance_variable_get(inst_var) )
          stored.delete(key)
        end }

      define_method(get_name) {
        ## NB ensure that the call e.g
        ##  Proj.metadata[:a]=:b should always
        ##  have a hash table available
        if instance_variable_defined?(inst_var)
          instance_variable_get(inst_var)
        else
          h = {}
          instance_variable_set(inst_var, h)
          return h
        end
        }

      define_method(set_name) {|value|
        instance_variable_set(inst_var, value) }

    end ## def attr_seq

  end ## def self.extended(extclass)

end ## module CollectionAttrs


##
## Project class
##
## @fixme This class provides an effective mashup of
##  _configuration API_ and _application data API_ forms,
##  such that may serve to limit the portability of either
##  set of API forms.
class Proj

  ## FIXME the following should be expanded into some normal
  ## documentation
  ##
  ## NB using #encode_with and #init_with methods in this
  ## class. These methods are used for YAML writing and YAML
  ## eval, respectively, within the Psych API.
  ##
  ## NB An instance of this class can be loaded from either a tagged
  ## or an untagged mapping in a YAML stream. If a tagged mapping,
  ## the mapping should have a tag equivalent to Proj::YAML_TAG.
  ##
  ## NB For any key token provided in the YAML mapping during and
  ## subsequent of YAML loading, if that key is not recognized as
  ## denoting a field name in this class, then the key and its
  ## value will be stored under @extra_conf_data in the instance

  VERSION="0.4.4"

  extend YAMLExt
  YAML_TAG = init_yaml_tag()
  ##
  ## NB new feature - not addressed in the following:
  ## Proj@encode_with_tag should generally be nil, for purpose
  ## of creating a generalized untagged YAML mapping on output.
  ##
  ## If an output stream must be created, such that a new Proj
  ## object would be initialized when the stream is read, then
  ## Proj@encode_with_tag == Proj::YAML_TAG should be used
  ##
  ## Although Proj@encode_with_tag can be set to any arbitrary
  ## string value, when not nil, it would be beyond the support
  ## of this API - at present- to decode an encoded Proj with
  ## any tag other than Proj::YAML_TAG (FIXME this will need to
  ## be addressed in a subsequent Proj revision)
  ##
  ## NB Psych.load_tags is used in initialization of the instance
  ## variable @load_tags for Psych::Visitors::ToRuby as in
  ## psych:lib/psych/visitors/to_ruby.rb. The instance variable
  ## @load_tags is then used e.g under numerous resolve_class
  ## calls, such as in #deserialize, #visit_Psych_Nodes_Sequence,
  ## and #visit_Psych_Nodes_Mapping instance methods onto the
  ## ToRuby visitor class.
  ##
  ## The definition of a value onto Psych.load_tags may affect
  ## each of those methods' behaviors. Generally, a binding onto
  ## Psych.load_tags should be accompanied with a definition of
  ## an instance method :init_with under the class denoted
  ## in the mapping e.g
  ##     Psych.load_tags[<tag>] = <class>
  ## ... such as for any <tag> representing a class to be
  ## specially initialized in the transformation from YAML to
  ## Ruby w/ the Psych API.
  ##
  ## Conversely, Psych.dump_tags is used in #visit_Object,
  ## #visit_BasicObject, and #dump_coder instance methods onto
  ## Psych::Visitors::YAMLTree as in
  ## psych:lib/psych/visitors/yaml_tree.rb


  def self.load_yaml_file(filename, **loadopts)
    ## FIXME may not be immediately useful
    ## for deserialization of any subclass instance
    ##
    ## FIXME provide an extended loadopt for file encoding
    instance = self.allocate
    instance.load_yaml_file(filename, **loadopts)
    return instance
  end

  attr_accessor :encode_with_tag ## FIXME move to a ConfigFile subclass

  attr_accessor :name
  attr_accessor :version
  attr_accessor :homepage
  attr_accessor :summary
  attr_accessor :description
  attr_accessor :license ## FIXME may be a seq. should use spdx syntax when not n/a
  attr_accessor :authors
  attr_accessor :fields_from_conf ## for debug & deserialization - array a.t.m

  ## attr_accessor :conf_file ## ...

  extend CollectionAttrs
  ## FIXME provide RDoc/YARD docs for all of the
  ## methods defined in the following
  ##
  ## FIXME lib_files, test_files, require_paths
  ## are generally Ruby project-specific
  attr_seq :require_paths
  attr_seq :lib_files
  attr_seq :test_files
  attr_seq :doc_files
  ## attr_seq :dependencies

  ## FIXME "metadata keys must be a string" ...
  attr_map :metadata ## for gemspec interop
  attr_map :extra_conf_data ## fallback capture for deserialization

  ## FIXME This class needs additional fields, for broader gemspec
  ## interop - see gemfile(5) and e.g
  ## Specification Reference @
  ## https://guides.rubygems.org/specification-reference/

  ## field descriptions for serializable fields of this class
  ##
  ## @see ::mk_fdescs
  ## @see ::fdesc_init
  SERIALIZE_FIELDS = [:name, :version, :homepage,
                      :summary, :description, :license,
                      [:require_paths, :sequence],
                      [:lib_files, :sequence],
                      [:test_files, :sequence],
                      [:doc_files, :sequence],
                      [:authors, :sequence],
                      [:metadata, :mapping]]

  ## FIXME provide a similar mapping,, GEMSPEC_FIELEDS
  ## under RbProject

  ## for an element in +SERIALIZE_FIELDS+, initialize a
  ## *FieldDesc* instance corresponding to the field
  ## described in that element
  ##
  ## @param datum [Symbol or Array] a field description
  ##
  ## @return an initialized instance of some subclass of
  ##  *FieldDesc*, as determined per the syntax of the provied
  ## *datum*
  ##
  ## @see SERIALIZEE_FIELDS
  ## @see ::mk_fdescs
  def self.fdesc_init(datum)
    if (datum.is_a?(Array))
      name = datum[0]
      typ  = datum[1]

      case typ
      when :sequence
        SequenceFieldDesc.new(self,name)
      when :mapping
        MappingFieldDesc.new(self,name)
 else
        raise "Unsupported FieldDesc type #{typ} in #{datum}"
      end
    else
      ScalarFieldDesc.new(self, datum)
    end
  end

  ## Create an array of *FieldDesc* objects from
  ## *SERIALIZE_FIELDS+, as representing serializable fields of
  ## this class. The value will be stored for memoization in
  ## +@class_fdescs+, for later retrieval after the first call to
  ## this method.
  ##
  ## @return an array of *FieldDesc* objects
  ##
  ## @see ScalarFieldDesc
  ## @see SequenceFieldDesc
  ## @see MappingFieldDesc
  ##
  ## @fixme should return a Hash mapped onto generalized filed
  ##  names, such that would represent mapping key names under
  ##  YAML encoding
  def self.mk_fdescs()
    ## FIXME this should use a map with each
    ## key being the generalized field name
    ## for each fdesc value, with subsq methods
    ##  self.find_fdesc; self.each_fdesc
    @class_fdescs ||= self::SERIALIZE_FIELDS.map do |field|
      self.fdesc_init(field)
    end
  end

  ##
  ## instance methods for the Proj YAML/Gemspec interop API
  ##

  ## @see Specification Reference
  ##  https://guides.rubygems.org/specification-reference/
  def author()
    if ( @authors && ( @authors.length > 1) )
      raise "Multiple authors defined, in #{__method__} for #{self}"
    else
      @authors && @authors[0]
    end
  end

  def author=(value)
    @authors= [ value ]
  end

  def add_author(value)
    ## NB semantics of a unique list
    if @authors
      @authors.find { |elt| elt == value } ||
        @authors.push(value)
    else
      @authors = [value]
    end
  end

  def remove_author(value)
    @authors && @authors.delete(value)
  end



  ## interop. with the Psych API, as under *Psych.load*
  ##
  ## @param coder [Psych::Coder]
  ##
  ## @see Psych::Visitors::ToRuby
  ## @see #encode_with
  ## @see #load_yaml_stream
  ## @see #load_yaml_file
  ## @see ::load_yaml_file
  def init_with(coder)
    ## NB If initializing a Proj with this method
    ## under Psych.load, if not using any calling
    ## method that would maintain any additional
    ## state data, it would loose any source file
    ## pathname. Furthermore, it may then not be
    ## possible to differentiate what values
    ## were initialized from an include file
    ##
    ## FIXME the naive include file recording
    ## approach in this API should be reviewed
    ## for subsequent revision.
    ## - TBD integration with an OrderedHash
    ##   extension under #encode_with
    ## - TBD application of an e.g @conf_fields
    ##   instance variable, for the configuration API
    ## - TBD encoding for 'include' directives
    ##   under the @conf_fields sequence
    ## - TBD handling for "included files"
    ##   under "write YAML to file"
    ##   - TBD initialization of Proj partial configuration
    ##     objects, for representing the configuration
    ##     data of any included file
    ##     - Proj#config_file
    ##       - ConfigFile#pathname (host pathname ... TBD)
    ##       - ConfigFile#mtime
    ##       - Utils::IO::ConfigFile ([<project_root>/lib/]rbproject/configfile.rb) << FileInfo (requires rbloader/fileinfo)
    ##     - Proj#include_config => ConfigFile
    ##       "including" ConfigFile - #inicluded_from
    ##     - Proj#reload_config(reset=false) (presently load_yaml...)
    ##     - Projg#write_config(includes=false) (presently write_yaml_...)
    (coder.type == :map) ||
      raise("Unsupported coder type #{coder.type} in #{coder}")

    fdescs = self.class::mk_fdescs()

    @fields_from_conf ||= []
    opts = {:symbolize_names => true,
            :aliases => true}
    coder.map.each do |k,v|
      puts "--[DEBUG] initializing #{self} with #{k} => #{v}"
      load_yaml_field(k.to_sym, v, fdescs, **opts)
    end

  end

  ## interop. with the Psych API, as under *Psych.dump*
  ##
  ## @param coder [Psych::Coder]
  ##
  ## @see Psych::Visitors::YAMLTree
  ## @see #init_with
  ## @see #write_yaml_stream
  ## @see #write_yaml_file
  def encode_with(coder)
    ## initialize the coder@map, per each bound
    ## insrtance variable

    if (coder.type != :map)
      raise "Unsupported coder type: #{coder.type} for #{coder} in #{__method__}"
    else
      coder.tag = encode_with_tag ## NB nil by default
      map = coder.map
    end

    ## FIXME the following is not well documented. This may be
    ## of use singularly for Proj mapping onto/from YAML text

    fdescs = self.class::mk_fdescs()

    if @fields_from_conf
      top_src_file = nil
      @fields_from_conf.each { |field|
        ## FIXME move this into a separate method
        ##
        ## replay configuration events stored under @fields_from_conf
        ## using present values in the instance - omitting any
        ## configuration events from included files (FIXME this
        ## part needs further refinement)
        conf_name = field[0]
        case conf_name
        when :include
          include_file= field[1]
          k = YAMLScalarExt.new("include")
          v = YAMLIncludeFile.new(include_file)
          map[k] = v
          top_src_file ||= field[2]
        when :extra_conf_data
          src_file = field[2]
          if (top_src_file.nil? ||
              (top_src_file == src_file))
            k = field[1]
            v = @extra_conf_data[k]
            map[k] = v
            top_src_file ||= src_file
          end
        else
          src_file = field[1]
          if (top_src_file.nil? ||
              (top_src_file == src_file))
            fdesc = fdescs.find { |f| f.name == conf_name}
            v = fdesc.get_value(self)
            map[conf_name]=v
            top_src_file ||= src_file
          end
        end
      }
      ## FIXME now store each initialized var under <fdescs>
      ## that was not configured under @fields_for_conf
    else
      ## FIXME API does not yet suport adding configuration 'include'
      ## directives if not somehow recorded in @fields_from_conf
      fdescs.each { |fdesc|
       if fdesc.value_in?(self)
         k = fdesc.name
         v = fdesc.get_value(self)
         map[k]=v
       end
      }
    end
  end


  ##
  ## initialize a field of this *Proj* instance from a
  ## deserialized YAML mapping pair provided in the +name+,
  ## +value+ params
  ##
  ## for sequence-type and mapping-type fields, this method
  ## may append values to the field denoted by +name+
  ##
  def load_yaml_field(name, value, field_descs, **loadopts)

    if ( source_file = loadopts[:filename] )
      source_file = File.expand_path(source_file)
    end

    if (name == :include) || (name.is_a?(YAMLScalarExt) &&
                              name.value == "include")

      yfile = value.is_a?(YAMLScalarExt) ? value.value : value

      abs = File.expand_path(yfile, source_file && File.dirname(source_file))
      @fields_from_conf.push [:include, yfile, source_file]
      ## FIXME provide a "load option" to continue
      ## when the include file is not available
      opts = loadopts.dup
      opts[:filename] = abs ## FIXME store the yfile path as provided
      self.load_yaml_file(abs,**opts)
    else

      fdesc = field_descs.find  {
        |f| f.name == name
      }

      if fdesc
        @fields_from_conf.push [name, source_file]
        case fdesc.type
        when :scalar
          fdesc.set_value(self,value)
        when :sequence
          if value.is_a?(Array)
            value.each do |v|
              fdesc.add_value(self,v)
            end
          else
            ## NB probably not reached from the
            ## YAML deserialization
            fdesc.add_value(self,value)
          end
        when :mapping
          ## NB 'value' here will be a hash table
          ## from the YAML deserialization
          fdesc.store_values(self,value)
        else
          raise "Unsupported FieldDesc type: #{fdesc.type} in #{fdesc}"
        end
      elsif (name == :extra_conf_data)
        ## assumption: the value represents a hash table, such
        ## that would have been encoded as a YAML mapping
        value.each do |extra_name, extra_value|
          @fields_from_conf.push [:extra_conf_data, extra_name, source_file]
          self.set_extra_conf_data(extra_name,extra_value)
        end
      else
        ## unkonwn top level { name => value } pair
        ## will be stored in extra_conf_data
        @fields_from_conf.push [:extra_conf_data, name, source_file]
        self.set_extra_conf_data(name,value)
      end
    end
  end

  ##
  ## initialize this *Proj* using YAML data in the provided
  ## stream
  ##
  ## @param io [IO or StringIO or String]
  ##
  ## @note This method will not reset any initialized instance
  ##  variables before loading the YAML stream
  ##
  def load_yaml_stream(io, **loadopts)
    if io.respond_to?(:eof) && io.eof
      raise EOFError.new("End of file on stream #{io}")
    end

    ## NB when reading YAML tagged with Proj::YAML_TAG here,
    ## Psych will crate a new Proj other than 'self'

    ## FIXME this may not gracefully handle some
    ## formatting errors in the file.
    ##
    ## This assumes that the file can be parsed
    ## as a top-level mapping or dictionary

    ## FIXME this dictionary syntax does not
    ## allow for project file includes, e.g
    ## to reuse common project fields, in this
    ## "YAML is not msbuild XML" hack

    opts = loadopts.dup

    opts[:symbolize_names] ||= true
    opts[:aliases] ||= true

    ## NB debug storage - FIXME will not overwrite previous
    ## entries in @fields_from_conf if the instance is initialized
    ## more than once, from the same file & includes. That should
    ## be managed in some calling method, to set @fields_from_conf
    ## to an empty array before reinitializing the instance from
    ## configuration files
    @fields_from_conf ||= []

    ## NB The fdecs table will be neededl such as when the YAML
    ## mapping in the YAML stream does not store the YAML tag
    ## corresponding to this class. In this case, the parsed
    ## field data from the YAML stream would have to be loaded
    ## into the new instance, principally external to #init_with
    fdescs = self.class::mk_fdescs()

    ## FIXME this, for safe_load
    opts[:permitted_classes] ||= [Proj, Symbol]

    out = Psych.safe_load(io, **opts)

      case out.class.name
      when Hash.name
        out.each do
          ## initialize the new instance 'instance'
          ## per { key => value } pairs in the data
          ## deserialized from the top-level mapping
          ## assumed to have been encoded in the YAML
          ## stream
          ##
          ## Assumptions:
          ## - the value of <name> is a symbol
          ## - the value of <value> is a list, hash,
          ##   or scalar value
          |name, value|
                 load_yaml_field(name, value, fdescs, **opts)        end

      when NilClass.name
        raise "safe_load failed (no output - end of file?) in #{__method__} for stream #{io}"
      else
        if ! out.is_a?(Proj)
          raise "unexpected parser output, class #{out.class} in #{__method__}: #{out}" 
        else
          return out
        end
      end
      return self
  end

  ##
  ## initialize this *Proj* using YAML data in the specified file
  ##
  ## @note This method will not reset any initialized instance
  ##  variables before loading the YAML stream
  ##
  def load_yaml_file(filename, **loadopts)
    ## FIXME provide an extended loadopt for file encoding
    f = File.open(filename, "rb:BOM|UTF-8")
    opts = loadopts.dup
    opts[:filename] = filename
    self.load_yaml_stream(f,**opts)
    ensure
      f && f.close
  end

  ##
  ## encode this *Proj* in YAML syntax, using the provided stream
  ##
  def write_yaml_stream(io, **dumpargs)
    dumpargs[:line_width] ||= 65
    dumpargs[:header] ||= true

    Psych.dump(self, io, **dumpargs)
  end

  ##
  ## encode this *Proj* in YAML syntax at a file of the specified
  ## pathname
  ##
  def write_yaml_file(pathname, **dumpargs)
    ##
    ## FIXME store the original file pathname, during ::load_yaml_file
    ##
    ## & Write to that file by default, here
    ##
    ## implies: Project Workspace
    ##

    ## FIXME if @fields_from_conf is non-nil and non-empty
    ## then iterate across the same,
    ## else ... TBD/FIXME using SERIALIZE_FIELDS

    f = File.open(pathname, "wb:BOM|UTF-8")
    write_yaml_stream(f, **dumpargs)
    f.flush
    return f
    ensure
      f && f.close
  end


  # def write_gemfile(dest)
  # end

end


# END {
#   ## FIXME not reached until irb exit?
#   ## when file is loaded with irb, via #require or #load
#   ## w/ ruby 3.0.2p107 (Arch Linux)
#
#   puts "DEBUG: in END block for #{__FILE__}"
# }


=begin

## trivial tests for Proj serialization/deserialization
## onto YAML

$FROB_P1 = Proj.load_yaml_file('../../rbloader.yprj')

$FROB_S00 = Psych.dump($FROB_P1, line_width: 65, header: true)

$FROB_P2 = Psych.safe_load($FROB_S00, symbolize_names: true)

## a general check for similarity across
## different encoding/decoding calls

IOST = StringIO.new

$FROB_S01 = $FROB_P1.write_yaml_stream(IOST)

IOST.pos=0

$FROB_P3 = Psych.load_stream(IOST, symbolize_names: true)

=end
