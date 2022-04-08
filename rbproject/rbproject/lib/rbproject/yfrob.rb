## ytests.rb

require('psych')
## ^ NB it's being used in the YAML impl anyway ...

##
## loading a YAML serialization stored under an unkonown class
##
begin
  o = Psych.safe_load ("--- !ruby/object:Unknown\nname: Project 02\n")
rescue Psych::DisallowedClass => exc

  ## TBD no state data in Psych.parser,
  ## pursuant after the error
  ## $FROB = [ exc , Psych.parser]

  ## can determine the class name:
  msg_data = exc.message.split(": ")
  if (msg_data.length >= 2) &&
      (msg_data[0] == "Tried to load unspecified class")
    THE_CLASS = msg_data[1]
  end
  ##
  ## origin information would be available
  ## in the calling environment
  ##

  ## TBD @ each:
  ##
  ## 1) using an alternate class, namely a Struct
  ## instance, to load YAML for any unkonwn class
  ## - parsing for the original class name,
  ##   fields, and field data with Psych
  ##
  ## 2) transferring project data from any
  ## Struct instance into a Project object,
  ## assuming a Struct has been used to serialize
  ## the project data

end

##
## --- Struct Serialization
##

P = Struct.new(:name)

p01 = P.new("Project 01")

s = YAML.dump(p01)
# -> "--- !ruby/struct:P\nname: Project 01\n"

## and now ...

s = YAML.safe_load("--- !ruby/struct:POther\nname: Project 02\n")

## ^ fails
##
## FIXME: For any serialized struct instance,
## define the instance's struct type during load,
## if not found
## - TBD providing that feature as an option
## during load
## - TBD extending Psych's low-level visitor (??)
##   API, for this - it may not be in
##   psych:lib/psych/visitors/yaml_tree.rb
##   - Psych::Parser (??) &rest
##   - see https://www.rubydoc.info/gems/psych/Psych/Parser
##   - docs on emtpy methods in
##     psych:lib/psych/handler.rb
##     - TBD how object or struct types are decoded,
##       under that handler API.
##     - It may involve :start_mapping at some point ...
##     - TBD usable subclasses of Psych::Handler
##       * psych:lib/psych/tree_builder.rb
##         .... might not be a complete implementation, itself?


## TBD - how does the parser parse a serialized struct record?
## cf. psych:lib/psych/handlers/recorder.rb

require('psych')

rec = Psych::Handlers::Recorder.new() ## N/A in ruby core (??)
p = Psych::Parser.new(rec)
out = p.parse("--- !ruby/struct:P\nname: Project 01\n")
rec.events
## result:
# [[:start_stream, [1]],
#  [:start_document, [[], [], false]],
#  [:start_mapping, [nil, "!ruby/struct:P", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Project 01", nil, nil, true, false, 1]],
#  [:end_mapping, []],
#  [:end_document, [true]],
#  [:end_stream, []]]
## i.e :start_mapping then alternating field (scalar) and value (any) records
## up to :end_mapping
##
## NB Psych did not store the field names as symbols, per se

## TBD Psych::TreeBuilder does not define
## :start_mapping or :end_mapping methods.
##
## Psych::Handler defines empty methods.
##
## How does this codebase ever deserialize struct records?
##
## is it bounced through uses of the Psych::JSON::YAMLEvents mixin module (??)
## psych:lib/psych/json/yaml_events.rb
## ??
## used in Psych::JSON::Emitter
## @ psych:lib/psych/json/stream.rb
## and used in Psych::JSON::TreeBuilder
## @ psych:lib/psych/json/tree_builder.rb
##
## or is managed in the C src?
## under psych:ext/psych/
## e.g in psych:ext/psych/psych_emitter.c [x]

## see sbuilder.rb


## ---

require('psych')
require '/usr/local/src/ruby_wk/psych_devsrc/lib/psych/handlers/recorder.rb'

Struct.new("Proj", :name, :main, :other)

Struct.new("Mod", :name) ## module


m01 = Struct::Mod.new("Module 01")
m02 = Struct::Mod.new("Module 02")
m03 = Struct::Mod.new("Module 03")

p01 = Struct::Proj.new(
  "Project 01",
  m01,
  [m02, m03]
)

s = Psych.dump(p01)
# "--- !ruby/struct:Struct::Proj\nname: Project 01\nmain: !ruby/struct:Struct::Mod\n  name: Module 01\nother:\n- !ruby/struct:Struct::Mod\n  name: Module 02\n- !ruby/struct:Struct::Mod\n  name: Module 03\n"

rec = Psych::Handlers::Recorder.new() ## N/A in ruby core (??)
p = Psych::Parser.new(rec)
out = p.parse(s)
rec.events

# [[:start_stream, [1]],
#  [:start_document, [[], [], false]],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Proj", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Project 01", nil, nil, true, false, 1]],
#  [:scalar, ["main", nil, nil, true, false, 1]],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 01", nil, nil, true, false, 1]],
#  [:end_mapping, []],
#  [:scalar, ["other", nil, nil, true, false, 1]],
#  [:start_sequence, [nil, nil, true, 1]],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 02", nil, nil, true, false, 1]],
#  [:end_mapping, []],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 03", nil, nil, true, false, 1]],
#  [:end_mapping, []],
#  [:end_sequence, []],
#  [:end_mapping, []],
#  [:end_document, [true]],
#  [:end_stream, []]]

## ---


Struct.new("Proj", :name, :main, :other)

Struct.new("Mod", :name, :sub) ## module

m01 = Struct::Mod.new("Module 01")
m02 = Struct::Mod.new("Module 02")
m03 = Struct::Mod.new("Module 03")

## NB how the syntax may handle a refernce loop
## - i.e with an "Alias", in a term
## presented at https://yaml.org/YAML_for_ruby.html
##
## TBD how that shows up in the Psych API
m02.sub = m03
m03.sub = m02

p01 = Struct::Proj.new(
  "Project 01",
  m01,
  [m02, m03]
)

s = Psych.dump(p01)

# "--- !ruby/struct:Struct::Proj\nname: Project 01\nmain: !ruby/struct:Struct::Mod\n  name: Module 01\n  sub:\nother:\n- &1 !ruby/struct:Struct::Mod\n  name: Module 02\n  sub: &2 !ruby/struct:Struct::Mod\n    name: Module 03\n    sub: *1\n- *2\n"

rec = Psych::Handlers::Recorder.new() ## N/A in ruby core (??)
p = Psych::Parser.new(rec)
out = p.parse(s)
rec.events

# [[:start_stream, [1]],
#  [:start_document, [[], [], false]],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Proj", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Project 01", nil, nil, true, false, 1]],
#  [:scalar, ["main", nil, nil, true, false, 1]],
#  [:start_mapping,
#   [nil, "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 01", nil, nil, true, false, 1]],
#  [:scalar, ["sub", nil, nil, true, false, 1]],
#  [:scalar, ["", nil, nil, true, false, 1]],
#  [:end_mapping, []],
#  [:scalar, ["other", nil, nil, true, false, 1]],
#  [:start_sequence, [nil, nil, true, 1]],
#  [:start_mapping,
#   ["1", "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 02", nil, nil, true, false, 1]],
#  [:scalar, ["sub", nil, nil, true, false, 1]],
#  [:start_mapping,
#   ["2", "!ruby/struct:Struct::Mod", false, 1]],
#  [:scalar, ["name", nil, nil, true, false, 1]],
#  [:scalar, ["Module 03", nil, nil, true, false, 1]],
#  [:scalar, ["sub", nil, nil, true, false, 1]],
#  [:alias, ["1"]],
#  [:end_mapping, []],
#  [:end_mapping, []],
#  [:alias, ["2"]],
#  [:end_sequence, []],
#  [:end_mapping, []],
#  [:end_document, [true]],
#  [:end_stream, []]]

## ---

require('psych')

begin
  $FROB_OUT = Psych.parse_file('../../rbloader.yprj')
rescue Psych::SyntaxError => err
  $FROB_ERR = err
end


## ---
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


    ## FIXME Ruby's "pop" is backwards

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
