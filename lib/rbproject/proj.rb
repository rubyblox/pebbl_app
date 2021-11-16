## proj.rb

require('psych')

class FieldDesc
  attr_reader :in_class
  attr_reader :reader
  attr_reader :writer

  def initialize(in_class, reader_name: nil,
                 writer_name: nil)
    @in_class = in_class
    @reader = (reader_name &&
               in_class.instance_method(reader_name))
    if (writer_name == true) && reader_name
      use_writer_name = (reader_name.to_s + "=").to_sym
    else
      use_writer_name = writer_name
    end
    @writer = (use_writer_name &&
               in_class.instance_method(use_writer_name))
  end
end


class Proj

  def self.load_yaml(file)
    ydoc = Psych.parse_file(file)
    yvisitor = Psych::Visitors::ToRuby.create()

    ## FIXME no type checking - assuming ydoc.children[0]
    ## is of a type Psych::Nodes::Mapping
    root_mapping = ydoc.children.pop
    ## ^ FIXME pick up any remaining ydoc.children => ruby as extra data (??)
    root_fields = root_mapping.children
    p = Proj.allocate

    while ! ( root_fields.length.zero? )
      data = root_fields.pop(2)
      name = data[0].value.to_sym ## FIXME assuming scalar

      puts ("read #{name}")

      ## FIXME err if root_fields is empty at now:
      ## FIXME value translation
      ## FIXME fails on 'sequence'
      value = yvisitor.send(:deserialize, data[1]) ## FIXME may err ..

      fdesc = LOADABLE_DESCS.find  {
        |f| f.reader == name
      }
      if fdesc
        ( writer = fdesc.writer ) &&
          p.call(writer,value)
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


$FROB_P = Proj.load_yaml('../../rbloader.yprj')
