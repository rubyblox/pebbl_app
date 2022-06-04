require('psych')

require('set')


## Description of a Struct class, from serialized data
class StructDesc
  attr_reader :struct_name  ## String or nil
  attr_reader :fieldset ## Set
  attr_reader :finalized

  ## If +tag+ begins with the prefix +!ruby/struct:+
  ## returns any struct name following the prefix,
  ## or +false+ if there is no name text following
  ## the prefix. If +tag+ does not match the prefix,
  ## returns nil.
  ##
  ## @param tag [String] a YAML block tag
  ## @return +nil+, +false+, or a struct name as
  ##  a *String*
  ##
  ##  Assuming that an anonymous struct class cannot
  ##  normally be encoded in YAML under Ruby, the
  ##  return value may generally be +nil+ or a
  ##  *String*
  ##
  ## @fixme it should be trivial to define a test case
  ##  for this method
  ##
  ## @fixme Move this method into another class and
  ##  update to accept any prefix, e.g such as to
  ##  parse a conventional class name out of a
  ##  block tag in YAML. That "Other class" may
  ##  be a general subclass of TreeBuilder
  def self.name_from_tag(tag)
    if (tag.match?('^!ruby/struct:'))
      offset = tag.index(':')
      if ( offset && ( offset < tag.length ) )
        tag.slice(1+offset..)
      else
        return false
      end
    end
  end

  def initialize(struct_name = nil, fieldset = nil)
    ## FIXME does not perform any checking on constructor params,
    ## at this version 0.0.1
    @struct_name = struct_name
    @fieldset = fieldset
  end

  def add_field(name)
    ## FIXME probably too simple, this
    ## - does not check for duplicate names
    ## - TBD further limitations

    if @finalized
      raise "Cannot add a field to a finalized #{self.class}: #{name} onto #{@struct_name}"
    end

    if (name.instance_of?(String))
      use_name = name.to_sym
    elsif (name.instance_of?(Symbol))
      use_name = name
    else
      raise "Unsupported syntax for a field name: #{name}"
    end
    if @fieldset
      @fieldset.add(use_name)
    else
      @fieldset =  Set.new([use_name])
    end
    return use_name
  end

  def finalize()
    @finalized = true
  end


  # def to_struct() ## see below, at mk_structs
  # end
end

## Description of a Struct instance and transitively,
## a Struct class, from serialized data
class StructInstanceDesc < StructDesc ## UNUSED
  ## FIXME revise this API to use only StructDesc,
  ## for representation of Struct class information
  ## external to the Psych Nodes API
  ## - StructMapping could ostensibly be removed
  ## - StructTreeBuilder#start_mapping could ostensibly
  ##   be updated to simply create a StructDesc
  ##   and store it in e.g @active_struct
  ##   then adding any field desc under #scalar
  ##   and at least resetting the active field desc
  ##   under any "reader" branch (scalar, etc) for
  ##   what would represent the struct field value.
  ##   in end_mapping, @active_struct (when true)
  ##   would also need to be finalized and the field
  ##   set to false or nil
  ##
  ## Albeit, this lot of present code ...
  ## has been quite time consuming, so far,
  ## in development even to this point.

  ## TBD: When is to_ruby called ...

  ## FIXME this allows for only one StructInstanceDesc
  ## per each StructDesc
  ##
  ## FIXME provide separate implementations of
  ## StructDesc and StructInstanceDesc such that
  ## a StructDesc may be referred from zero or more
  ## StructInstanceDesc
  def initialize(struct_name = nil, field_values = nil)
    ## @struct_desc = SomeContext.ensure_struct_dessc(struct_name)
    ## ^ FIXME in this class usage here, the "SomeContext" would
    ## be provided by a StructTreeBuilder

    ## FIXME iterate on field_values, assuming a Hash when not false
    if field_values ## assuming: hash table
      super(struct_name, field_values.keys)
    else
      super(struct_name, nil)
    end
    @field_values = field_values
  end

  def add_field_value(name, val)
    add_field(name) ## @struct_desc.add_field(name)
    if @field_values
      @field_values[name]=val
    else
      @field_values={ name => val }
    end
  end

##  def mk_instance
# see to_struct, above, and mk_structs subsq
##  end
end

## ...

class StructMapping < Psych::Nodes::Mapping
  attr_reader :struct_desc
  attr_reader :last_field
  attr_reader :builder

  def initialize(anchor = nil, tag = nil,
                 implicit = true, style = BLOCK,
                 builder = nil)

    ## TBD @ API testing
    # if ! tag
    #   raise "Cannot create a #{self.class} with no tag"
    # end
    #
    # if ( s_name = StructDesc.name_from_tag(tag) )
    #   if ! s_name
    #     raise "Cannot create a #{self.class} for an anonymous struct, in tag #{tag}"
    #   else
    #     ## TBD optional transformation on the struct class name, here
    #     ## - such as via options on #{builder}
    #     o      end
    # end


    ## FIXME for back-reference to existing struct/instance descs,
    ## need to store the active tree builder here,
    ## e.g via an additional arg 'builder'
    @builder = builder

    if ( s_name = StructDesc.name_from_tag(tag) )
      desc = ( builder.struct_desc_find(name) ||
               StructeDesc.new(s_name))
      @struct_desc = desc
    end
    super(anchor,tag,implicit,style)
  end

  def push_field(name)
    ## FIXME err if @struct_desc is nil ...
    @last_field = @struct_desc.add_field(name)
  end

  def finalize()
    ## FIXME err if @struct_desc is nil ...
    @struct_desc.finalize
  end
