## storetopics.rb


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
  ## FIXME ...
  ## - one registry for each StoreTool
  ## - TBD global registry, when a name may be defined under multiple providers

  #   def addTopic(topic,provider) ... # most useful for a PageTopic, TBD recursive handling for API topics
end


class Topic
  ## TBD
  # attr_reader :path
  def initialize()
  end
end

class NamedTopic < Topic
  attr_reader :name
  attr_accessor :full_name
  attr_accessor :namespace ## nil if name is a top-level name
  def initialize (name)
    super()
    @name = name
    ## FIXME initialize rest, at some point
  end

  def inspect
    "#<%s 0x%x [%s]>" % [self.class, self.object_id, self.full_name]
  end
end

## NB
## ["ABC","C","Z","PDQ","DEFG"].sort{ |a,b| al = a.length; bl = b.length; if al == bl; 0; elsif al < bl; -1; else 1; end }
##
## TBD names already stored under RDoc::Store

module NamespaceTopic
  def self.included(inclass)
    inclass.attr_reader :elements

    ## NB searching for constants will require parsing all existing RI
    ## files installed under a new pathname or updated since some
    ## previous timestamp.
    ##
    ## see e.g class_document_constants
    ## in ~/.local/share/gem/ruby/3.0.0/gems/rdoc-6.3.3/lib/rdoc/ri/driver.rb


    ## FIXME define ...
    ## storetool .. attr_reader :topics
    ## @topics = {} ## key = topic kind, value = TBD (TopicStore)
    ## storetool .. load_topic
    ## storetool .. map_topics(recurse = nil)
    def inclass.ensure_containing_namespace(name, store)
      if name.is_a? Array
        parts = name
      else
        parts = name.split('::') ## self.NAMESPACE_SEPARATOR
      end
      if parts.length > 1
        store.find_topic_for(self.NAMESPACE_KIND, parts[...-1])
      else
        return nil
      end
    end
  end

  def initialize(fullname)
    ## TBD initialize in a module (FIXME unused for RITopicRegistry)
    super(fullname)
    init_storage
    ## N/A no store ...
    #@namespace = self.class.ensure_containing_namespace(fullname, store)
  end

  def init_storage
    @elements ||= self.class::ELEMENT_KINDS.map { |kind|
      [kind,{}]
    }.to_h
  end

  def use_element(elt)
    elt_kind = elt.class::TOPIC_KIND
    if self.class::ELEMENT_KINDS.member?(elt_kind) &&
       elt.class::NAMESPACE_KINDS.member?(self.class::TOPIC_KIND)
      name = elt.name
      if (elt_hash = @elements[elt_kind])
        elt_hash[name] = elt
      else
        @elements[elt_kind] = { name => elt }
      end
    else
      raise "Element with topic kind #{elt.class::TOPIC_KIND} not valid in #{self}: #{elt}"
    end
  end

  def find_element(kind, name)
    elt_hash = @elements[kind]
    if elt_hash
      # TBD name as string or [string+]
      if name.is_a?(String)
        elt_hash[name]
      else
        ## FIXME
        raise "Unsupported: %s#%s(%p, %p)" % [self.class, __method__, kind, name]
      end
    else
      return false
    end
  end
end


