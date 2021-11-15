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
end

class StructInstanceDesc < StructDesc
  def initialize(struct_name = nil, field_values = nil)
    if field_values ## assuming: hash table
      super(struct_name, field_values.keys)
    else
      super(struct_name, nil)
    end
    @field_values = field_values
  end

  def add_field_value(name, val)
    add_field(name)
    if @field_values
      @field_values[name]=val
    else
      @field_values={ name => val }
    end
  end
end

## ...

class StructMapping < Psych::Nodes::Mapping
  attr_reader :struct_desc
  attr_reader :last_field
  attr_reader :builder

  def initialize(anchor = nil, tag = nil,
                 implicit = true, style = BLOCK,
                 builder = nil)
    ## FIXME for back-reference to existing struct/instance descs,
    ## need to store the active tree builder here,
    ## e.g via an additional arg 'builder'
    @builder = builder

    if ( s_name = StructDesc.name_from_tag(tag) )
      ## FISXME test for the s_name = false case,
      ## per StructDesc.name_from_tag
      ## && TBD YAML encoding for an anonymous struct
      desc = StructInstanceDesc.new(s_name)
      @struct_desc = desc
    end
    super(anchor,tag,implicit,style)
  end

  def push_field(name)
    @last_field = @struct_desc.add_field(name)
  end

  def push_field_value(value)
    @struct_desc.add_field_value(@last_field, value)
  end

  def finalize()
    ## FIXME err if @struct_desc is nil ...
    @struct_desc.finalize
  end
end


class StructTreeBuilder <  Psych::TreeBuilder
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

  def start_mapping(anchor, tag, implicit, style)
    ## NB if tag matches "!ruby/struct:",
    ## create a new StructDesc for the name
    ## provided in the tag value i.e after
    ## the delimiting colon
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
      super
  end

  def scalar (value, anchor, tag, plain, quoted, style)
      if @last.instance_of?(StructMapping)
        if @field_read
          @last.push_field_value(value)
          @field_read=nil
        else
          @field_read = @last.push_field(value) ## name, here
        end
      else
        super
      end
  end
end

=begin

P = Struct.new(:name)

sbuilder = StructTreeBuilder.new
parser =  Psych::Parser.new(sbuilder)
out_1 = parser.parse("--- !ruby/struct:P\nname: Project 01\n")

out_1.handler.structs.each do |stmap|
desc = stmap.struct_desc
## now initialize a struct from desc .. (FIXME)
end

## FIXME have to reinitialize the parser,
## or it will keep adding struct descs ..

out_2 = parser.parse("--- !ruby/struct:POther\nname: Project 02\n")
## ^ NB worked.

out_2.handler.structs


## that all parsed correctly, but what is it now
## about the implicit_end= failure again?


=end
