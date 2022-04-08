## fieldclass.rb

## TBD optional interop with rbs (??) because ... what support?

class FieldStorage
  class << self
    def kind()
      return self::STORAGE_KIND
    end
  end

  attr_reader :name, :field

  def initialize(name, field)
    @name = name.to_sym
    @field = field
  end

  def validate_instance(instance)
    cls = self.field.in_class()
    if instance.is_a?(cls)
      return cls
    else
      raise ArgumentError.new(
        "Object is not a %p: %p:" % [cls, instance]
      )
    end
  end

  def make_reader_lambda(cls)
    storage = self
    ## NB 'self' at time/scope of call:
    lambda { || storage.get_value(self) }
  end

  def make_writer_lambda(cls)
    storage = self
    lambda { |value| storage.set_value(self, value) }
  end

end

class FieldInstanceStorage < FieldStorage
  STORAGE_KIND ||= :field

  attr_reader :variable

  def initialize(name, field, variable: nil, **otheropts)
    super(name, field)
    if variable
      use_ivar = variable.to_s
    else
      use_ivar = name.to_s
    end
    ## FIXME frozen string literals => true :: usage/testing
    pfx = "@".freeze
    unless(use_ivar[0] == pfx)
      use_ivar = pfx + use_ivar
    end
    @variable = use_ivar.to_sym
  end

  def bound?(instance)
    validate_instance(instance)
    instance.instance_variable_defined?(@variable)
  end

  def get_value(instance)
    validate_instance(instance)
    ## NB a subclass may opt to err if the variable is unbound,
    ## before calling this method in its superclass
    instance.instance_variable_get(@variable)
  end

  def set_value(instance, value)
    validate_instance(instance)
    ## NB a subclass may opt to err if the variable is already bound,
    ## before calling super()
    instance.instance_variable_set(@variable, value)
  end

end

class FieldMethodStorage < FieldStorage
  ## NB specifically for instance method fields, this impl
  STORAGE_KIND ||= :method
  attr_reader :method

  def self.default_writer_name(rdr_name)
    return (rdr_name.to_s + "=").to_sym
  end

  def self.get_impl_method(name)
    cls = field.in_class
    begin
      cls.instance_method(method.to_sym)
    rescue NameError
      raise new ArgumentError(
        "No instance method %p found in %s" % [name, cls]
      )
    end
  end

  def initialize(name, field, reader_name: name,
                 writer_name: self.class.default_writer_name(reader_method),
                 **otheropts)
    ## NB the reader_name/writer_name here would not be in the same
    ## scope as any method onto a FieldInfo object
    super(name, field)
    @reader_method = self.class.get_impl_method(reader_name)
    @writer_method = self.class.get_impl_method(writer_name)
  end

  def bound?(instance)
    validate_instance(instance)
    ## returns a truthy but ambiguous value, appropriate for the
    ## definition of a field onto a method, such that the method's
    ## internal structure may not be known to the implementation
    return 0
  end

  def get_value(instance)
    validate_instance(instance)
    ## FIXME assumes an unbound instance method
    @reader_method.bind_call(instance)
  end

  def set_value(instance, value)
    validate_instance(instance)
    ## FIXME assumes an unbound instance method
    @writer_method.bind_call(instance, value)
  end
end

class FieldConstantStorage < FieldStorage
  STORAGE_KIND ||= :constant

  attr_reader :constant

  def initialize(name, field, constant: name, **otheropts)
    super(name, field)
    @constant = constant.to_sym
  end

  def bound?(instance)
    validate_instance(instance)
    self.field.in_class.const_defined?(@constant)
  end

  def get_value(instance)
    validate_instance(instance)
    ## NB implementation decision - while a constant is presumably
    ## constant for some duration of time, yet in considering that
    ## the Ruby language allows for redefining clases and rebinding
    ## constants, this method will access the constant for each
    ## call, using the original class provided to the field definition
    ## for this field storage object
    ##
    ## Applications may ensure that the field definitions for a class
    ## are updated, e.g by ensuring that the source forms defining those
    ## field definitions are loaded again when the class definition is
    ## updated
    self.field.in_class.const_get(@constant)
  end

  def set_value(instance, value)
    ## NB implementation decision - see remarks under #for
    validate_instance(instance)
    self.field.in_class.const_set(@constant, value)
  end

