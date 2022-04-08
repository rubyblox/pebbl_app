
class InteropBroker

  ## cf +kind+ in #add_field_desc... (trivial assoc)
  FIELD_INTEROP_MAP = { :scalar => [ScalarFieldDesc, ScalarFieldMap],
                        :sequence => [SequenceFieldDesc, SequenceFieldMap],
                        :mapping => [MappingFieldDesc, MappingFieldMap]  }

  attr_reader :internal_class
  attr_reader :field_descs


  ## FIXME redesign as a sort of FieldDescs container
  ## with additional support for valu eexport calls
  ##
  ## NB Note the special handling needed for :include
  ## fields or fields with scalar object values of a certain
  ## extension class, decoded from YAML with Psych

  def initialize(internal_class)
    ## FIXME as this stores an actual class, application libraries
    ## should ensure that a new InteropBroker is created
    ## for each redefined class
    @internal_class = internal_class
    @field_descs = {}
    yield self if block_given?
  end

  def add_field_desc(name, kind)
    classes = FIELD_INTEROP_MAP[kind]
    if classes
      c = classes[0]
      use_name = name.to_sym
      fdesc = c.new(@internal_class, use_name)
      yield fdesc if block_given?
      @field_descs[use_name] = fdesc
    else
      raise ArgumentError.new(
        "No field description class found for kind #{kind} (#{name})")
    end
  end

  def rem_field_desc(name)
    @field_descs.delete(name.to_sym)
  end

  def field_desc(name)
    return @field_descs[name.to_sym]
  end

  def map_field_descs()
    ## NB the block should receive two arguments,
    ## a field name and a FieldDesc bound for that field
    if block_given?
      yield @field_descs
    else
      raise "No block provided for #{__method__} in #{self}"
    end
  end

  def add_field_exporter(name, external_class, external_name)


    ## FIXME now handled in FieldDesc#add_field_exporter

    fdesc = field_desc(name)
    if fdesc
      ## FIXME the initial prototype is naive, here
      fdesc_kind = fdesc.type
      mdesc_classes = FIELD_INTEROP_MAP[fdesc_kind]
      mdesc_c = mdesc_classes[1]
      inst = mdesc_c.new(external_class, external_name)
      ## TBD storage & subsq access for the external field map onto the
      ## associated internal field desc
      ##
      ## FIXME may not be consistent across class redefinition, as the
      ## class itself is used as a hash key
      fdesc.field_exporters[external_class]=inst
    else
      raise "No field desc found for #{name}"
    end
  end

  def rem_field_exporter(name, external_class)
    fdesc = field_desc(name)
    if fdesc
      fdesc.field_exporters.delete(external_class)
    else
      raise "No field desc found for #{name}"
    end
  end


  def map_field_exporters(name)
    fdesc = field_desc(name)
    if fdesc
      if block_given?
        yield fdesc.field_exporters
      else
        raise "No block provided for #{__method__} in #{self}"
      end
    else
      raise "No field desc found for #{name}"
    end
  end

  ## TBD import/export onto the field_exporter maps
  ## for an arbitrary instance A and external instance B

  def get_import_mapper(external_class) # ?

  end

  def get_export_mapper(external_class) # ?

  end

  def import_field(int_inst, int_name, ext_inst)

  end

  def export_field(int_inst, int_name, ext_inst)
  end



end



class InteropMapper # ??

  attr_reader :interop_broker

  def initialize(interop_broker)
    @interop_broker = broker
  end

  def import(int_instance, ext_instance)
  end

  def export(int_instance, ext_instance)
  end

  def add_field_exporter(tbd)
  end

  def rem_field_exporter(tbd)
  end
end

class HashInteropMapper < InteropMapper
## e.g for a coder.map or generalized YAML mapping as a Hash
end


class ObjectInteropMapper < InteropMapper
## e.g for a gemspec
end

# Local Variables:
# fill-column: 65
# End:
