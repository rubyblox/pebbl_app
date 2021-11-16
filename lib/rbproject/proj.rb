## proj.rb

require('psych')

class FieldDesc
  attr_reader :in_class
  attr_reader :reader
  attr_reader :writer

  def initialize(in_class, reader_name: nil,
                 writer_name: nil)
    @in_class = in_class

    ## FIXME cannot call 'send' on actual method objects

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

  def self.load_yaml(file)

    p = Proj.allocate

    Psych.safe_load_file(file,
                         symbolize_names: true).each do
      |name,value|
      fdesc = LOADABLE_DESCS.find  {
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

  ## NB still not enough as a field desc, each:
  LOADABLE_FIELDS = [:name, :version, :summary,
                     :description, :license, :lib_files,
                     :doc_files]

  LOADABLE_DESCS = LOADABLE_FIELDS.map do |f|
    FieldDesc.new(self, reader_name: f,
                  writer_name: true)
  end


  def set_extra_conf_data(name, value)
    if @extra_conf_data
      @extra_conf_data[name] = value
    else
      @extra_conf_data = { name => value}
    end
  end
end


=begin

$FROB_P = Proj.load_yaml('../../rbloader.yprj')
## ^ simple enough on the input side ...

=end