class RITopicRegistry < TopicRegistry
  ## NB this implementation does not need to be optimized
  ## for interactive name completion
  include NamespaceTopic

  NAMESPACE_SEPARATOR = "::".freeze

  ## NB ELEMENT_KINDS will be locally modified during use_kind
  ELEMENT_KINDS=[]
  TOPIC_KIND=:REGISTRY

  attr_reader :module_topics, :class_topics

  def self.use_kind(kind, c)
    super(kind, c)
    unless ELEMENT_KINDS.member?(kind)
      ELEMENT_KINDS.push(kind)
    end
    return kind
  end

  def initialize()
    @module_topics = {}
    @class_topics = {}
    @constant_topics = {}
    @page_topics = {}
    @elements = {module: @module_topics,
                 class: @class_topics,
                 constant: @constant_topics,
                 page: @page_topics}
  end

  def inspect
    "#<%s 0x%x (%d modules, %d classes, %d constants, %d pages)>" % [
      self.class, self.object_id, @module_topics.length,
      @class_topics.length, @constant_topics.length,
      @page_topics.length
      ]
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
    kind = :module
    name.split(NAMESPACE_SEPARATOR).each { |elt|
      nextopic = parent.find_element(kind, elt)
      unless nextopic
        c = self.class.kind_class(kind)
        nextopic = c.new(elt)
        parent_name = parent.full_name
        if parent_name
          nextopic.full_name = parent.full_name + NAMESPACE_SEPARATOR + elt
        else
          nextopic.full_name = elt
        end
        nextopic.namespace = parent
        parent.use_element(nextopic)
      end
      parent = nextopic
    }
    parent.full_name ||= name
    return parent
  end

  ## FIXME these classes all need useful #inspect methods

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
  TOPIC_KIND = :page
  NAMESPACE_KINDS = [:REGISTRY] ## or :page TBD ..

  extend TopicRegistrantClass
  register_to(RITopicRegistry)
  def initialize (path)
    super()
    @path = path
  end
end


class ModuleTopic < NamedTopic
  TOPIC_KIND = :module
  NAMESPACE_KINDS = [:module, :REGISTRY].freeze
  ELEMENT_KINDS = [:class, :module, :constant, :method].freeze

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
  NAMESPACE_KINDS = [:module, :class, :REGISTRY].freeze
  ELEMENT_KINDS = [:method, :constant, :class].freeze

  extend TopicRegistrantClass
  register_to(RITopicRegistry)

  ## FIXME add constants storage to NamespaceTopic

  include NamespaceTopic
end

class MethodTopic < NamedTopic
  TOPIC_KIND = :method
  NAMESPACE_KINDS = [:class, :module].freeze

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
end

class ConstantTopic < NamedTopic
  TOPIC_KIND = :constant
  NAMESPACE_KINDS = [:class, :module, :REGISTRY].freeze

  extend TopicRegistrantClass
  register_to(RITopicRegistry)
end


=begin TBD
##
##
class BaseFrob
  def initialize
      puts "In BaseFrob"
  end
end

module Frob
  def self.extended(extclass)
    def extclass.initialize
      ## not reached
      puts "In Frob A"
    end
  end

  def init
    puts "In Frob.init"
  end

  def self.init2 ## this
    puts "In Frob.init2"
  end


  def self.initialize ## this works too [X]
    puts "In Frob.self.initialize (#{self.class})" ## self.class => module
  end

  protected ## DNW. Ruby still defines initialize as a private method (lame)
  def initialize
    puts "In Frob B"
  end
end

class NextFrob < BaseFrob
  extend Frob
  def initialize
    super
    puts "In NextFrob, after super"
  end
end


class OtherFrob < BaseFrob
  extend Frob
  ## does not ever reach the initialize method defined in Frob/extended
  ## or that defined in Frob
end


class LastFrob < BaseFrob
  extend Frob
  def initialize
    ## initialize is defined as a private method always, cannot call from here
    # Frob.initialize

    # Frob.init ## DNW (TBD why not)
    # Frob::init ## Also DNW ...
    Frob.init2 ## [X]
    Frob.initialize ## NB in this method, self.class = Module
    super
  end
  ## does not ever reach the initialize method defined in Frob/extended
  ## or that defined in Frob
end

module IncFrob
  def initialize
    puts "In IncFrob @ #{self.class}" ## reached
  end

  def self.included(inclass)
    def inclass.initialize
      ## not reached from FrobX#initialize
      ## is reachable as FrobX.initialize
      puts "In IncFrob.initialize @ #{self} (#{self.class})"
    end

    def inclass.mtest
      puts "in mtest"
    end
  end
end

class FrobX < BaseFrob
  include IncFrob
  ## NB
  ## FrobX.new.is_a?(IncFrob) => true
  ##   while
  ## NextFrob.new.is_a?(Frob) => false
end

##
##
=end

