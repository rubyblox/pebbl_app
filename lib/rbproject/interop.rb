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

## common class for field router and field bridge classes
class ClassBridge
  attr_reader :internal_class
  attr_reader :external_class

  def initialize(internal_class, external_class)
    @internal_class = internal_class
    @external_class = external_class
  end
end


## trivial mapping class for object interoperability
class FieldRouter < ClassBridge
  attr_reader :field_map

  def initialize(internal_class, external_class)
    super(internal_class, external_class)
    @field_map=Hash.new() do |h,name|
      raise "No field mapping found for #{name}"
    end
  end

  ## @param field [Symbol] field name for the bridge instance
  ## @param bridge_class [Class] class for the bridge instance
  ## @param args [any] initialization arguments for the bridg einstance
  def add_bridge(field, bridge_class, **args)
    inst = bridge_class.new(field, @internal_class, @external_class, **args)
    field_map[field]=inst
    return inst
  end

  ## locate an FieldBridge for this FieldRouter by field name
  ##
  ## @param field [Symbol] field name
  def find_bridge(field)
    return field_map[field.to_sym]
  end

  ## import a single field from an external object to an internal object
  ##
  ## @param field [Symbol] field name
  ## @param ext_inst [Object] an instance of the #external_class
  ## @param int_inst [Object] an instance of the #internal_class
  ## @see #import_mapped
  def import(field, ext_inst, int_inst)
    bridge = find_bridge(field)
    bridge.import(ext_inst,int_inst)
  end

  ## export a single field from an internal object to an external object
  ##
  ## @param field [Symbol] field name
  ## @param int_inst [Object] an instance of the #internal_class
  ## @param ext_inst [Object] an instance of the #external_class
  ## @see #export_mapped
  def export(field, int_inst, ext_inst)
    bridge = find_bridge(field)
    bridge.export(int_inst,ext_inst)
  end

  ## import all mapped fields from an external instance to an internal
  ## instance
  ##
  ## @param ext_inst [Object] an instance of the #external_class
  ## @param int_inst [Object] an instance of the #internal_class
  ## @see #import
  def import_mapped(ext_inst,int_inst)
    @field_map.each do |field,bridge|
      bridge.import(ext_inst,int_inst)
    end
  end

  ## export all mapped fields from an internal instance to an external
  ## instance
  ##
  ## @param int_inst [Object] an instance of the #internal_class
  ## @param ext_inst [Object] an instance of the #external_class
  ## @see #export
  def export_mapped(int_inst,ext_inst)
    @field_map.each do |field,bridge|
      bridge.export(int_inst,ext_inst)
        end
  end
end


class HashFieldRouter < FieldRouter
  def import_mapped(h,int_inst)
    ## NB This would not address 'include' objects in a mapping
    h.each do |k,v|
      name = k.to_sym
      bridge = self.find_bridge(name)
      if (bridge)
        bridge.import_value(v,int_inst)
      else
        if block_given?
          ## e.g add to Proj#extra_conf_data
          ## FIXME needs illustration in test
          yield(k,v)
        else
          raise "No mapping found for #{k} in #{self} and no
block provided"
        end
      end
    end
  end


  def export_mapped(int_inst,h)
    ## NB this would export values in the field order
    ## in which @field_map is defined
    @field_map.each do |field,bridge|
      # exp_name=self.name_for_export(field)
      if bridge.value_in?(int_inst)
        value = bridge.get_internal(int_inst)
        ## FIXME this departs from other FieldBridge
        ## implementations in that it assumes that
        ## no value is bound for the field name in the
        ## hash. This does not iterate to add values,
        ## for any sequence or map value from the
        ## internal instance
        bridge.set_external(h,value)
      end
    end
  end
end

## method-oriented field bridge for principally scalar mappings
class FieldBridge < ClassBridge
  ## NB illustration in interop.rspec
  attr_reader :internal_getter ## for #export
  attr_reader :internal_setter ## for #import

  attr_reader :external_getter ## for #import
  attr_reader :external_setter ## for #export

  attr_reader :name

  def initialize(name, internal_class, external_class,
                 internal_getter: name,
                 internal_setter: true,
                 external_getter: nil,
                 external_setter: nil)
    super(internal_class,external_class)
    @name = name
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

  alias :import_value :set_internal

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

  def value_in?(internal_inst)
    return true
  end
end


## common mixin module for interop bridge types utilizing an
## instance variable for internal field storage
module VarFieldBridgeMixin
  def self.included(extclass)
    extclass.attr_reader :instance_var

    def initialize(name, internal_class, external_class,
                   instance_var: ("@" + name.to_s).to_sym,
                   external_getter: nil,
                   external_setter: nil)
      super(name, internal_class, external_class,
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
    ## NB one key part of API behaviors with this class:
    ## This does not export a value if no value is bound for the
    ## internal field's instance variable
    if value_in?(internal_inst)
      super
    else
      return false
    end
  end
end


## *FieldBridge* utilizing an instance variable semantics
class VarFieldBridge < FieldBridge
  ## NB reimpl of a FieldDesc
  include VarFieldBridgeMixin
end


module FieldHBridgeMixin
  def name_for_export()
    ## NB using symbols in external hash keys, for application
    ## data. For purpose of interoperability, the keys can be
    ## translated to or from string values, during export or
    ## import onto any strongly typed syntax e.g with YAML
    ##
    ## if needed, this method can be overridden in
    ## any subclass
    return @name
  end

  def value_ext?(external_inst)
    external_inst.key?(self.name_for_export())
  end

  def set_external(external_inst, value)
    name = self.name_for_export()
    external_inst[name]=value
  end

  def get_external(external_inst, default=false)
    name = self.name_for_export()
    if external_inst.key?(name)
      external_inst[name]
    else
      ## NB providing block args similar to a default proc
      ## for a Hash
      yield(external_inst,name) if block_given?
      return default
    end
  end
end

## *FieldBridge* type for field name and value export to a *Hash*
class FieldHBridge < FieldBridge
  include FieldHBridgeMixin
end

class VarFieldHBridge < FieldHBridge
  ## FIXME this class naming convention is unwieldy,
  ## though descriptive
  ##
  ## FIXME soon ...
  ## class SeqFieldHBridge ##...
  ## class SeqVarFieldHBridge ##...
  ## class MappingFieldHBridge ##...
  ## class MappingVarFieldHBridge ##...
  include VarFieldBridgeMixin
end

## common class for *FieldBridge* mappings utilizing
## enumerable values for internal and external field
## storage
class EnumFieldBridge < FieldBridge
  def import_enum(external_inst, internal_inst)
    v = get_external(external_inst).dup
    set_internal(internal_inst, v)
  end

  def export_enum(internal_inst, external_inst)
    v = get_internal(internal_inst).dup
    set_external(external_inst, v)
  end
end


## *FieldBridge* for mappings utilizing an Array-like value for internal
## and external field storage
class SeqFieldBridge < EnumFieldBridge
  def add_internal(internal_inst, value)
    get_internal(internal_inst).push(value)
  end

  def add_external(external_inst, value)
    get_external(external_inst).push(value)
  end

  def import_value(value,internal_inst)
    ## NB appends - does not reset the internal value before
    ## importing each element
    ##
    ## FIXME use this under hash subclasses
    value.each do |elt|
      add_internal(internal_inst, elt)
    end
  end

  def import_each(external_inst, internal_inst)
    get_external(external_inst).each do |elt|
      add_internal(internal_inst,elt)
    end
  end
  alias :import :import_each

  def export_each(internal_inst, external_inst)
    get_internal(internal_inst).each do |elt|
      add_external(external_inst,elt)
    end
  end
  alias :export :export_each
end

## *FieldBridge* type for mappings utilizing an Array-like value
##  under an instance variable for internal field storage
class SeqVarFieldBridge < SeqFieldBridge
  include VarFieldBridgeMixin
end

## *FieldBridge* type for mappings utilizing a Hash-like value for
## internal and external field storage
class MappingFieldBridge < EnumFieldBridge
  def add_internal(internal_inst, key, value)
    get_internal(internal_inst)[key] = value
  end

  def add_external(external_inst, key, value)
    get_external(external_inst)[key] = value
  end

  def import_value(value,internal_inst)
    ## NB appends - does not reset the internal value before
    ## importing each key, value pair
    ##
    ## FIXME use this under hash subclasses
    value.each do |k,v|
      add_internal(internal_inst, k, v)
    end
  end

  def import_each(external_inst, internal_inst)
    get_external(external_inst).each do |k,v|
      add_internal(internal_inst,k,v)
    end
  end
  alias :import :import_each

  def export_each(internal_inst, external_inst)
    get_internal(internal_inst).each do |k,v|
      add_external(external_inst,k,v)
    end
  end
  alias :export :export_each
end

## *FieldBridge* type for mappings utilizing a Hash-like value
##  under an instance variable for internal field storage
class MappingVarFieldBridge < MappingFieldBridge
  include VarFieldBridgeMixin
end


# Local Variables:
# fill-column: 65
# End:
