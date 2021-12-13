## interop.rb - trivial object interoperability API

=begin rdoc

## Introduction

The FieldBroker API provides support for object data interchange
with a generally field-oriented approach to object data.

Using the *FieldBroker* class as representative of a mapping for
an _internal_ and _external class_, with any number of
*FieldBridge* classes as representative of interoprable fields in
each of the internal and external class, an application can
provide support for effective _import_ or _export_ of scalar,
array, and hash data across individual object implementations.

This API provides suport for _import_ and _export_ of object data
across subclasses of *Object*. Support is provided, furthermore,
for _import_ and _export_ of object data between any internal
subclass of *Object* and an external *Hash* type.

## Concepts

* *Field* : A property of an object generally represented with
  at least one of a read accessor, write accesssor, and/or
  instance variable, such that a field may hold a generally
  _scalar_-, _array_-, or _hash_-like value, A field may or may
  not be implemented with a one-to-one mapping onto an instance
  variable in a Ruby class.

* *Field Bridge* : An object that provides support for _import_
   and _export_ of data onto a _field_. A field bridge may be
   defined for any single _field_  such that may be represented
   compatibly within instances of an _internal class_ and
   instances of a corresponding _external class_.

* *Field Broker* : An object providing storage and access onto
   any number of _field bridge_ definitions, for a single set of
   an _internal class_ and an _external class_.


## API - Notes

A _field broker_ provides the methods *#import_mapped* and
*#export_mapped*, such that may be called for interchange of
data for all field bridge definitions in the field broker.

The _field broker_ methods *#import* and *#export* are available
for individual field bridge definitions initialized to a field
broker.

## Field Bridge Kinds

The field bridge classes provided in this API may be
represented, each, within a number of categories, as dependent
on general functionality.

With regards to instance variable access for any instance of the
_internal class_ to a field broker, field bridge implementations
may be categorized as follows:

* field bridge implementations using generally method-oriented
  access to the internal instance

* field bridge implementations using an instance variable for
  field data storage in the internal instance. These field bridge
  classes are generally named with a prefix, "Var"

With regards to interoperability across object systems,
individual field bridge classes are provided for:

* interchange between any internal subclass of object and any
  external subclass of object

* interchange between any internal subclass of object and a
  generally Hash-based field mapping, externally. These field
  bridge claasses are generally named with a suffix, "HBridge"

With regards to the type of data accessed in any single field
bridge, field bridge classes may be categorized generally per
_scalar_, _sequence_ i.e _array-like_, and _mapping_ i.e
generally _hash-like_ field values. In the following API, this
characteristic may be interpolated from the namespace in which
each field bridge class has been defiend.

In the following API, the field bridge classes are each defined
within a distinct namespace corresponding to the type of data
accessed in each field bridge. Other characteristics of each
field bridge implementation may be interpolated genmerally from
the class name within each namespace.

* **FieldBridge:** Message-oriented, method-based value access
  for both internal and external instances

* **VarFieldBridge:** Internal value storage within an instance
  variable, for external value storage with a method-based API

* **FieldHBridge:** FieldBridge for export to a hash map

* **VarFieldHBridge:** VarFieldBridge for export to a hash map

This API provides the following *FieldBridge* classes for
application in a *FieldBroker*:

* Scalar field value access, in the
  *FieldBroker::Bridge* namespace
  - FieldBroker::Bridge::FieldBridge
  - FieldBroker::Bridge::VarFieldBridge
  - FieldBroker::Bridge::FieldHBridge
  - FieldBroker::Bridge::VarFieldHBridge

* Array-like field value access, in the
  *FieldBroker::Bridge::Seq* namespace
  - FieldBroker::Bridge::Seq::FieldBridge
  - FieldBroker::Bridge::Seq::VarFieldBridge
  - FieldBroker::Bridge::Seq::FieldHBridge
  - FieldBroker::Bridge::Seq::VarFieldHBridge

* Hash-like field value access, in the
  *FieldBroker::Bridge::Map* namespace
  - FieldBroker::Bridge::Map::FieldBridge
  - FieldBroker::Bridge::Map::VarFieldBridge
  - FieldBroker::Bridge::Map::FieldHBridge
  - FieldBroker::Bridge::Map::VarFieldHBridge

## Examples

(TBD)

Examples of the general functionality of the FieldBroker API may
be available in +interop.rspec+.

## History

This API was developed originally in relation to a set of
extensions onto the Psych API for YAML.

Additional features have been added to the API, in an interest of
general portability.

=end
module FieldBroker

class FieldError < RuntimeError
  attr_reader :field
  def initialize(field, message)
    super(message)
    @field = field
  end
end

class FieldBridgeNotFound < FieldError
  attr_reader :context
  def initialize(field, context,
                 message = "found no field bridge for #{field} in #{context}")
    super(field, message)
    @context = context
  end
end

class UnboundField < FieldError
  attr_reader :instance
  def initialize(field, instance,
                 message: "Unbound field #{field} in #{instance}")
    super(field, message)
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
class FieldBroker < ClassBridge
  attr_reader :field_map
  attr_reader :ext_field_map

  def initialize(internal_class, external_class)
    super(internal_class, external_class)
    @field_map=Hash.new() do |h, name|
      raise FieldBridgeNotFound.new(name, self)
    end
    @ext_field_map=Hash.new() do |h, name|
      msg = "Found no field bridge for external field #{name} in #{self}"
      raise FieldBridgeNotFound.new(name, self, msg)
    end
  end

  ## @param field [Symbol] field name for the bridge instance
  ## @param bridge_class [Class] class for the bridge instance
  ## @param args [any] initialization arguments for the bridge
  ## instance
  ##
  ## FIXME needs test
  def add_bridge(field, bridge_class, **args)
    ## TBD this could be provided for a more succinct syntax,
    ## not requiring a class name - dispatchintg on
    ## A) when the FieldBroker itself is e.g
    ##    a FieldBroker or an HFieldBroker =>
    ##    => only the *HBridge classes would apply
    ## B) if an instance variable is directly provided
    ##     e.g with :instance_var <name>
    ##    or indirectly implied e.g with :instance_var true
    ##    => only the Var* classes would apply
    ## C) If a :kind parameter is provided onto
    ##    [:scalar,:seq,:map] then a class from the
    ##    respective namespace can be selected
    inst = bridge_class.new(field, @internal_class, @external_class, **args)
    @field_map[field]=inst
    ext_name=args[:external_name]
    @ext_field_map[ext_name]=inst
    return inst
  end

  ## locate a FieldBridge for this FieldBroker by internal field
  ## name .
  ##
  ## If a block is provided in the call, the block will be
  ## invoked with +self+ and the provided +field+, as when no
  ## FieldBridge can be found for the provided field name.
  ##
  ## @param field [Symbol] field name
  ## @param default [any] value to return, if no matching field
  ##  bridge can be found in this instance
  def find_bridge(field, default=false)
    name = field.to_sym
    if field_map.key?(name)
      return field_map[name]
    else
      yield(self, field) if block_given?
      return default
    end
  end


  ## locate a FieldBridge for this FieldBroker by external field
  ## name.
  ##
  ## If a block is provided in the call, the block will be
  ## invoked with +self+ and the provided +field+, as when no
  ## FieldBridge can be found for the provided external field
  ## name.
  ##
  ## @param ext_field [Symbol] field name
  ## @param default [any] value to return, if no matching field
  ##  bridge can be found in this instance
  def find_bridge_external(ext_field, default=false)
    name = ext_field.to_sym
    if ext_field_map.key?(name)
      return ext_field_map[name]
    else
      yield(self, ext_field) if block_given?
      return default
    end
  end

  ## import a field value from an external object to an internal
  ## object
  ##
  ## @param field [Symbol] field name
  ## @param ext_inst [Object] an instance of the #external_class
  ## @param int_inst [Object] an instance of the #internal_class
  ## @see #import_mapped
  def import(field, ext_inst, int_inst)
    bridge = find_bridge(field) {
      raise FieldBridgeNotFound.new(field, self)
    }
    bridge.import(ext_inst, int_inst)
  end

  ## export a field value from an internal object to an external
  ## object
  ##
  ## @param field [Symbol] field name
  ## @param int_inst [Object] an instance of the #internal_class
  ## @param ext_inst [Object] an instance of the #external_class
  ## @see #export_mapped
  def export(field, int_inst, ext_inst)
    bridge = find_bridge(field)  {
      raise FieldBridgeNotFound.new(field, self)
    }
    bridge.export(int_inst, ext_inst)
  end

  ## import values for all mapped fields from an external
  ## instance to an internal instance
  ##
  ## @param ext_inst [Object] an instance of the #external_class
  ## @param int_inst [Object] an instance of the #internal_class
  ## @see #import
  def import_mapped(ext_inst, int_inst)
    @field_map.each do |field, bridge|
      bridge.import(ext_inst, int_inst)
    end
  end

  ## export values for all mapped fields from an internal
  ## instance to an external instance
  ##
  ## @param int_inst [Object] an instance of the #internal_class
  ## @param ext_inst [Object] an instance of the #external_class
  ## @see #export
  def export_mapped(int_inst, ext_inst)
    @field_map.each do |field, bridge|
      bridge.export(int_inst, ext_inst)
    end
  end
