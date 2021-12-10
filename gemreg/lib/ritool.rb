## ritool.rb

require 'rdoc'

## module <TBD> ...

require 'forwardable'
class StoreTool

  extend(Forwardable)
  def_delegators(:@store,*RDoc::Store.instance_methods(false))

  attr_reader :store

  def initialize(store)
    @store = store
  end
end

class GemStoreTool < StoreTool
  ## store.type => :gem

  attr_reader :spec

  def initialize(store, spec)
    super(store)
    @spec = spec
  end
end

class SystemStoreTool < StoreTool
  ## store.type => :system
end

class SiteStoreTool < StoreTool
  ## store.type => :site
end

class HomeStoreTool < StoreTool
  ## store.type => :home
end


class RITool
  def self.driver
    @driver ||= RDoc::RI::Driver.new()
  end

  def self.display_exprs(*exprs)
    ## NB any of exprs may be a regular expression
    driver.display_exprs(exprs.map { |exp| exp.to_s })
  end

  def self.display_classes(*exprs)
    ## NB can be called with an empty *exprs seq
    ##
    ## any of exprs may be a regular expression
    ## e.g display_classes("Psych::.*")
    ## or simply: display_classes("Psych")
    ##
    ## NB see [driver.rb]#list_known_classes
    driver.list_known_classes(exprs.map { |exp| exp.to_s })
  end

  ## NB @driver.stores => ...array...
  ##
  ## drv.stores.length
  ## => 17
  ##
  ## drv.stores[0].class
  ## => RDoc::Store
  ##
  ## drv.stores[0].module_names.class
  ## => Array (of strings)
  ##
  ## drv.stores[0].module_names.length
  ## => 1269 e.g
  ##
  ## drv.stores[0].path
  ## => "/usr/share/ri/3.0.0/system"
  ##
  ## drv.stores.map { |s| s.path }
  ## => ["/usr/share/ri/3.0.0/system", "/usr/share/ri/3.0.0/site", ...]
  ##
  ## drv.stores.last.class.instance_methods(false)
  ## => [...]

  ## TBD: Query API in/for rdoc's RI db (??)

  # def self.namespaces(*exprs)
  #   ## modules and classes ...
  # end

  def self.gem_store(name)
    gem = Gem::Specification.find_by_name(name)
    fn = gem.full_name

    driver.stores.find { |s|
      ( s.type == :gem ) && ( s.source == fn )
    } || raise("No RDoc storage found for gem #{name}")

  end

  def self.gem_namespaces(name)
    store = self.gem_store(name)
    store.module_names
    ## NB classes with inheritance (mixin modules and each superclass):
    ## store.ancestors => { ... }
  end

  def self.defined_classes(name)
    store = self.gem_store(name)
    store.ancestors.keys

    ## NB store.class_file(name) ... spurious results possible e.g
    ## RITool.gem_store('yard').class_file("frobject")
    ## => "/usr/lib/ruby/gems/3.0.0/doc/yard-0.9.26/ri/frobject/cdesc-frobject.ri"
    ## ... so, should only be called e.g on a mapping of store.module_names
  end

  def self.defined_modules(gem)
    store = self.gem_store(gem)
    classes = store.ancestors.keys
    names = store.module_names
    names.difference(classes)
  end

  def self.gem_cdesc_files(name)
    store = self.gem_store(name)
    store.module_names.map { |name|
      store.class_file(name)
    }
  end

  def self.gem_find_cdesc_file(gem,name)
    ## e.g RITool.gem_find_cdesc_file('yard','Object')
    store = self.gem_store(gem)
    cdesc = store.class_file(name)
    if File.exists?(cdesc)
      cdesc
    else
      raise "No cdesc found for #{name} in #{gem}"
    end
  end


  def self.gem_instance_methods_for(gem, name)
    ## e.g RITool.gem_instance_methods_for('yard','Object')
    store = self.gem_store(gem)
    methods = store.instance_methods
    if methods.key?(name)
      methods[name]
    else
      ## NB the class may or may not be defined under the gem
      raise "No instance methods defined for #{name} in #{gem}"
    end
  end

  def self.gem_class_methods_for(gem, name)
    ## e.g RITool.gem_class_methods_for('yard','YARD::CLI::Command')
    ## => ["run"]
    store = self.gem_store(gem)
    methods = store.class_methods
    if methods.key?(name)
      methods[name]
    else
      ## NB the class may or may not be defined under the gem
      raise "No class methods defined for #{name} in #{gem}"
    end
  end

end
