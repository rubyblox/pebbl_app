require('psych')

require('set')

class StructDesc
  attr_reader :struct_name  ## String or nil
  attr_reader :fieldset ## Set
  attr_reader :finalized

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
  ## TBD integrating this with the following
  attr_reader :struct_desc
  attr_reader :last_field
  def initialize(anchor = nil, tag = nil,
                 implicit = true, style = BLOCK)
    puts("DEBUG StructMapping tag #{tag}")
    if (tag && tag.match?('^!ruby/struct:'))
      off = tag.index(':')
      puts("DEBUG off #{off}")
      if ( off && ( off < tag.length ) )
        s_name = tag.slice(1+off..)
        puts("DEBUG s_name #{s_name}")
        desc = StructInstanceDesc.new(s_name)
        @struct_desc = desc
      end
    end
    super
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
      ## FIXME needs a backref onto the src
      ## 1) StructMapping.new(...)
      mapping = StructMapping.new(anchor,tag,implicit,style)
      structs << mapping
      ## 2) push ??
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
