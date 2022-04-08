## storetopics.rb - topical database API for RI doc objects

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

module RIKit

module TopicRegistryClass
  def self.extended(extclass)
    # def extclass.[]=(kind, useclass)
    def extclass.use_kind(kind, useclass)
      if @registry_kinds
        @registry_kinds[kind] = useclass
      else
        @registry_kinds = {kind => useclass}
      end
    end

    # def extclass.[](kind)
    def extclass.kind_class(kind)
      if @registry_kinds
        @registry_kinds[kind]
      else
        false
      end
    end

    def extclass.kind_classes
      @registry_kinds.values if @registry_kinds
    end
  end
end

module TopicRegistrantClass
  def self.extended(extclass)
    def extclass.register_to(registry)
      registry.use_kind(self::TOPIC_KIND, self)
    end
  end
end


class TopicRegistry
  extend TopicRegistryClass

  def convert_ns_topic(kind, orig)
    newc = kind_class(kind)
    ## NB this assumes that the copy_as call will in effect
    ## copy any members list for the original topic
    newtopic = orig.copy_as(newc)
    ns = orig.namespace
    ns.use_ns_element(newtopic)
    return newtopic
  end
end


class Topic
  attr_reader :namespace
  def initialize(in_namespace)
    @namespace = in_namespace
  end

  def kind
    self.class.kind
  end
end

class NamedTopic < Topic

  attr_reader :name
  attr_accessor :full_name
  attr_accessor :namespace ## nil if name is a top-level name

  def initialize (in_namespace, name)
    super(in_namespace)
    @name = name
    ## FIXME initialize rest, at some point
  end

  def inspect
    "#<%s 0x%x [%s]>" % [self.class, self.object_id, self.full_name]
  end
end


module TransferrableTopic
  def self.included(inclass)
    def transferrable_fields(dst_kind)
      ## FIXME implement
    end

    def add_transferrable_field(name, dst_kind)
      ## FIXME implement
    end

    def copy_field(which, inst, dst)
      ## FIXME TBD
    end

    def copy_as(dst_kind, instance)
      ## NB The behaviors are unspecified if the class of the
      ##    instance is not eql to this class

      ## FIXME needs class storage for transferrable fields
      ## onto A) fields via instance variables, or B) fields via accessors
      ## preferring "B"

      dst = self.kind_class(dst_kind).allocate

      transferrable_fields(dst_kind).each { |f|
        copy_field(f, instance, dst)
      }
      return dst
    end
  end
end

module TypedTopic
  def self.included(inclass)
    include TransferrableTopic
    attr_reader :type_members ## e.g constants, methods

    ## NB searching for constants will require parsing all existing RI
    ## files installed under a new pathname or updated since some
    ## previous timestamp.
    ##
    ## see e.g class_document_constants
    ## in ~/.local/share/gem/ruby/3.0.0/gems/rdoc-6.3.3/lib/rdoc/ri/driver.rb
  end

  def init_storage
    ## FIXME cannot call 'super' across modules per se @ storage kinds
    ##
    ## TBD can call a method metaobject ...  in Ruby ...
    @type_members = {}
  end

  def type_names
    ## e.g constant, method names
    @type_members && @type_members.keys
  end

  def type_members
    ## e.g constant, method topics
    @type_members && @type_members.values
  end

  def use_type_element(elt)
    ## FIXME differentiate (in constants and API)
    ## - NS_ELEMENT_KINDS/NS_KINDS e.g (:module => :module, :class), (:class => :class)
    ## - TYPE_ELEMENT_KINDS/TYPE_KINDS in NamedElement e.g :method, :constant for any
    elt_kind = elt.class::TOPIC_KIND
    if self.class::TYPE_ELEMENT_KINDS.member?(elt_kind) &&
       elt.class::TYPE_KINDS.member?(self.class::TOPIC_KIND)
      if @type_members.nil?
        @type_members = { elt.name => elt}
      else
        @type_members[elt.name] = elt
      end
      elt.type = self
    else
      raise "Element with topic kind #{elt.class::TOPIC_KIND} not valid in #{self}: #{elt}"
    end
  end

  def find_ns_element(name)
    find_table_element(@ns_members, name.to_s)
  end

end