end


## NB FIXME/TBD Visitor/Emitter tooling (output)
## see
## lib/psych/visitors/yaml_tree.rb
##



class StructTreeBuilder < Psych::TreeBuilder
  ## < .. Psych::Handlers::DocumentStream ??
  ## ^ NB &block' in initialize

  attr_reader :structs

  def initialize()
    super
    ## NB super@stack
    ## - accessed under #push and #pop *private* methods
    ## - ;ast element pushed : accessible via @last
    ##
    # @struct_stack = ??
    @structs = []
    @field_read = false
  end

  ## Retrieve a *StructDesc* for a +struct_name+ provided as
  ## _+name+_. If no matching +StructDesc+ has been initialized
  ## to this builder, returns nil
  def struct_desc_find(name)
    @structs.find do |st|
      st.struct_name == name
    end
  end



  def start_mapping(anchor, tag, implicit, style)
    ## TBD using StructDesc here
    ##
    ## TBD soring an @active_struct during mapping,
    ## 

    ## NB if tag matches "!ruby/struct:",
    ## create a new StructMapping for the name
    ## of the struct type provided in the tag
    ##
    ## - FIXME must account for nonexistent modules,
    ##  per the provided name from a struct record
    if (tag && tag.match?('^!ruby/struct:'))
      ## FIXME if not an anonymous struct type and the struct type's
      ## name matches any existing mapping, then reuse that mapping here
      mapping = StructMapping.new(anchor, tag, implicit, style,
                                  self)
      ## FIXME this does not reuse any existing mapping
      @structs << mapping
      ## TBD this self.send semantics may not be highly efficient.
      ## If these were defined as protected methods, at least,
      ## then it would not be necessary. (Patch needed)
      self.send(:set_start_location,mapping)
      @last.children << mapping
      self.send(:push,mapping)
    else
      super
    end
  end

  def end_mapping()
      if @last.instance_of?(StructMapping)
        sdesc = @last.struct_desc
        sdesc.finalize
        # structs << sdesc ## NB nope. see << above
        ## FIXME what else is supposed to follow, here?
      #else
        #super
      end
      ## NB may need to call to super for all instances.
      ## By side effect, this may serve to ensure that
      ## any YAML 'document', under psych, will be ended
      ## on the input stream
      super
  end

  def scalar(value, anchor, tag, plain, quoted, style)
      if @last.instance_of?(StructMapping)
        if @field_read
          ## FIXME need to do similar for start_sequence
          ## and also in some branch of start_mapping
          @field_read=nil
        else
          @field_read = @last.push_field(value) ## field name, here
        end
      else
        super
      end
  end

  ## Define a +Struct+ subtype and instance each
  ## +StructInstanceDesc+ initialized to this
  ## +StructTreeBuilder+
  ##
  ## @param prefix [String or nil] If a string, specifies
  ##  a naming prefix to use for each created struct
  ##  type that is not an anonymous struct
  ##
  ## @param overwrite [boolean] If _true_, ovewrite any
  ##  existing Struct subclass definition for each named Struct type,
  ##  such that the the named Struct type - with any provided *prefix* -
  ##  would match a name already declared in +Struct.constants+, If
  ##  _false_, an error will raised for the first "Name overlap"
  ##
#  def mk_structs(prefix: nil, overwrite: nil)
## FIXME define under a subsq. changeset
#  end

end


## Parse a YAML serialization record as an implicit
## struct instance record
##
## @fixme needs a similar implementation, for an
##  arbitrary class name (under an arbitrary module
##  namespace)
class ImplicitStructTreeBuilder < StructTreeBuilder
  ## FIXME W.I.P
  attr_reader :struct_name
  attr_reader :root_mapping
  def initialize(struct_name)
    @struct_name = struct_name
    @root_mapping = nil
  end

  def start_document(version, tag_directives, implicit)
    if (!@root_mapping)
      root_tag = "!ruby/struct:#{struct_name}"
      @root_mapping = StructMapping.new(nil, root_tag, implicit, BLOCK,
                                        self)
    end

    super

    if (@root_mapping)
      ## NB this will result in a parse tree
      ## such that, if the parse tree is
      ## written back YAML, will not be
      ## equivalent to the original text.
      ##
      ## The output would have the struct
      ## description in @root_mapping added,
      ## with the original document in effect
      ## contained within that struct mapping

      ## NB after the next call, any immediately subsequent
      ## calls to #scalar should add fields and field values
      ## to the @root_mapping
      self.send(:push,@root_mapping)
    end
  end

  def end_document(implicit_end = !streaming?)
    @root_mapping.finalize
    super
  end
end


=begin

P = Struct.new(:name)

sbuilder = StructTreeBuilder.new
parser =  Psych::Parser.new(sbuilder)
out_1 = parser.parse("--- !ruby/struct:P\nname: Project 01\n")

# out_1.handler.structs.each do |stmap|
# desc = stmap.struct_desc
# ## now initialize a struct from desc .. (FIXME)
# end

## FIXME have to reinitialize the parser,
## or it will keep adding struct descs ..

out_2 = parser.parse("--- !ruby/struct:POther\nname: Project 02\n")
## ^ NB worked.

out_2.handler.structs



=end
