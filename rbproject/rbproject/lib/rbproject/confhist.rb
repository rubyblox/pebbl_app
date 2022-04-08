
class ConfHistMapper

  ## TBD: Alternate object models for configuration
  ## source recording
  ## - subclassing all "base object" classes ... ??
  ##   such as to provide an encode_with method for each,
  ##   and ... loosing any additional information after
  ##   serialization, short of the implicit mapping between
  ##   a configuration file and the configuration directives
  ##   present in the same file

  def initialize()
    @sonf_history = []
    @conf_schema = {}
  end

  def select_origin(origin)
    @conf_hist.select{ |entry| entry.origin == origin }
  end

  def schema_add(entry_class, directives)
    if directives.is_a?(Array)
	directives.each { |elt|
          @conf_schema[elt] = entry_class
        }
    else
      ## assumption: 'directives' is a symbol, here
      @conf_schema[directives]=entry_class
    end
  end

  def entry_class_for(directive, origin, **data)
    ## TBD origin, **data args - usage in any subclass
    if @conf_schema.key?(directive)
      return @conf_schema[directive]
    else
      raise "No configuration schema entry for directive #{directive}"
    end
  end

  def add_conf(directive, origin, **data)
    entry_class=entry_class_for(directive, origin, **data)
    entry_class.allocate(directive, origin, **data)
  end

  def map_conf(&block)
    @conf_hist.each do |entry|
      block.yield(entry)
    end
  end
end

class ConfEvent
  attr_reader :directive ## e.g a symbol, typically a field name ... (??)

  attr_reader :origin ## e.g a pathname

  def export(where)
  end

  ## TBD granularity - recording only field names?
  ## or field names with value change in the history event...
end

class IncludeEvent < ConfEvent
  DIRECTIVES=[:include]
  ## TBD configuration history recording for the included file
end

## see proj.rb @ Proj#encode_with // @fields_from_conf
## and interop.rb @ FieldBroker (??)


