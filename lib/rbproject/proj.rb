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


##
## Project class
##
class Proj

  VERSION="0.4.2"

  ## FIXME when the setter for Psych.dump_tags[Proj]
  ## is placed instead in an END block in this file
  ## and this file is loaded with irb, the END block
  ## is not being evaluated until irb exits.
  ##
  ## Is something translating the END blocks to
  ## at_exit blocks for load under irb?
  DUMP_TAG= Psych.dump_tags[self] ||=
            "#{self.name}@#{self::VERSION}"

  def self.load_yaml(file, **loadopts)

    descs = LOADABLE_FIELDS.map do |f|
      FieldDesc.new(self, reader_name: f,
                    writer_name: true)
    end

    p = self.allocate

    ## FIXME this may not gracefully handle some
    ## formatting errors in the file.
    ##
    ## This assumes that the file can be parsed
    ## as a top-level mapping or dictionary
    ##
    ## FIXME this dictionary syntax does not
    ## allow for project file includes, e.g
    ## to reuse common project fields, in this
    ## "YAML is not msbuild XML" hack

    loadopts[:symbolize_names] ||= true
    loadopts[:aliases] ||= true

    Psych.safe_load_file(file, **loadopts).each do
      |name,value|
      fdesc = descs.find  {
        |f| f.reader == name
      }
      if fdesc
        ( writer = fdesc.writer ) &&
          p.send(writer,value)
      else
        p.set_extra_conf_data(name,value)
      end
    end
    return p
  end

  attr_accessor :name
  attr_accessor :version
  attr_accessor :summary
  attr_accessor :description
  attr_accessor :license
  attr_accessor :lib_files
  attr_accessor :test_files
  attr_accessor :doc_files
  attr_reader   :extra_conf_data ## for serialization


  ## FIXME This class needs additional fields, for broader gemspec
  ## interop - see gemfile(5) and e.g
  ## Specification Reference @
  ## https://guides.rubygems.org/specification-reference/

  LOADABLE_FIELDS = [:name, :version, :summary,
                     :description, :license, :lib_files,
                     :test_files, :doc_files]


  def set_extra_conf_data(name, value)
    if @extra_conf_data
      @extra_conf_data[name] = value
    else
      @extra_conf_data = { name => value }
    end
  end


  def write_yaml_file(pathname, mode_flags: File::CREAT,
                     **dumpargs)
    ##
    ## FIXME store the original file pathname, during ::load_yaml
    ##
    ## & Write to that file by default, here
    ##
    ## implies: Project Workspace
    ##

    f = File.open(pathname, mode_flags | File::RDWR)
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

$FROB_P1 = Proj.load_yaml('../../rbloader.yprj')

$FROB_S00 = Psych.dump($FROB_P1, line_width: 65, header: true)

$FROB_P2 = Psych.safe_load($FROB_S00, symbolize_names: true)

## a general check for similarity across
## different encoding/decoding calls

IOST = StringIO.new

$FROB_S01 = $FROB_P1.write_yaml_stream(IOST)

IOST.pos=0

$FROB_P3 = Psych.load_stream(IOST, symbolize_names: true)

=end