end

class FieldBindingStorage < FieldStorage
  STORAGE_KIND ||= :binding
  ## TBD how to integrate a block into a class and fields, with this,
  ## extentional to local binding storage

  ## TBD usage cases, any tangible application

  attr_reader :binding

  def initialize(name, field, **otheropts)
    super(name, field)

    ## TBD default impl - using name as a local variable name
    ## onto an arbitrary instance-specific binding,
    ## or a class field-specific binding,
    ## or "other binding"
    ##
    ## e.g application: binding for field storage onto a thread's block
    ## (would also need concurrency support, e.g with a mutex/CV
    ## architecture onto some variable in binding.local_variables,
    ## assuming the Ruby impl has not provided a common R/W mutex)
    ## @binding = bdg
  end

  ## TBD other methods
  # def get_value(instance)
  #   bdg = field.binding_for(instance)
  #   bdg.local_variable_get(self.name)
  # end

end

class FieldInfo
  STORAGE_KINDS = [[:instance, FieldInstanceStorage],
                   [:method, FieldMethodStorage],
                   [:constant, FieldConstantStorage] # ,
                   # [:binding, FieldBindingStorage]
                  ].freeze

  attr_reader :name, :in_class, :type, :storage, :reader, :writer

  def self.find_storage_class(kind)
    found = false
    use_kind = kind.to_sym
    catch :found do
      STORAGE_KINDS.each { |elt|
        if (elt[0] == use_kind)
          found = elt[1]
          throw :found
        end
      }
    end
    if found
      return found
    else
      raise ArgumentError.new(
        "No field class found for kind %p in %s" % [use_kind, self]
      )
    end
  end


  def initialize(name, in_class, type: Object, storage: nil,
                 reader: nil, writer: nil, **otheropts)
    @name = name
    @in_class = in_class
    @type = type

    empty = "".freeze
    eq = "=".freeze

    scls = nil
    storage_opts = {}.freeze

    ## TBD compute default field storage options from this instance's class?

    case storage
    when FieldStorage
      use_storage = storage
    when nil
      ## NB default field storage class:
      scls = self.class.find_storage_class(:instance)
    when Symbol
      scls = self.class.find_storage_class(storage)
    when String
      scls = self.class.find_storage_class(storage.to_sym)
    when Class
      scls = storage
    when Array
      ## FIXME needs illustration
      ##
      ## NB rudimentary field storage class selection
      ## and field storage option pass-through here
      scls = storage[0]
      storage_opts = storage[1..]
    else
      raise ArgumentError.new(
        "initializing %s: Unknown field storage specifier: %p" % [
          self, storage
        ])
    end
    use_storage ||= scls.new(name, self, **storage_opts)

    @storage = use_storage

    if reader
      if reader.eql?(true)
        rdr_pfx = (otheropts[:reader_prefix] || empty)
        rdr_sfx = (otheropts[:reader_suffix]  || empty)
        @reader = (rdr_pfx.to_s + name.to_s + rdr_sfx.to_s).to_sym
      else
        @reader = reader.to_sym
      end
    end

    if writer
      if writer.eql?(true)
        wr_pfx = (otheropts[:writer_prefix] || empty)
        wr_sfx = (otheropts[:writer_suffix]  || eq)
        @writer = (wr_pfx.to_s + name.to_s + wr_sfx.to_s).to_sym
      else
        @writer = writer.to_sym
      end
    end
  end


  def initialize_field()
    if (cls = @in_class)
      # @storage.initialize_storage
      if (rdr = @reader)
        proc = @storage.make_reader_lambda(cls)
        cls.define_method(rdr, &proc)
      end
      if (wrt = @writer)
        proc = @storage.make_writer_lambda(cls)
        cls.define_method(wrt, &proc)
      end
      cls
    else
      raise "Cannot initialize field, no class bound: #{self}"
    end
  end

  def read?
    true if @reader
  end

  def write?
    true if @writer
  end
end



