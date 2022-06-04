## yamlclass.rb

#module RBProject

require_relative('proj') ## YAMLExt (FIXME)

  module YAMLEntity
    ## TBD subclasses
    ## - YAMLScalar
    ## - YAMLSequence
    ## - YAMLMap
    ##
    ## NB refer to rbproject proj.rb
    YAML_TAG ||= self.name

    def self.included(inclass)

      extend YAMLExt
      init_yaml_tag(YAML_TAG)

      def check_coder_type(coder)
        if (coder.type != self::CODER_TYPE)
          raise ("Unsupported coder type: %p for %p in %s" % [
                   coder.type, coder, __method__
                 ])
        end
      end


    end

    def init_with(coder)
      ## NB object may not have been fully initialized when this method
      ## is called
      self.class.check_coder_type(coder)
    end

    def encode_with(coder)
     self.class.check_coder_type(coder)
     coder.tag = self.class::YAML_TAG
    end
  end

  module YAMLScalar
    CODER_TYPE ||= :scalar
    include YAMLEntity

      ## NB this should not use 'marshal' forms
      ## - there is probably a YAML ext for that under Ruby/psych

    def init_from_scalar(scalar)
      ## TBD string deserialization w/o marshal forms
    end

    def to_scalar()
      ## TBD string serialization w/o marshal forms
    end

    def init_with(coder)
      super(coder)
      self.init_from_scalar(coder.scalar)
    end

    def encode_with(coder)
      super(coder)
      coder.scalar = self.to_scalar()
    end
  end

  module YAMLSequence
    CODER_TYPE ||= :sequence
    include YAMLEntity

    def init_from_seq(seq)
      ## TBD iteration on input
    end

    def to_seq()
      ## TBD iteration for coder seq binding
    end

    def init_with(coder)
      super(coder)
      self.init_from_seq(coder.seq)
    end

    def encode_with(coder)
      super(coder)
      coder.seq = self.to_seq()
    end
  end

  module YAMLMap
    CODER_TYPE ||= :map
    include YAMLEntity

    def init_from_map(map)
      ## TBD selective instance variable processing on input
    end

    def to_map()
      ## TBD selective instance variable processing on output
    end

    def init_with(coder)
      super(coder)
      self.init_from_map(coder.map)
    end

    def encode_with(coder)
      super(coder)
      coder.map = self.to_map()
    end
  end


  module YAMLObject # < YAMLMap
  end


### FIXME move testing code to another file :

  require_relative('./fieldclass')

  ## and to a point of this ...

  class YAMLFile < File
    include YAMLObject
  end

  ## and for applications ... in application development


  class ChangeLogEntry

    include  YAMLObject
    extend FieldProvider

    ## TBD portable definition of fields to serialize for encode_for
    ## see also: proj.rb

    fields_init(reader: true, writer: true)
    field({type: String}, :author)
    field({type: Time}, :timestamp)
    field({type: String}, :data)

    def encode_with(coder)
      super()
      map = coder.map
      self.class.field_info.each { |info|
        map[info.name] = info.bind(self)
      }
    end

    def encode_self_for(container)
      coder = Psych::Coder.new(self::YAML_TAG)
      coder.type = :map
      encode_with(coder)
      return coder
    end
  end

  class ChangelogFile < YAMLFile
    ## TBD overriding the superclass YAMLObject include
    ## with a YAMLSequence include here
    ##
    ## or not including YAMLObject in YAMLFile
    ##
    ## or using a different superclass here - e.g ProjectDataFile
    ##
    ## or using a non-sequence encoding here
    ## e.g
    ## - <changleog-key>: <changelog-object>
    include YAMLSequence

    attr_reader :entries

    def encode_with(coder)
      ## NB configuring something of a rudimentary AST under the coder.map data
      ## pursuant towards any stream-based encoding
      super(coder)
      encoded_entries = []
      entries.each { |entry|
        encoded = entry.encode_self_for(self)
        encoded_entries.push(encoded)
      }
      coder.map[:entries] = encoded_entries
    end

    def init_with(coder)
      ## NB the instance may not be fully initialized when this method
      ## is called
      super(coder)
      map = coder.map
      ## TBD decoding as one 'entries' ... array.
      ## NB an array would allow for duplicate key (e.g timestamp) values
      @entries = ( map[:entries] || [] )
      ## .. or as a sequence of entry keys, on this object's YAML map
      ## as an encoded hash table
    end
  end

#end