end


class HFieldBroker < FieldBroker


  def initialize(internal_class, external_class = Hash)
    super(internal_class, external_class)
  end

  def import_mapped(h, int_inst)
    ## FIXME needs test
    ##
    ## NB This would not address 'include' objects in a mapping
    h.each do |k, v|
      name = k.to_sym
      bridge = self.find_bridge_external(name)
      if (bridge)
        bridge.import_value(int_inst, v)
      else
        if block_given?
          ## e.g within block: extra_data[k]=v
          yield(k, v)
        else
          msg = "No field bridge found for external key #{k} in #{self} \
and no block provided to #{__method__}"
          raise FieldBridgeNotFound.new(name,self,msg)
        end
      end
    end
  end


  def export_mapped(int_inst, h)
    ## FIXME needs test
    ##
    ## NB this would export values using the field order
    ## in which @field_map is defined
    @field_map.each do |field, bridge|
      # exp_name=self.name_for_export(field)\
      bridge.export(int_inst, h)
      # if bridge.value_in?(int_inst)
      #   value = bridge.get_internal(int_inst)
      #   ## FIXME this departs from other FieldBridge
      #   ## implementations in that it assumes that
      #   ## no value is bound for the field name in the
      #   ## hash. This does not iterate to add values,
      #   ## for any sequence or map value from the
      #   ## internal instance
      #   bridge.set_external(h, value)
      end
    end
end

module Bridge ## FieldBroker::Bridge

## method-oriented field bridge
##
## This class provides access for a generally scalar field
## value.
##
## @see FieldBroker::Bridge::VarFieldBridge
##  for internal storage using an instance variable
## @see FieldBroker::Bridge::FieldHBridge
##  for external storage onto a hash key
## @see FieldBroker::Bridge::VarFieldHBridge
##  for external storage onto a hash key, with
##  internal storage using an instance variable
## @see FieldBroker::Bridge::Seq::FieldBridge
##  for each field using a generally array-like storage
## @see FieldBroker::Bridge::Map::FieldBridge
##  for each field using a generally hash-like storage
class FieldBridge < ClassBridge
  ## NB illustration in interop.rspec
  attr_reader :internal_getter ## for #export
  attr_reader :internal_setter ## for #import

  attr_reader :external_getter ## for #import
  attr_reader :external_setter ## for #export

  attr_reader :name
  attr_reader :external_name

  def initialize(name, internal_class, external_class,
                 internal_getter: name,
                 internal_setter: true,  ## if true, derived from internal_getter
                 external_name: name,
                 external_getter: external_name,
                 external_setter: true ## if true, derived from external_getter
                )
    super(internal_class, external_class)
    @name = name
    internal_getter && ( @internal_getter = internal_getter)
    if (internal_setter == true) && internal_getter
      @internal_setter = (internal_getter.to_s + "=").to_sym
    elsif internal_setter
      @internal_setter = internal_setter
    end
    @external_name = external_name
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

  def import(external_inst, internal_inst)
    v = get_external(external_inst)
    set_internal(internal_inst, v)
  end

  def export(internal_inst, external_inst)
    v = get_internal(internal_inst)
    set_external(external_inst, v)
  end

  def value_in?(internal_inst)
    return true
  end
end


## common mixin module for field bridge types utilizing an
## instance variable for internal field storage
module VarFieldBridgeMixin
  def self.included(extclass)
    extclass.attr_reader :instance_var

    def initialize(name, internal_class, external_class,
                   # external_name: name,
                   instance_var: ("@" + name.to_s).to_sym,
                   #external_getter: external_name,
                   #external_setter: true,
                   **restargs)
      args = restargs.dup
      args[:internal_getter] ||= nil
      args[:internal_setter] ||= nil
      # args[:external_name] = external_name
      #external_getter && ( args[:external_getter]=external_getter )
      #external_setter && ( args[:external_setter]=external_setter )
      super(name, internal_class, external_class, **args)
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


## *FieldBridge* class for fields utilizing an instance variable
## for internal value storage
##
## This class provides access for a generally scalar field
## value.
##
## @see FieldBroker::Bridge::Seq::VarFieldBridge
## @see FieldBroker::Bridge::Map::VarFieldBridge
class VarFieldBridge < FieldBridge
  ## NB reimpl of a FieldDesc
  include VarFieldBridgeMixin
end

## Mixin module for application in a *FieldBridge* type
## utilizing a key in a Hash-like value, externally
module FieldHBridgeMixin
  def self.included(extclass)
    def initialize(name, internal_class, external_class = Hash, **restargs)
      args = restargs.dup
      args[:external_setter] ||= nil
      args[:external_getter] ||= nil
      super(name, internal_class, external_class, **args)
    end
  end ## self.included

  def name_for_export()
    ## NB using symbols in external hash keys, for application
    ## data. For purpose of interoperability, the keys can be
    ## translated to or from string values, during export or
    ## import onto any strongly typed syntax e.g with YAML
    ##
    ## if needed, this method can be overridden in
    ## any subclass
    return @external_name
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
      yield(external_inst, name) if block_given?
      return default
    end
  end

  ## TBD export_each, import_each for seq, map types
end

## Mixin module for application in a *FieldBridge* type utilizing
## a key in a Hash-like value externally, with an instance
## variable for internal storage of the field value
module VarFieldHBridgeMixin
  def self.included(extclass)

    if ! self.include?(VarFieldBridgeMixin)
      include VarFieldBridgeMixin
    end

    if ! self.include?(FieldHBridgeMixin)
      include FieldHBridgeMixin
    end

    def initialize(name, internal_class,
                   external_class = Hash,
                   instance_var: ("@" + name.to_s).to_sym,
                   **restargs)
      args = restargs.dup
      args[:external_setter] ||= nil
      args[:external_getter] ||= nil
      super(name, internal_class, external_class, **args)
      @instance_var = instance_var
    end

  end ## self.included
end ## VarFieldHBridgeMixin

## *FieldBridge* type for field name and value export to a *Hash*
##
## This class provides access for a generally scalar field
## value.
##
## @see FieldBroker::Bridge::Seq::FieldHBridge
## @see FieldBroker::Bridge::Map::FieldHBridge
class FieldHBridge < FieldBridge
  include FieldHBridgeMixin
end

## *FieldBridge* type for fields using an instance variable for
## internal value storage, with value export to a *Hash*
##
## This class provides access for a generally scalar field
## value.
##
## @see FieldBroker::Bridge::Seq::VarFieldHBridge
## @see FieldBroker::Bridge::Map::VarFieldHBridge
class VarFieldHBridge < VarFieldBridge
  include VarFieldHBridgeMixin
  alias :import_value :set_internal
end

## common class of *FieldBridge* for fields utilizing
## enumerable values for internal and external field
## storage
class EnumFieldBridge < FieldBridge
  ## store a duplicate of the external value for this field
  ## bridge, as the internal value for this field bridge
  ##
  ## @see #export_enum
  def import_enum(external_inst, internal_inst)
    v = get_external(external_inst).dup
    set_internal(internal_inst, v)
  end

  ## store a duplicate of the internal value for this field
  ## bridge, as the external value for this field bridge
  ##
  ## @see #import_enum
  def export_enum(internal_inst, external_inst)
    v = get_internal(internal_inst).dup
    set_external(external_inst, v)
  end
end


module Seq ## FieldBroker::Bridge::Seq

## *FieldBridge* for fields utilizing an Array-like value for internal
## and external field storage
##
## @see FieldBroker::Bridge::Seq::VarFieldBridge
##  for internal storage using an instance variable
## @see FieldBroker::Bridge::Seq::FieldHBridge
##  for external storage onto a hash key
## @see FieldBroker::Bridge::Seq::VarFieldHBridge
##  for external storage onto a hash key, with
##  internal storage using an instance variable
## @see FieldBroker::Bridge::FieldBridge
##  for fields using generally scalar values
## @see FieldBroker::Bridge::Map::FieldBridge
##  for fields using a generally hash-like storage
class FieldBridge < EnumFieldBridge

  ## add an element to the internal value for this field bridge
  ##
  ## @see #import_value
  ## @see #import_enum
  def add_internal(internal_inst, value)
    get_internal(internal_inst).push(value)
  end

  ## add an element to the external value for this field bridge
  ##
  ## @see #export_each
  ## @see #export_enum
  def add_external(external_inst, value)
    get_external(external_inst).push(value)
  end

  ## add each element of a value to the internal value for
  ## this field bridge
  ##
  ## @see #add_internal
  def import_value(internal_inst, value)
    ## NB appends - does not reset the internal value before
    ## importing each element
    ##
    ## FIXME use this under hash subclasses
    value.each do |elt|
      add_internal(internal_inst, elt)
    end
  end

  ## add elements to the internal value for this field bridge,
  ## bridge.
  ## using each element in the external value for this field
  ##
  ## @see #import_enum
  def import_each(external_inst, internal_inst)
    get_external(external_inst).each do |elt|
      add_internal(internal_inst, elt)
    end
  end
  alias :import :import_each

  ## add element to the external value for this field bridge,
  ## using each element in the internal value for this field
  ## bridge.
  ##
  ## @see #export_enum
  def export_each(internal_inst, external_inst)
    get_internal(internal_inst).each do |elt|
      add_external(external_inst, elt)
    end
  end
  alias :export :export_each
end

## *FieldBridge* type for fields utilizing an Array-like value
##  under an instance variable for internal field storage
class VarFieldBridge < FieldBridge
  include VarFieldBridgeMixin
end

class FieldHBridge < FieldBridge
  include FieldHBridgeMixin
end

class VarFieldHBridge < FieldHBridge
  include VarFieldHBridgeMixin
end


end ## Module FieldBroker::Bridge::Seq



module Map

## *FieldBridge* type for fields utilizing a Hash-like value for
## internal and external field storage
##
## @see FieldBroker::Bridge::Map::VarFieldBridge
##  for internal storage using an instance variable
## @see FieldBroker::Bridge::Map::FieldHBridge
##  for external storage onto a hash key
## @see FieldBroker::Bridge::Map::VarFieldHBridge
##  for external storage onto a hash key, with
##  internal storage using an instance variable
## @see FieldBroker::Bridge::FieldBridge
##  for fields using generally scalar values
## @see FieldBroker::Bridge::Seq::FieldBridge
##  for fields using a generally array-like storage
class FieldBridge < EnumFieldBridge

  ## add a key, value pair to the internal value for this field
  ## bridge
  ##
  ## @see #import_value
  ## @see #import_enum
  def add_internal(internal_inst, key, value)
    get_internal(internal_inst)[key] = value
  end

  ## add a key, value pair to the extternal value for this field
  ## bridge
  ##
  ## @see #export_each
  ## @see #export_enum
  def add_external(external_inst, key, value)
    get_external(external_inst)[key] = value
  end

  ## add each key, value pair of a hash value to the internal
  ## value for this field bridge
  ##
  ## @see #add_internal
  def import_value(internal_inst, value)
    ## NB appends - does not reset the internal value before
    ## importing each key, value pair
    ##
    ## FIXME use this under hash subclasses
    value.each do |k, v|
      add_internal(internal_inst, k, v)
    end
  end

  ## add key, value pairs to the internal value for this field
  ## bridge, using each key, value pair in the external value for
  ## this field bridge.
  ##
  ## @see #import_enum
  def import_each(external_inst, internal_inst)
    get_external(external_inst).each do |k, v|
      add_internal(internal_inst, k, v)
    end
  end
  alias :import :import_each

  ## add key, value pairs to the external value for this field
  ## bridge, using each key, value pair in the internal value for
  ## this field bridge.
  ##
  ## @see #export_enum
  def export_each(internal_inst, external_inst)
    get_internal(internal_inst).each do |k, v|
      add_external(external_inst, k, v)
    end
  end
  alias :export :export_each
end

class VarFieldBridge < FieldBridge
  include VarFieldBridgeMixin
end

class FieldHBridge < FieldBridge
  include FieldHBridgeMixin
end

class VarFieldHBridge < FieldHBridge
  include VarFieldHBridgeMixin
end

end ## module FieldBroker::Bridge::Map

end  ## module FieldBroker::Bridge

end ## module FieldBroker
## FIXME


# Local Variables:
# fill-column: 65
# End:
