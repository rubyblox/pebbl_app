## proj.rb

require('psych')



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


class Proj

  VERSION="0.4.1"

  ## FIXME the setter for Psych.dump_tags[Proj]
  ## was not being evaluated when in an END
  ## block in this file. Not any END block
  ## in this file was being evaluated
  DUMP_TAG= Psych.dump_tags[self] ||=
            "#{self.name}@#{self::VERSION}"

  def self.load_yaml(file)

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

    Psych.safe_load_file(file,
                         symbolize_names: true,
                         aliases: true).each do
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
    ## FIXME store the original file pathname, during ::load_yaml
    ##
    ## & Write to that file, by default, here
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
#   ## was not reached
#   puts "DEBUG: in END block for #{__FILE__}"
# }


=begin

$FROB_P1 = Proj.load_yaml('../../rbloader.yprj')
## ^ simple enough on the input side ...

$FROB_S00 = Psych.dump($FROB_P1, line_width: 65, header: true)

$FROB_P2 = Psych.safe_load($FROB_S00, symbolize_names: true)

## a general check for similarity across
## different encoding/decoding calls

IOST = StringIO.new

$FROB_S01 = $FROB_P1.write_yaml_stream(IOST)

IOST.pos=0

$FROB_P3 = Psych.load_stream(IOST, symbolize_names: true)

=end
