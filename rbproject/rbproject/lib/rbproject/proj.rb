## proj.rb

=begin Project docs

In this source file, at this revision:

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
      defined?(APP) && APP.log_debug(
        "In #{__method__}: Using tag '#{use_tag}' for class #{self}"
      )
      ## extclass
      Psych.load_tags[use_tag] = class_name
      #Psych.load_tags[use_tag] = self.name.to_sym # ??
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

      if block_given?
        yield [inst_var,add_name,rem_name,get_name,set_name]
      end
      return field
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
    def extclass.attr_map(field, trim_plural: true,
                          add_name: nil, rem_name: nil,
                          get_name: nil, set_name: nil)
      use_name = field.to_s
      inst_var = ('@' + use_name).to_sym
      verb_sfx = ( trim_plural && use_name[-1] == "s" ) ?
        use_name[...-1] : use_name
      add_name ||= ('set_' + verb_sfx).to_sym
      rem_name ||= ('remove_' + verb_sfx).to_sym
      get_name ||= use_name.to_sym
      set_name ||= (use_name + '=').to_sym

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

      if block_given?
        yield [inst_var,add_name,rem_name,get_name,set_name]
      end
      return field
    end ## attr_seq
  end ## self.extended(extclass)
end ## module CollectionAttrs

require('logger')
require('forwardable')

## mixin module for adding *log_*+ delegate methods to a class
## FIXME now duplicated in ~/wk/rbdevtools/gemreg/lib/riview.rb
module LoggerDelegate

  def self.extended(extclass)
    ## FIXME no way to pass parameters across Object#extend
    ##
    ## e.g the name of the instance variable to delegate to
    extclass.extend Forwardable

    ## FIXME needs documentation (params)
    ##
    ## TBD YARD rendering for define_method in this context
    ##
    ## NB application must ensure that the instance variable is
    ## initialized with a Logger before any delegate method is
    ## called - see example under Application#initialize
    define_method(:def_logger_delegate) do | instvar, prefix=:log_ |
      use_prefix = prefix.to_s
      Logger.instance_methods(false).
        select { |elt| elt != :<< }.each do |m|
          extclass.
            def_instance_delegator(instvar,m,(use_prefix + m.to_s).to_sym)
        end ## instance_methods block
    end ## def_logger_delegate block
  end ## self.extended block
end ## LoggerDelegate module


module AppIO

  ## IO options list for +::io_options!+
  ##
  ## @see ::io_options!
  ## @see IO::new
  IO_OPTION_FLAGS = [:mode, :flags,
                     :external_ecodiing,
                     :internal_encoding,
                     :encoding, :tetmode,
                     :binmode, :autoclose]


  ## TBD providing extended loadopts for file encoding
  ## (internal, external) and Unicode BOM options
  ## cf. Encoding docs - Encoding::find
  ##
  ## Here: supporting an :io_bom option
  ##
  ## TBD docs on the BOM option
  ##
  ## option io_bom:
  ##   UTF-8|UTF-16LE|UTF-16BE|UTF-32LE|UTF-32BE(upper/lowercase)
  ##
  ## NB UTF-16* implies file_mode: :binary which is used here
  ## by default
  ##
  ## TBD UTF-32* probably also
  ##
  ## NB test files used in ruby-src:spec/ruby/language/source_encoding_spec.rb
  ##
  ## NB MODE_SETENC_BY_BOM
  ##    in ruby-src:io.c
  ##
  ## NB ri docs for IO::new


  def self.included(extclass)

    ## @PARAM MODE [String] mode as in +File::open+, absent of
    ##   any BOM of encoding strings
    ## @param options [Hash] will be dstructively modified if :io_bom
    ##   is provided in +options+, such as to remove the argument
    ##   name and value
    ##
    ## @see ::io_options!
    def extclass.bom_option_string!(mode, options, default = "UTF-8")
      ## FIXME needs documentation

      use_mode = mode.to_s
      if options.key?(:io_bom)
        if use_bom = options[:io_bom]
          opts_str="#{use_mode}:BOM|#{use_bom.to_s}"
        else
          ## i.e io_bom: false | io_bom: nil
          opts_str = use_mode
        end
        options.delete(:io_bom)
      elsif default
        opts_str = "#{use_mode}:BOM|#{default}"
      else
        opts_str = use_mode
      end
      return opts_str
    end


    ## process the provided *opts* map for any key, value pairs
    ## with a key denoted in +IO_OPTION_FLAGS+. For each matching
    ## key, delete the key, value pair from +opts+ and add the
    ## options pair to the return value. For any options provided
    ## in +defaults+, add those options to the return value if no
    ## matching key is provided in *opts*. Returns the
    ## constructed IO options map
    ##
    ## This method may destructively modify the options map
    ## +opts+, in filtering options to produce the return value.
    ##
    ## @param opts [Hash]
    ## @param defaults
    ## @return [Hash]
    ## @see IO::new
    ## @see ::bom_option_string!
    def extclass.io_options!(opts,**defaults)
      use_options={}
      IO_OPTION_FLAGS.each do |flag|
        if opts.key?(flag)
          use_options[flag]=opts[flag]
          opts.delete(flag)
        end
      end
      defaults.each do |arg,argv|
        if ! use_options.key?(arg)
          use_options[arg]=argv
        end
      end
      return use_options
    end
  end