module FieldProvider
  def self.extended(extclass)

    ## FIXME optomize reader methods, below, for a frozen class
    ##
    ## FIXME detect and err on a frozen class, in methods below
    ## that modify the instance variable on the class

    def extclass.field_default_options()
      @field_default_options ||=
        {metaclass: FieldInfo}
    end

    def extclass.fields_clear()
      seq = self.field_info
      seq.delete_if { true }
    end

    def extclass.field_remove(name)
      use_name = name.to_sym
      self.field_info.delete_if { |info| info.name.eql?(use_name) }
    end

    def extclass.fields_config(**options)
      whence = self.field_default_options
      options.each { |k, v|
        whence[k] = v
      }
      whence
    end

    def extclass.fields_clear_config()
      opts = self.field_default_options
      opts.delete_if { true }
      opts[:metaclass] = FieldInfo
    end


    def extclass.read_fields()
      if @field_info
        readable = []
        @field_info.each { |f|
          readable.push(f.name) if f.read?
        }
        readable
      end
    end

    def extclass.write_fields()
      if @field_info
        writable = []
        @field_info.each { |f|
          writable.push(f.name) if f.write?
        }
        writable
      end
    end

    def extclass.fields()
      ## FIXME support a matching syntax similar to field_info here,
      ## rather implementing the same here
      self.field_info.map { |f| f.name } if @field_info
    end

    def extclass.field_info(name = nil)
      info = (@field_info ||= [])
      case name
      when nil
          info
      when Symbol
        info.find { |inf| inf.name == name }
      when String
        field_info(name.to_sym)
      when Regexp
        ## FIXME finds only the first matching instance
        info.find { |inf| inf.name.grep(name) }
      end
    end

    def extclass.field_type(name = nil)
      ## NB per field_info, 'name' may also be a regexp,
      ## in which case (FIXME) this could return an array
      ## but presently (FIXME) would return only the first match
      inf = field_info(name)
      inf.type
    end

    def extclass.field_read?(name)
      info = field_info()
      it = info.find { |inf| inf.name == name }
      if it
        it.read?
      else
        raise ArgumentError.new("No field #{name} found in #{self}")
      end
    end

    def extclass.field_write?(name)
      info = field_info()
      it = info.find { |inf| inf.name == name }
      if it
        it.write?
      else
        raise ArgumentError.new("No field #{name} found in #{self}")
      end
    end

    def extclass.field?(name)
      use_name = name.to_sym
      true if @field_info.find{ |info| info.name.eql?(use_name) }
    end

    def extclass.field(*descs)
      ## FIXME points of call here:
      ##  this.field (*names_and_options_
      ##  FieldInfo.new
      ##   ^ FIXME this is where the FieldStorage instance is being initialized
      ##  FieldStorage.new & subclass methods on same
      ##  FieldInfo#initialize_field
      @field_info ||= []
      names = []
      base_options = self.field_default_options
      options = base_options.dup
      name = nil
      descs.each { |desc|
        case desc
        when Symbol
          name = desc
        when String
          name = desc.to_sym
        when Hash
          options = base_options.dup
          desc.each { |k, v|
            options[k] = v
          }
        end

        if name
          if options[:in_class]
            raise ArgumentError.new("at #{name}: Not a valid field option: :in_class")
          elsif ((exists = self.field?(name)) && ! (exists.eql?(self)))
            raise ArgumentError.new("A field is already defined for name #{name}")
          else
            info_cls = ( options[:metaclass] ||
                    field_default_options[:metaclass] ||
                    FieldInfo )
            ## ensure that the :metaclass option is not passed through
            ## to the field info initialization
            options.delete(:metaclass)
            ## TBD method binding here, onto the field info & field storge object stored via here
            info = info_cls.new(name, self, **options)
            info.initialize_field
            @field_info.push(info)
            names.push(name)
            name = nil
          end
        end
      }
      names
    end

  end
end

class FieldTest
  extend FieldProvider

  # fields_init(read: true, write: true, type: String)

  fields_clear
  fields_clear_config
  fields_config(reader: true, writer: true, type: String)
  field(:a, :b, :c)

  field({type: String}, :d)

  field({type: Array(String)}, :e)

  field({type: Hash(Symbol => Object)}, :f)
end

## ----

# require_relative('./yamlclass')

