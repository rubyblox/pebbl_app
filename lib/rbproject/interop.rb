## interop.rb - trivial object interoperability API

class UnboundField < RuntimeError
  attr_reader :field
  attr_reader :instance

  def initialize(field, instance,
                 message: "Unbound field #{field} in #{instance}")
    super(message)
    @field = field
    @instance = instance
  end

end

class InterShim
  attr_reader :internal_class
  attr_reader :external_class

  def initialize(internal_class, external_class)
    @internal_class = internal_class
    @external_class = external_class
  end
end

## FIXME partial illustration of API (Prototype)

class InterRouter < InterShim ## TBD ...
  ## NB first implement, test field-local InterBridge classes

  attr_reader :import_table
  attr_reader :export_table

  def add_import_bridge(tbd)

  end

  def find_import_bridge(field)
  end

  def add_export_bridge(tbd)

  end

  def find_export_bridge(field)

  end
end

##
## ...
##

class InterBridge < InterShim
  ## NB illustration in interop.rspec

  attr_reader :internal_getter ## for #export
  attr_reader :internal_setter ## for #import

  attr_reader :external_getter ## for #import
  attr_reader :external_setter ## for #export

  def initialize(internal_class, external_class,
                 internal_getter: nil,
                 internal_setter: nil,
                 external_getter: nil,
                 external_setter: nil)
    super(internal_class, external_class)
    internal_getter && ( @internal_getter = internal_getter)
    if (internal_setter == true) && internal_getter
      @internal_setter = (internal_getter.to_s + "=").to_sym
    elsif internal_setter
      @internal_setter = internal_setter
    end
    external_getter && ( @external_getter = external_getter)
    if (external_setter == true) && external_getter
      @external_setter = (external_getter.to_s + "=").to_sym
    elsif external_setter
      @external_setter = external_setter
    end
 end


  def self.def_instance_reader(name, inst_var)
    define_method(name) { |instance|
      if self.instance_variable_defined?(inst_var)
        name = self.instance_variable_get(inst_var)
        instance.send(name)
      else
        raise UnboundField.new(inst_var.to_s[1..].to_sym, self)
      end
    }
  end


  def self.def_instance_writer(name, inst_var)
    define_method(name) { |instance, value|
      if self.instance_variable_defined?(inst_var)
        name = self.instance_variable_get(inst_var)
        instance.send(name, value)
      else
        raise UnboundField.new(inst_var.to_s[1..].to_sym, self)
      end
    }
  end

  # def get_internal(internal_inst)
  #   if self.instance_variable_defined?(:@internal_getter)
  #     internal_inst.send(@internal_getter)
  #   else
  #     raise "No internal_getter defined in #{self}"
  #   end
  # end
  ## alternately, see following

  ## NB the call wrapping provided here - repetitive
  ## as it would be to implement directly - it may serve
  ## to prevent reference under any nil/unbound value of
  ## each @<internal|external>_<getter|setter> variable
  def_instance_reader(:get_internal,:@internal_getter)
  def_instance_reader(:get_external,:@external_getter)

  def_instance_writer(:set_internal,:@internal_setter)
  def_instance_writer(:set_external,:@external_setter)

  ## ^ NB internal_* methods will be overridden
  ## under field-based subclasses

  def import(external_inst,internal_inst)
    v = get_external(external_inst)
    set_internal(internal_inst,v)
  end

  def export(internal_inst,external_inst)
    v = get_internal(internal_inst)
    set_external(external_inst, v)
  end
end


module FieldInterBridgeMixin
  def self.included(extclass)
    extclass.attr_reader :instance_var

    def initialize(internal_class, external_class,
                   instance_var,
                   external_getter: nil,
                   external_setter: nil)
      ## NB it is notably unwieldy, in this part
      super(internal_class, external_class,
            external_getter: external_getter,
            external_setter: external_setter)
      @instance_var = instance_var
    end
  end

  def value_in?(internal_inst)
    internal_inst.instance_variable_defined?(@instance_var)
  end

  def get_internal(internal_inst, default=false)
    if value_in?(internal_inst)
      internal_inst.instance_variable_get(@instance_var)
    else
      return default
    end
  end

  def set_internal(internal_inst, value)
    internal_inst.instance_variable_set(@instance_var, value)
  end

  def export(internal_inst, external_inst)
    ## NB one key part of the API behaviors with this class:
    ## This does not export a value if no value is bound for the
    ## internal field's instance variable
    if value_in?(internal_inst)
      super
    else
      return false
    end
  end
end


class FieldInterBridge < InterBridge
  ## NB reimpl of a FieldDesc

  ## TBD may be reimplemented as a mixin module
  ## - FIXME test first as a direct class definition

  ## FIXME instance variables internal_getter, internal_setter
  ## - from the superclass - are redundant here

  include FieldInterBridgeMixin
end

## NB the following more or less depart from a field-based
## semantics, more towards a sense of value cells in an
## arbitrary enumerable object

class EnumInterBridge < InterBridge
  ## NB here and in subclasses, the respective
  ## getter/setter methods would serve to retireve
  ## or set the value of the entire enumerable under
  ## storage

  def import_enum(external_inst, internal_inst)
    v = get_external(external_inst).dup
    set_internal(internal_inst, v)
  end

  def export_enum(internal_inst, external_inst)
    v = get_internal(internal_inst).dup
    set_external(external_inst, v)
  end
end

class SeqInterBridge < EnumInterBridge

  def add_internal(internal_inst, value)
    get_internal(internal_inst).push(value)
  end

  def add_external(external_inst, value)
    get_external(external_inst).push(value)
  end

  def import_each(external_inst,internal_inst)
    get_external(external_inst).each do |elt|
      add_internal(internal_inst,elt)
    end
  end
  alias :import :import_each

  def export_each(internal_inst,external_inst)
    get_internal(internal_inst).each do |elt|
      add_external(external_inst,elt)
    end
  end
  alias :export :export_each
end


class SeqFieldInterBridge < SeqInterBridge
  include FieldInterBridgeMixin
end



class MappingInterBridge < EnumInterBridge

  def add_internal(internal_inst, key, value)
    get_internal(internal_inst)[key] = value
  end

  def add_external(external_inst, key, value)
    get_external(external_inst)[key] = value
  end

  def import_each(external_inst,internal_inst)
    get_external(external_inst).each do |k,v|
      add_internal(internal_inst,k,v)
    end
  end
  alias :import :import_each

  def export_each(internal_inst,external_inst)
    get_internal(internal_inst).each do |k,v|
      add_external(external_inst,k,v)
    end
  end
  alias :export :export_each
end


class MappingFieldInterBridge < MappingInterBridge
  include FieldInterBridgeMixin
end