end

##
## naive Application class
##
class Application

  ## FIXME revise to a mixin module for use under 'extend'

  ## FIXME define a subclass YAMLApplication
  ## && integrate with a Config::YAMLConfig (file, ...)

  ## - FIXME use a gem for XDG dirs
  ## - define a default log file under some data dir for
  ##   this application nmame
  ## - apply log rotation, when the Application class is
  ##   initialized with same default "app logger"

  attr_reader :name
  attr_reader :logger

  extend(LoggerDelegate)
  def_logger_delegate :@logger

  LOG_LEVEL_DEFAULT = Logger::WARN

  def initialize(name = "App-" + Random.rand.to_s[2..],
                 logger: nil)
    @name = name
    if logger
      use_logger = logger
    else
      use_logger = Logger.new(STDERR)
      use_logger.level = LOG_LEVEL_DEFAULT
      use_logger.progname = name
    end
    @logger = use_logger
  end
end


=begin TBD
BEGIN {
  ## FIXME handle elsewhere
  ##
  ## FIXME N/A with the Application class defined in this source file
  APP = nil
  APP ||= Application.new("MAIN").tap {
    |app| app.log_level = (
      defined?(IRB) && defined?(IRB.conf) ? Logger::DEBUG : Logger::WARN
    )
  }
}
=end


require_relative('interop')

##
## Project class
##
## @fixme This class provides an effective mashup of
##  _configuration API_ and _application data API_ forms,
##  such that may serve to limit the portability of either
##  set of API forms.
class Proj

  include AppIO ## FIXME move to an AppData class

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
  ##
  ## This mapping may be configured e.g
  ##  Psych.load_tags[<class>] = <tag>
  ##
  ## ... after which, the provided <tag> will be used
  ## when serializing any instance of the denoted <class>
  ##
  ## Additional notes:
  ##
  ## - When the mapped class is redefined, each converse
  ##   tags/class mapping value should generally be stored
  ##   newly, for the mapped tag
  ##
  ## - Towards extension: This class/tag mapping behavior may
  ##   be used for supporting YAML deserialization of instances
  ##   of classes defined in langauges other than Ruby, or for
  ##   general YAML interchange.
  ##
  ## TBD as to how it may map into any of Psych's json support
  ##
  ## TBD how to ensure, under a Proj#init_with method, that
  ## any non-serializing instance variables will not be
  ## encoded in the YAML serialization stream
  ##
  ## TBD further annotations/notes/docs as to how to implement
  ## an :init_with method, e.g onto the ... thing ... passed
  ## to the method such as from Psych::Visitors::ToRuby#deserialize
  ##
  ## - NB broad similarity to the :encode_with semantics under
  ##   Psych::Visitors::YAMLTree#accept ... singularly onto
  ##   #dump_coder and subsq. #emit_coder
  ##   ... moreover only under calls to YamlTree#accept
  ##       ... e.g for Struct object members ...
  ##       ... or Range limits
  ##       ... or each Hash key, value
  ##       ... or Set key, value (value generally 'true' ??)
  ##       ... or other Enumerator elements (each)
  ##       ... or TBD onto BasicObject under YAMLTree (Ruby-marshalable objects)
  ##       ... or TBD instance variables of "array subclasses" and sometimes
  ##           also individual elements of the instance (??)
  ##       ... or TBD onto a "hash subclass" (FIXME test with the Options API)
  ##       ... or for serializing a ruby exception ... #accept on
  ##           the exception message and the exception backtrace
  ##   ... and in #dump_coder (note also, Coder instance usage as
  ##       dentoed below, for deserialization - a Coder is not a
  ##       Psych Node, but may represent a value in some ways
  ##       parallel to the AST-relevant nature of a Psych Node)
  ##
  ## - The arg to the :init_with method will be an instance of
  ##   Psych::Coder initialized with the bound tag,
  ##   and subsequently ...
  ##   - for a scalar node under ToRuby#deserialize: The 'value'
  ##     of the scalar node stored under the <<coder.scalar>>
  ##     field, and thus with a Coder@type = :scalar
  ##   - For a sequence node: a <<coder.seq>> field containing the
  ##     original children.map of the sequence node
  ##     ... subsq Coder@type = :seq
  ##   - For a mapping node mapped with such as Psych.load_tags
  ##     ... TBD :init_with under ToRuby#revive &&
  ##         ToRuby#revive_hash ... hash key, value mapping from the latter
  ##     ... there with a <coder.map>> field containing
  ##         (see below)
  ##      ... subsq Coder@type = :map
  ##   - Otherwise for a mapping node (not dispatched per load_tags)
  ##      - for each, with subsq Coder@type = :map
  ##      - onto a struct tag:
  ##        TBD how it's mapped from ToRuby#init_with
  ##      - onto a string deserialized as a mapping
  ##        TBD at #init_with there (initializing a string and
  ##        remapped instance variable encoding
  ##      - onto a deserialized Ruby exception
  ##        TBD at #init_with there (initializing a hash table?)
  ##      - onto an object serialized with a tag '!ruby/marshalble:...'
  ##        TBD ... and a #revive_hash call. (See also
  ##        :mashal_load under this branch in ToRuby)
  ##    - ToRuby#init_with is also called in ToRuby#revive
  ##    - ToRuby#init_with itself will call any :init_with method
  ##      of the object provided as the first arg to ToRuby#init_with,
  ##      passing a 'Coder' instance then initialized with the
  ##      tag of the third arg to ToRuby#init_with, subsq
  ##      with the value of the second arg to ToRuby#init_with
  ##      stored under the <<coder.map>> field


  def self.load_yaml_file(filename, **loadopts)
    ## FIXME may not be immediately useful
    ## for deserialization of any subclass instance
    ##
    ## FIXME provide an extended loadopt for file encoding
    instance = self.allocate
    instance.load_yaml_file(filename, **loadopts)
    return instance
  end

  attr_reader :encode_with_tag ## FIXME move to a ConfigFile subclass

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
  ## for interop onto Hash key,values pairs and other instances
  ## of this class - supporting scalar, sequence i.e array, and
  ## mapping i.e hash type field values
  ##
  ## @see ::yaml_field_broker
  YAML_FIELDS = [:name, :version, :homepage,
                 :summary, :description, :license,
                 [:require_paths, :seq],
                 [:lib_files, :seq],
                 [:test_files, :seq],
                 [:doc_files, :seq],
                 [:authors, :seq],
                 [:metadata, :map]]


  def self.yaml_field_broker()
    if @yaml_field_broker &&
        ( @yaml_field_broker.internal_class.eql?(self.class) )
      @yaml_field_broker
    else
      fieldbroker = FieldBroker::HFieldBroker.new(self)
      YAML_FIELDS.each { |elt|
        if elt.is_a?(Array)
          name = elt[0]
          kind = elt[1]
        else
          name = elt
          kind = :scalar
        end
        fieldbroker.add_bridge(name, kind: kind,
                               external_name: name.to_s,
                               instance_var: true)
      }
      @yaml_field_broker = fieldbroker
    end
  end

  attr_reader :app


  def initialize(app: Application.new(self.to_s[2...-1]))
    ## TBD delegate methods for logging onto app.logger
    ## .. FIXME logging unused except for debug ...
    ##
    ## NB @app cannot be assumed to have been initialized for
    ## any objects created originally in Psych.load
    @app = app
  end

  ## configure a YAML tag to use for encoding this instance
  ##
  ## If +value+ is the value +true+, then the class' value of
  ## +::YAML_TAG+ will be used as the encoding tag
  ##
  ## If +value+ is false, no encoding tag will be used. This is
  ## the default behavior for +Proj+, as it ensures that any
  ## +Proj+ configuration data will be encoded to a generalized
  ##YAML mapping
  ##
  ## If +value+ is any other value, that value will be used as
  ## the YAML encoding tag for this instance. For purpose of
  ## deserialization, a siimlar tag should be used under
  ## +Psych.load_tags+ e.g
  ##     Psych.load_tags[custom_tag]=custom_class.name
  ## Thus, +Psych.load+ may be able to create an object of the
  ## appropriate class, when processing the subsequent YAML
  ## encoding stream under +Psych::Visitors::ToRuby+.
  ##
  ## @param value [boolean or String] value to use in configuring
  ##  any YAML encoding tag for this instance
  ##
  ## @see #encode_with
  ## @see #init_with
  ## @see Psych.dump_tags
  ## @see Psych.load_tags
  ## @see ::YAML_TAG
  ## @see ::init_yaml_tag(...)
  def encode_with_tag=(value)
    case value
        when true
          use_value = self.class::YAML_TAG
        when false
          use_value = nil
        else
          ## NB this branch may not be very well supported,
          ## insofar as for reading tagged YAML without further
          ## configuration onto the Psych API,
          ## e.g per Psych.load_tags and #init_with
          use_value = value
    end
    @encode_with_tag = use_value
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
  ## This method will typically not be reached unless decoding
  ## tagged YAML, with a tag equivalent to *YAML_TAG* in this class
  ##
  ## @param coder [Psych::Coder]
  ##
  ## @see YAML_TAG class constant
  ## @see #load_yaml_stream instance method
  ## @see #load_yaml_file instance method
  ## @see ::load_yaml_file class method
  ## @see #encode_with instance method, onto the Psych API
  ## @see #encode_with_tag instance field
  ## @see Psych::Visitors::ToRuby class
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


    fbroker = self.class.yaml_field_broker()

    @fields_from_conf ||= [] ## FIXME w/ field broker interop
    opts = {:symbolize_names => true,
            :aliases => true}
    coder.map.each do |k,v|
      load_yaml_field(k.to_sym, v, fbroker, **opts)
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

    ## FIXME special case of HFieldBroker.export_... here
    ## - TBD HConfFieldBroker.export_conf

    if (coder.type != :map)
      raise "Unsupported coder type: #{coder.type} for #{coder} in #{__method__}"
    else
      coder.tag = @encode_with_tag ## NB nil by default
      map = coder.map
    end

    ## FIXME the following is not well documented. This may be
    ## of use singularly for Proj mapping onto/from YAML text

    fbroker = self.class.yaml_field_broker()

    ## FIXME this @fields_from_conf approach may serve
    ## two main purposes:
    ## 1) Ensure that any configuration file is written
    ##    with fields in an order generally matching
    ##    that in which the fields were read from the file
    ## 2) Ensure that any include directives are maintained
    ##    as across the representation in @fields_from_conf
    ##
    ## Limitations
    ## - This does not provide any support for appending or
    ##   otherwise editing configuration history, outside
    ##   of the parsing of any single configuration file
    ## - This does not presently provide deduplication
    ##   in the configuration history


    if @fields_from_conf
      ## ** FIXME ** This section needs cleanup
      ## & configuration history API development
      ## @ configuration history "roll out"
      ## ... or anything more innocuous in terms

      wrote_fields = []
      wrote_extra_conf = []

      ## initialize the coder.map from configuration history
      top_src_file = nil
      @fields_from_conf.each { |field|
        ## FIXME move this into a separate method
        ##
        ## replay configuration events stored under @fields_from_conf
        ## using present values in the instance - omitting any
        ## configuration events from included files (FIXME this
        ## part needs further refinement)
        conf_name = field[0]
        ## NB the following represents an intrinsic mapping
        ## from @fields_from_conf elements onto
        ## a Psych::Coder.map hash, as for purpose of
        ## encoding from an initial configuration
        ## to an external YAML stream
        ##
        ## FIXME each branch of the following could
        ## be handled with a separate block, in a
        ## mapping from some @fields_from_conf token
        ## e.g :include, :extra_conf_data, or a Proj
        ## field name, onto some external method as
        ## to an effect of storing the identity and
        ## value of the configured field (or include)
        ## into the map of the coder
        ##
        ## ... i.e onto a field bridge x conf hitory API?
        case conf_name
        when :include
          ## FIXME skip if :merge_config is false
          ## ... from whence however (??)
          ## coder.tag would be the only value that can be
          ## effectively passed through from Psych.dump
          ## to encode_with, excepting any values stored
          ## as instance variables in self, e.g
          ##
          ## so, ConfigFile#merge_config ?
          ## onto a self.config field

          ## ... TBD yielding fields_from_conf data,
          ## and the coder map, to a block provided
          ## such as like the following, in some
          ## branch-specific method for a mapping
          ## from the :include @fields_from_conf
          ## element onto the Psych::coder (for output to YAML)
          include_file= field[1]
          src_file= field[2]
          if (top_src_file.nil? ||
              (top_src_file == src_file))
            ## store in map only if included from top_src_file
            ##
            ## FIXME this does not suport re-serialization of
            ## included files
            k = YAMLScalarExt.new("include")
            v = YAMLIncludeFile.new(include_file)
            map[k] = v
            top_src_file ||= src_file
          end
          ## FIXME :metadata hash keys not being "re-stringified" on
          ## output - not an error ...
        when :extra_conf_data
          src_file = field[2]
          if (top_src_file.nil? ||
              (top_src_file == src_file))
            ## NB storing only data from top_src_file
            k = field[1]
            v = @extra_conf_data[k]
            map[k.to_s] = v
            top_src_file ||= src_file
            wrote_extra_conf.push(k)
          end
        else
          ## using the field broker
          ##
          ## TBD see also ./confhist.rb
          src_file = field[1]
          if (top_src_file.nil? ||
              (top_src_file == src_file))
            bridge = fbroker.find_bridge(conf_name) do
              |broker,field|
              ## NB - this would represent a disparity
              ## between @fields_from_conf and YAML_FIELDS
              ## if a directive (here, a field name) apepars
              ## in @fields_fromo_conf that is not in YAML_FIELDS
              ## and is not an :extra_conf_data or :include
              ## directive
              raise "Not a serializable field: #{field}"
            end

            if (bridge.value_in?(self)
                !wrote_fields.find{ |f| f == conf_name})
              wrote_fields.push(conf_name)
              bridge.export(self, map)
              ## NB each of these branches serves to ensure
              ## that the first src_file read will be used
              ## as the top_src_file - it's a hack, absent
              ## of any normative configuration history API
              top_src_file ||= src_file
            end
          end
        end
      }
      ## now store each initialized, serializable field that was
      ## not configured under @fields_for_conf
      ##
      ## FIXME this would write data processed from any
      ## include files
      ##
      # fbroker.field_map.each do |field, bridge|
      #   wrote_fields.find{ |f| f == field } ||
      #     bridge.export(self, map)
      # end

      ## lastly, write any unwritten extra_conf_data
      ##
      ## FIXME this would write any extra_conf_data that was
      ## picked up from an include file
      # @extra_conf_data.each do |k,v|
      #   wrote_extra_conf.find{|name| name == k} ||
      #     map[k] = v
      #   wrote_extra_conf.push[k]
      # end

    else
      ## FIXME API does not yet suport adding configuration 'include'
      ## directives if not somehow recorded in @fields_from_conf
      fbroker.export_mapped(self, map)
    end
    return coder
  end


  ##
  ## initialize a field of this *Proj* instance from a
  ## deserialized YAML mapping pair provided in the +name+,
  ## +value+ params
  ##
  ## for sequence-type and mapping-type fields, this method
  ## may append values to the field denoted by +name+
  ##
  def load_yaml_field(name, value, fbroker, **loadopts)

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
      catch(:imported) do
        fbridge = fbroker.find_bridge(name) {
          @fields_from_conf.push([:extra_conf_data, name, source_file])
          self.set_extra_conf_data(name, value)
          throw :imported
        }
        @fields_from_conf.push([name, source_file])
        fbridge.import_value(self,value)
      end
      return value
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

    ## NB trivial configuration history - FIXME will not
    ## overwrite previous entries in @fields_from_conf if the
    ## instance is initialized more than once, from the same file
    ## & includes. That may be managed in some calling method,
    ## to set @fields_from_conf to an empty array before
    ## reinitializing the instance from configuration files
    @fields_from_conf ||= []

    fbroker = self.class.yaml_field_broker()

    ## FIXME a required parameter, when using safe_load
    ## - needs local paramterization, e.g under further
    ## usage testing for Proj-to-YAML serialization
    opts[:permitted_classes] ||= [Proj, Symbol,
                                  YAMLScalarExt, YAMLIncludeFile]

    out = Psych.safe_load(io, **opts)

      case out.class.__id__
      when Hash.__id__
        ## Psych has parsed a generalized YAML mapping
        out.each do
          ## initialize this instance per { key => value } pairs in the
          ## data deserialized from the top-level mapping read from 'io'
          |name, value|
                 load_yaml_field(name.to_sym, value, fbroker, **opts)
        end

      when NilClass.__id__
        raise "safe_load failed (no value) \
in #{self.class}##{__method__} for stream #{io}"
      else
        if ! out.is_a?(Proj)
          raise "unexpected value from safe_load \
in #{self.class}##{__method__}: Not a Proj: #{out}"
        else
          ## NB here: out != self
          ##
          ## i.e 'out' was probably deserialized from a tagged
          ## YAML mapping for any arbitrary instance of this
          ## class
          ##
          ## The following will proceess serializable fields from
          ## the new object 'out', for mapping into the object
          ## 'self'
          fbroker.map_fields do |bridge|
            if bridge.value_in?(out)
              load_yaml_field(bridge.name,
                              bridge.get_internal(out),
                              fbroker, **opts)
            end
            ## FIXME also parse for extra_conf_data from 'out'
          end
          ## TBD logger storage
          $LOGGER &&
            $LOGGER.log_warn("In #{self.class}##{__method__} for #{self}: \
Discarding ephemeral instance #{out}")
          return self
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
    ## FIXME :io_bom option/support needs documentation
    ## similarly, the args pass-through to File.open
    opts = loadopts.dup
    mode_str = self::bom_option_string!("rb", opts)
    open_opts = self::io_options!(opts)
    f = File.open(filename, mode_str, **open_opts)
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
  ## encode this *Proj* in YAML syntax, in a file of the specified
  ## pathname
  ##
  ## @param pathname [String]
  ## @param dumpargs
  def write_yaml_file(pathname, **dumpargs)
    ##
    ## FIXME store the original file pathname, during ::load_yaml_file
    ##
    ## & Write to that file by default, here
    ##
    ## - may imply: Project Workspace (??)
    ## - needs usage cases - modification of Proj data after load
    ##   + re-write to original & included files
    ##

    ## FIXME :io_bom option/support needs documentation
    ##
    ## FIXME parse other loadopts for pass through to File.open
    ## cf IO.new RI docs
    opts = dumpargs.dup
    ## FIXME :io_bom option/support needs documentation
    ## similarly, the args pass-through to File.open
    mode_str = self::bom_option_string!("wb", opts)
    open_opts = self::io_options!(opts)
    f = File.open(pathname, mode_str,**open_opts)
    write_yaml_stream(f, **opts)
    f.flush
    return f
    ensure
      f && f.close
  end


  ## TBD using a special environment during load (??)
  ## but capturing some return value, namely a gemspec
  ## object
  ##
  # def write_gemspec(dest)
  # end
  #
  # def load_gemspec(dest)
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


# NB more on Ruby iterators : it#each_slice

[1,2,3,4].each_slice(2) {
  |a,b| puts a.to_s + ": " + b.to_s
}

=end

# Local Variables:
# fill-column: 65
# End:
