## proj.rb

require('psych')


## _ad hoc_ field description for Ruby classes,
## suitable for simple get/set fields
class FieldDesc
  attr_reader :in_class
  attr_reader :reader
  attr_reader :writer

  def initialize(in_class, reader_name: nil,
                 writer_name: nil)
    @in_class = in_class

    @reader = reader_name
    if (writer_name == true) && reader_name
      use_writer_name = (reader_name.to_s + "=").to_sym
    else
      use_writer_name = writer_name
    end
    @writer = use_writer_name
  end
end


class YAMLInclude
  attr_accessor :yaml_filename
  attr_accessor :host_filename

  VERSION= "0.0.1"

  YAML_TAG= ( tag = "#{self.name}@#{self::VERSION}".freeze;
             Psych.load_tags[tag]  = self;
             Psych.dump_tags[self] = tag )

  DIRECTIVE= "Include".to_sym

  def coder_value(coder)
    if (coder.type == :scalar)
      return coder.scalar
    else
      ## FIXME use a more exacting exception type here
      raise "Unsupported coder type #{coder.type} in #{coder}"
    end
  end

  def init_with(coder)
    ## NB usage under Psych::**::ToRuby
    value = coder_value(coder)
    if (value == DIRECTIVE)
      ## NB the filename part of the mapping is what to load
    else
      ## TBD ensure that the filename will be processed for
      ## adding subsequent mapping entries, Proj#load_yaml_stream
    end
  end

  def encode_with(coder)
    ## NB usage under Psych::**::YAMLTree
    value = coder_value(coder)
    ## TBD dump a tagged value ..
    if (value == DIRECTIVE)
      ## NB the filename part of the mapping is one of half of what to encode
    else
    end
  end
end



##
## Project class
##
class Proj

  ## TBD may have to use encode_with (if not also init_with) in
  ## this class itself, to use some specific encode_with
  ## semantics under possible configuration - incl. configuration
  ## with "Include"

  VERSION="0.4.3"

  ## FIXME when the setter for Psych.dump_tags[Proj]
  ## is placed instead in an END block in this file
  ## and this file is loaded with irb, the END block
  ## is not being evaluated until irb exits.
  ##
  ## Is something translating the END blocks to
  ## at_exit blocks for load under irb?
  # YAML_TAG= Psych.dump_tags[self] ||=
  #           "#{self.name}@#{self::VERSION}"
          ## ^ FIXME not similarly: Psych::Psych.load_tags

  YAML_TAG= ( tag = "#{self.name}@#{self::VERSION}".freeze;
             Psych.load_tags[tag]  = self;
             Psych.dump_tags[self] = tag )

  def self.load_yaml_file(filename, **loadopts)
    ## FIXME may not be immediately useful
    ## for deserialization to any subclass instance
    ##
    ## FIXME provide an extended loadopt for file encoding
    instance = self.allocate
    instance.load_yaml_file(filename, **loadopts)
    return instance
  end

  attr_accessor :name
  attr_accessor :version
  attr_accessor :summary
  attr_accessor :description
  attr_accessor :license
  attr_accessor :lib_files ## FIXME needs a sequence reader => add... under *from_yaml_stream
  attr_accessor :test_files ## FIXME similar (previous)
  attr_accessor :doc_files ## FIXME similar (previous)
  attr_reader	:extra_conf_data ## for deserialization - hash table or nil
  attr_accessor :fields_from_conf ## for debug


  ## FIXME This class needs additional fields, for broader gemspec
  ## interop - see gemfile(5) and e.g
  ## Specification Reference @
  ## https://guides.rubygems.org/specification-reference/

  SERIALIZE_FIELDS = [:name, :version, :summary,
                     :description, :license, :lib_files,
                     :test_files, :doc_files]


  def set_extra_conf_data(name, value)
    if @extra_conf_data
      @extra_conf_data[name] = value
    else
      @extra_conf_data = { name => value }
    end
  end

  def load_yaml_field(name, value, field_descs, source_file = nil)

    if (name.instance_of?(YAMLInclude))
      yfile = value.yaml_source_file
      abs = File.expand_path(yfile, source_file && File.dirname(source_file))
      @fields_from_conf.push [abs, source_file]
      ## FIXME provide an "load option" to continue
      ## when the include file is not available
      self.load_yaml_file(abs,**loadopts)
    else
      @fields_from_conf.push [name, source_file]

      fdesc = @fdescs.find  {
        |f| f.reader == name
      }
      ## FIXME parse for a name == :include
      ## using the value as a source_file relative to this file
      ## subsq initializing 'instance' with any data from
      ## that file (or failing if inaccessible)

      ## FIXME reimplement onto Psych::Coder ??
      if (fdesc && ( writer = fdesc.writer ))
        self.send(writer,value)
      elsif (name == :extra_conf_data)
        ## assumption: the value represents a hash table, such
        ## that would have been encoded as a YAML mapping
        value.each do |exname, exvalue|
          self.set_extra_conf_data(exname,exvalue)
        end
      else
        ## unkonwn top level { name => value } pair
        ## will be stored in extra_conf_data
        self.set_extra_conf_data(name,value)
      end
    end
  end


  def load_yaml_file(filename, **loadopts)
    ## FIXME provide an extended loadopt for file encoding
    f = File.open(filename, "rb:BOM|UTF-8")
    opts = loadopts.dup
    opts[:filename] ||= filename
    self.load_yaml_stream(f,**opts)
    ensure
      f.close
  end

  def load_yaml_stream(io, **loadopts)

    ## FIXME FDESCS should be stored and accessed
    ## via a class method
    @fdescs ||= self.class::SERIALIZE_FIELDS.map do |f|
      ## populate @fdescs with an array of
      ## FieldDesc objects for this class
      FieldDesc.new(self, reader_name: f,
                    writer_name: true)
    end

    ## FIXME this may not gracefully handle some
    ## formatting errors in the file.
    ##
    ## This assumes that the file can be parsed
    ## as a top-level mapping or dictionary

    ## FIXME this dictionary syntax does not
    ## allow for project file includes, e.g
    ## to reuse common project fields, in this
    ## "YAML is not msbuild XML" hack

    opts = loadopts.dup

    opts[:symbolize_names] ||= true
    opts[:aliases] ||= true

    ## NB debug storage - FIXME will not overwrite previous
    ## entries in @fields_from_conf if the instance is initialized
    ## more than once, from the same file & includes. That should
    ## be managed in some calling method, to set @fields_from_conf
    ## to an empty array before reinitializing the instance from
    ## configuration files
    @fields_from_conf ||= []
    if ( filename = opts[:filename] )
      filename = File.expand_path(filename)
    end

    Psych.safe_load(io, **opts).each do
      ## initialize the new instance 'instance'
      ## per { key => value } pairs in the data
      ## deserialized from the top-level mapping
      ## assumed to have been encoded in the YAML
      ## stream
      ##
      ## Assumptions:
      ## - the value of <name> is a symbol
      ## - the value of <value> is a list, hash,
      ##   or scalar value
      |name, value|
      load_yaml_field(name, value, @fdescs, filename)
    end
    return self
  end

  def write_yaml_file(pathname, **dumpargs)
    ##
    ## FIXME store the original file pathname, during ::load_yaml_file
    ##
    ## & Write to that file by default, here
    ##
    ## implies: Project Workspace
    ##

    ## FIXME if @fields_from_conf is non-nil and non-empty
    ## then iterate across the same,
    ## else ... TBD/FIXME using SERIALIZE_FIELDS

    f = File.open(pathname, "wb:BOM|UTF-8")
    write_yaml_stream(f, **dumpargs)
    f.flush
    return f
    ensure
      f.close
  end

  def write_yaml_stream(dest, **dumpargs)
    dumpargs[:line_width] ||= 65
    dumpargs[:header] ||= true

    Psych.dump(self, dest, **dumpargs)
  end


  # def write_gemfile(dest)
  # end

end


# END {
#   ## FIXME not reached until irb exit?
#   ## when file is loaded with irb, via #require or #load
#   ## w/ ruby 3.0.2p107 (Arch Linux)
#
#   puts "DEBUG: in END block for #{__FILE__}"
# }


=begin

## trivial tests for Proj serialization/deserialization
## onto YAML

$FROB_P1 = Proj.load_yaml_file('../../rbloader.yprj')

$FROB_S00 = Psych.dump($FROB_P1, line_width: 65, header: true)

$FROB_P2 = Psych.safe_load($FROB_S00, symbolize_names: true)

## a general check for similarity across
## different encoding/decoding calls

IOST = StringIO.new

$FROB_S01 = $FROB_P1.write_yaml_stream(IOST)

IOST.pos=0

$FROB_P3 = Psych.load_stream(IOST, symbolize_names: true)

=end