module NamespaceTopic
  def self.included(inclass)
    include TransferrableTopic
    attr_reader :ns_members ## e.g modules, classes
  end

  def init_storage
    ## FIXME cannot call 'super' across modules per se @ storage kinds
    ##
    ## TBD can call a method metaobject ...  in Ruby ...
   @ns_members = {}
  end

  def ns_names
    ## e.g module, class names
    @ns_members && @ns_members.keys
  end

  def ns_members
    ## e.g module, class topics
    @ns_members && @ns_members.values
  end


  def use_ns_element(elt)
    ## FIXME differentiate (in constants and API)
    ## - NS_ELEMENT_KINDS/NS_KINDS e.g (:module => :module, :class), (:class => :class)
    ## - TYPE_ELEMENT_KINDS/TYPE_KINDS in NamedElement e.g :method, :constant for any
    elt_kind = elt.class::TOPIC_KIND
    if self.class::NS_ELEMENT_KINDS.member?(elt_kind) &&
       elt.class::NS_KINDS.member?(self.class::TOPIC_KIND)
      ## FIXME TBD implementing :name for PageTopic elements, which have no "name" per se
      if @ns_members.nil?
        @ns_members = { elt.name => elt}
      else
        @ns_members[elt.name] = elt
      end
      elt.namespace = self
      ## elt.full_name = ... # TBD name init in use_ns_element
    else
      raise "Element with topic kind #{elt.class::TOPIC_KIND} not valid in #{self}: #{elt}"
    end
  end

  def find_ns_element(name)
    find_table_element(@ns_members, name.to_s)
  end

  ## FIXME define the following in an included module (TBD API types vis. storage)
  protected

  def find_table_element(table, name)
    ## NB 'name' should be of the same type as keys in 'table' here
    if @table.nil?
      return false
    elsif @table.key?(name)
      @table[name]
    else
      return false
    end
  end

end


module TypedNamespaceTopic
  def self.included(inclass)
    include NamespaceTopic
    include TypedTopic
  end

  @@ns_init_storage = NamespaceTopic.instance_method(:init_storage)
  @@typed_init_storage = TypedTopic.instance_method(:init_storage)

  def init_storage
    ## FIXME cannot call 'super' across modules per se @ storage kinds
    ##
    ## TBD can call a method metaobject ...  in Ruby ...
    ##
    ## TBD defining this method via define_method in 'included'
    ## such that this method then cannot be called on the
    ## defining module
    @@ns_init_storage.bind_call(self)
    @@typed_init_storage.bind_call(self)
  end
end

class RITopicRegistry < TopicRegistry
  ## NB this implementation does not need to be optimized
  ## for interactive name completion
  include NamespaceTopic

  NAMESPACE_SEPARATOR = "::".freeze

  ## NB NS_ELEMENT_KINDS will be locally modified during use_kind
  NS_ELEMENT_KINDS=[]
  TOPIC_KIND=:REGISTRY

  attr_reader :module_topics, :class_topics

  def self.use_kind(kind, c)
    super(kind, c)
    unless NS_ELEMENT_KINDS.member?(kind)
      NS_ELEMENT_KINDS.push(kind)
    end
    return kind
  end

  def initialize()
    super()
    init_storage()
    @page_topics = {}
  end

  def inspect
    "#<%s 0x%x (%d namespace members, %d pages)>" % [
      self.class, self.object_id, @ns_members.length, @page_topics.length
      ]
  end

  def tree_error(message)
    ## NB this can be overridden in a subclass, if for purpose of debug
    warn message
  end


  def full_name
    ## NB if not "nil", it would be pulled into the namespace
    ## registration for registered elements of the registry
    return nil
  end

  def register_namespace(kind, name, parent = self)

  end

  def register_class(name, parent = self)
    ## FIXME/TBD parsing onto nested classes, here
    ## - NB do not use separate topic tables for each :kind
  end

  def register_module(name, parent = self)
    ## FIXME update to use a single topic tree for named program objects,
    ## not separate trees for each topic kind in the same
    ## ... in #use_ns_element
    kind = :module
    # STDERR.puts "register #{name} in #{self}"

    if (name.length > 2) && (name[0...2] == "::")
      ## FIXME ensure parent is a topic registry here
      unless parent.is_a?(TopicRegistry)
        tree_error "Registering toplevel module #{name} in non-toplevel namespace #{parent}"
      end
      name = name[2..]
    end

    name.split(NAMESPACE_SEPARATOR).each { |elt|
      # STDERR.puts "find #{elt} in #{parent.inspect}"
      nextopic = parent.find_ns_element(elt)
      if nextopic
        unless nextopic.kind.eql?(:module)
          tree_error "Converting #{nextopic} to :module kind (was #{nextopic.kind})"
          nextopic = self.convert_ns_topic(:module, nextopic)
        end
      else
        ## FIXME move the following into NamespaceTopic#use_ns_element
        c = self.class.kind_class(kind)
        nextopic = c.new(self, elt)
        parent_name = parent.full_name
        if parent_name
          nextopic.full_name = parent.full_name + NAMESPACE_SEPARATOR + elt
        else
          nextopic.full_name = elt
        end
        nextopic.namespace = parent
        parent.use_ns_element(nextopic)
      end
      parent = nextopic
    }
    parent.full_name ||= name
    return parent
  end

  def register_class(name, parent = nil)
    elts = name.split(NAMESPACE_SEPARATOR)

    c = self.class.kind_class(:class)
    inst = c.new(name)
  end

  def register_page(path)
    c = self.class.kind_class(:page)
    inst = c.new(path)
  end

  def load_store(store)
    st = case store.type
         when :system
           SystemStoreTool.new(store)
         when :site
           SiteStoreTool.new(store)
         when :home
           HomeStoreTool.new(store)
         when :gem
           GemStoreTool.new(store)
         else
           raise("Unknown store type %p in %s" % [store.type, store])
         end
    st.modules.each { |m|
      self.register_module(m)
    }
    st.classes.each { |c|
      self.register_class(c)
    }
    st.pages.each { |p|
      self.register_page(p)
    }
  end

end


class PageTopic < Topic
  ## TBD shared API for PageTopic and CDesc parsing
  ## - NB CDesc sections - "Constants", etc
  TOPIC_KIND = :page
  NS_KINDS = [:REGISTRY] ## or :page TBD ..

  extend TopicRegistrantClass
  register_to(RITopicRegistry)
  def initialize (registry, path)
    super(registry)
    @path = path
  end
end


class ModuleTopic < NamedTopic
  TOPIC_KIND = :module
  NS_KINDS = [:module, :REGISTRY].freeze
  NS_ELEMENT_KINDS = [:class, :module, :constant, :method].freeze

  NAMESPACE_SEPARATOR = RITopicRegistry::NAMESPACE_SEPARATOR

  extend TopicRegistrantClass
  register_to(RITopicRegistry)

  ## FIXME add constants storage to NamespaceTopic

  ## NB module "class methods" (singleton methods) in Ruby may include
  ##  extended
  ##  included
  ## visible e.g with <Module>.methods(false) for those directly defined
  ##  in a module.
  ##
  ## TBD as to whether or how that may be represented in RI
  ##
  ## TBD as to whether and how to access any list of methods defined by
  ##  including a  module, under Ruby - does Ruby publish this
  ##  information to the program environment?
  ##

  include NamespaceTopic

end

class ClassTopic < NamedTopic
  TOPIC_KIND = :class

  NS_KINDS = [:module, :class, :REGISTRY].freeze
  NS_ELEMENT_KINDS = [:class].freeze

  TYPE_ELEMENT_KINDS = [:method, :constant].freeze

  NAMESPACE_SEPARATOR = ModuleTopic::NAMESPACE_SEPARATOR

  extend TopicRegistrantClass
  register_to(RITopicRegistry)

  ## FIXME add constants storage to NamespaceTopic

  include NamespaceTopic
end


class MethodTopic < NamedTopic
  TOPIC_KIND = :method
  NS_KINDS = [:class, :module].freeze
  TYPE_KINDS = NS_KINDS

  ## NB name tokenization would be slightly less trivial, here
  ## in either of the singleton or instance method topic classes,
  ## namely in that the last name element uses a different
  ## name separator token.
  ##
  ## of course, the name in itself would not indicate if the
  ## namespace to the method is a class or a module

  extend TopicRegistrantClass
  register_to(RITopicRegistry)

  ## FIXME: extend for separate class/singleton and instance method topics
  ## or implement a :scope field (:singleton|:instance)
end


class InstanceMethodTopic < MethodTopic
  ## FIXME implement
  NAMESPACE_SEPARATOR = "#".freeze
end

class SingletonMethodTopic < MethodTopic
  ## FIXME implement
  NAMESPACE_SEPARATOR = ".".freeze
end


class ConstantTopic < NamedTopic
  TOPIC_KIND = :constant
  NS_KINDS = [:class, :module, :REGISTRY].freeze
  TYPE_KINDS = [:class, :module].freeze

  NAMESPACE_SEPARATOR = ModuleTopic::NAMESPACE_SEPARATOR

  extend TopicRegistrantClass
  register_to(RITopicRegistry)
end

end ## RIKit module

# Local Variables:
# fill-column: 65
# End:
