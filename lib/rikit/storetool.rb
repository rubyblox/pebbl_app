## storetool.rb - utility classes for query onto RDoc::Store objects

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}


require 'rdoc'

module RIKit

class QueryError < RuntimeError
end

## TBD compatability for the following, onto YARD's RI-like tooling

require 'forwardable'
class StoreTool

  ## FIXME this utility class needs a desktop UI

  ## Return an RI Driver for this class
  ##
  ## @return [RDoc::RI::Driver]
  def self.driver
    @driver ||= RDoc::RI::Driver.new()
  end

  ## Set the RI Driver for this class
  ##
  ## @param drv [RDoc::RI::Driver] the RI Driver
  ## @return [RDoc::RI::Driver] the provided driver
  def self.driver=(drv)
    @driver=drv
  end


  ## Retrieve the +:system+ RDoc Store for this Ruby environment
  ##
  ## @see system_storetool
  ## @return [RDoc::Store]
  def self.system_store
    s = driver.stores.find { |s| s.type == :system }
    if s
      return s
    else
      raise QueryError.new("No RDoc storage found with type :system")
    end
  end

  ## Retrieve a delgating SystemStoreTool for this Ruby environment
  ##
  ## @return [SystemStoreTool]
  def self.system_storetool
    @system_storetool ||= SystemStoreTool.new(system_store)
  end

  ## Retrieve the +:site+ RDoc Store for this Ruby environment
  ##
  ## @return [RDoc::Store]
  ## @see site_storetool
  def self.site_store
    s = driver.stores.find { |s| s.type == :site }
    if s
      return s
    else
      raise QueryError.new("No RDoc storage found with type :site")
    end
  end

  ## Retrieve a delgating SiteStoreTool for this Ruby environment
  ##
  ## @return [SiteStoreTool]
  def self.site_storetool
    @site_storetool ||= SiteStoreTool.new(site_store)
  end

  ## Retrieve the +:home+ RDoc Store for this Ruby environment
  ##
  ## @return [RDoc::Store]
  ## @see site_storetool
  def self.home_store
    s = driver.stores.find { |s| s.type == :home }
    if s
      return s
    else
      raise QueryError.new("No RDoc storage found with type :home")
    end
  end

  ## Retrieve a delgating HomeStoreTool for this Ruby environment
  ##
  ## @return [HomeStoreTool]
  def self.home_storetool
    @site_storetool ||= HomeStoreTool.new(home_store)
  end


  ## Retrieve an RDoc Store for this named gem in this Ruby environment
  ##
  ## @param name [String or Gem::Specification] the gem name, or a Gem
  ##  specification defining the gem
  ## @param version [String] version qualifier for the gem, used when
  ##  quering the Gem Specification cache if a string name is provided
  ## @return [RDoc::Store]
  ## @see gem_storetool
  def self.gem_store(origin, version = "> 0.0")
    if origin.instance_of?(Gem::Specification)
      ## FIXME does not check for version parity
      ## given origin.version and the provided version
      gem = origin
    else
      gem = Gem::Specification.find_by_name(origin, version) ## NB may err
    end

    fn = gem.full_name
    store = driver.stores.find { |s|
      ## FIXME fails at the rdoc gem, under one local installation via
      ## OS package manager
      ##
      ## FIXME of limited use for the rspec gem, under one local
      ## installation via the same OS package manager
      ( s.type == :gem ) && ( s.source == fn )
    }

    store || ( raise QueryError.new(
      "No RDoc storage found for gem #{origin} version #{version}"
    ))
  end

  ## Retrieve a delgating GemStoreTool for this Ruby environment
  ##
  ## @param whence [String or Gem::Specification] the gem name,
  ##  or a Gem Specification
  ## @param version [String] version qualifier for the gem,
  ##  used for the Gem Specification query if +whence+ is provided as a
  ##  string
  ## @return [GemStoreTool]
  def self.gem_storetool(whence, version = "> 0.0")
    if whence.is_a?(Gem::Specification)
      spec = whence
    else
      spec = Gem::Specification::find_by_name(whence, version)
    end

    if @gem_storetools && (st = @gem_storetools[spec.full_name])
      st
    else
      store = gem_store(spec)
      if store.source != spec.full_name
        raise new QueryError(
          "Version mismatch: source #{store.source} != #{spec.full_name}"
        )
      else
        st = GemStoreTool.new(store, spec)
      end

      if @gem_storetools
        @gem_storetools[spec.full_name] = st
      else
        @gem_storetools = {spec.full_name => st}
        st
      end
    end
  end

  extend(Forwardable)
  def_delegators(:@store,*RDoc::Store.public_instance_methods(false))

  ## The RDoc Store for this delegating instance
  attr_reader :store

  ## Initialize the instance with a provided RDoc Store
  ##
  ## @param store [RDoc::Store]
  def initialize(store)
    @store = store
  end

  ## <<Utility Methods>>

  ## Retrieve the list of class names for the RDoc Store in this
  ## delegating StoreTool
  ##
  ## *Examples*
  ##
  ## +StoreTool.system_storetool.classes(/Thread/)+
  ## +StoreTool.system_storetool.classes(/^JSON::/)+
  ## +StoreTool.gem_storetool('rdoc').classes+
  ##
  ## @param expr [Regexp or nil] If non-nil, a regular expression to
  ##   use in filtering the class names provided under the delegate RDoc
  ##   Store
  ##
  ## @return [Array of String] class names
  ##
  ## @see modules
  def classes(expr = nil)
    ## NB while there's also the delegate #all_classes method,
    ## it may not appear to be in common use
    c = @store.ancestors.keys
    return expr ? c.grep(expr) : c
  end

  ## Retrieve the list of module names for the RDoc Store in this
  ## delegating StoreTool
  ##
  ## @param expr [Regexp or nil] If non-nil, a regular expression to
  ##   use in filtering the module names provided under the delegate
  ##   RDoc Store
  ##
  ## @return [Array of String] class names
  ##
  ## @see classes
  def modules(expr = nil)
    ## NB there's also the delegate #all_modules method,
    ## though it may not appear to be in common use
    c = @store.ancestors.keys
    ns = @store.module_names
    m = ns.difference(c)
    return expr ? m.grep(expr) : m
  end


  ## NB @store.load_all => not a short call, but it populates a lot of
  ## store fields, such that would be uninitialized from the store data bootstrap
  ##
  ## e.g after load_all
  ## st.store.instance_variable_get(:@text_files_hash)
  ## => not an empty value
  ##
  ## NB @store.load_cache
  ## - is called by load_all

  def pages
    @store.cache[:pages]
  end

  ## Retrieve a sequence of cdesc files provided under the RDoc Store of
  ## this delegating StoreTool
  ##
  ## @return [Array of String] the cdesc files, as absolute pathnames
  def cdesc_files()
    ## FIXME/TBD: cdesc API under RDoc/RI ??
    ## - FIXME it would be useful if the OS package manager had intalled
    ##   RI docs for the RDoc gem installation. Failing that, 'gem install'
    ##   may serve to provide the ri docs under a latest release of rdoc
    @store.module_names.map { |name|
      @store.class_file(name)
    }
  end

  ## Retrieve the pathnanme of a cdesc file provided under the RDoc
  ## Store of this delegating StoreTool
  ##
  ## @return [String] pathname of the cdesc file
  def find_cdesc_file(name)
    ## calls store.class_file and then performs a filesystem test on
    ## that method's return value
    ##
    ## e.g
    ## StoreTool.gem_storetool('yard').find_cdesc_file("Object")
    cdesc = @store.class_file(name)
    if File.exists?(cdesc)
      cdesc
    else
      raise QueryError.new("No cdesc found for #{name} in #{self.source}")
    end
  end

  ## Retrieve a sequence of instance method names defined for a class
  ## under the RDoc Store of this delegating StoreTool
  ##
  ## * Examples *
  ##
  ## +StoreTool.system_storetool.instance_methods_for("DateTime").last+
  ## +=> "zone"
  ##
  ## +StoreTool.system_storetool.class_methods_for("Process::Sys").last+
  ## +=> "setuid"+
  ##
  ## @param name [String] the class' name
  ## @return [Array of String] instance method names
  def instance_methods_for(name)
    ## e.g
    ## StoreTool.gem_storetool('yard').instance_methods_for('Object')
    methods = @store.instance_methods
    if methods.key?(name)
      methods[name]
    else
      ## NB the named class may or may not be defined e.g in the gem or
      ## system installation
      raise QueryError.new("No instance methods defined for #{name} in #{self.source}")
    end
  end

  ## Retrieve a sequence of class method names defined for a class
  ## under the RDoc Store of this delegating StoreTool
  ##
  ## * Example *
  ##
  ## +StoreTool.system_storetool.class_methods_for("Abbrev")+
  ## +=> ["abbrev"]+
  ##
  ## @param name [String] the class' name
  ## @return [Array of String] class method names
  def class_methods_for(name)
    ## e.g
    ## StoreTool.gem_storetool('yard').class_methods_for('YARD::CLI::Command')
    ## => ["run"]
    methods = @store.class_methods
    ## FIXME StoreTool.system_storetool.class_methods
    if methods.key?(name)
      methods[name]
    else
      ## NB the named class may or may not be defined e.g in the gem or
      ## system installation
      raise QueryError.new("No class methods defined for #{name} in #{self.source}")
    end
  end

  def inspect()
    st = self.store
    "#<%s (%s %s 0x%x) 0x%x>" % [self.class, st.class, st.friendly_path, st.object_id, self.object_id]
  end
end  ## StoreTool

## TBD additional specialization for the :system, :site, and :home
## types of RDoc Store

## delegating StoreTool class for +:system+ RDoc Store type
class SystemStoreTool < StoreTool
  def initialize(store = StoreTool.system_store)
    super(store)
  end
end

## delegating StoreTool class for +:site+ RDoc Store type
class SiteStoreTool < StoreTool
  def initialize(store = StoreTool.site_store)
    super(store)
  end
end

## delegating StoreTool class for +:home+ RDoc Store type
class HomeStoreTool < StoreTool
  def initialize(store = StoreTool.home_store)
    super(store)
  end
end

## delegating StoreTool class for +:gem+ RDoc Store type
class GemStoreTool < StoreTool
  ## store.type => :gem

  ## return the name with version for the Gem defined to the RDoc Store
  ## of this deletaging instance
  alias :gem_full_name :source

  ## the cached Gem Specification for this GemStoreTool
  attr_reader :gem_spec

  ## Initialize a new GemStoreTool delegating to the specified store,
  ## for the provided Gem Specification
  ##
  ## @param store [RDoc::Store]
  ## @param spec [Gem::Specification]
  def initialize(store, spec)
    super(store)
    @gem_spec = spec
  end

  ## return the Gem name for this GemStoreTool
  ##
  ## @return [String] the Gem's name without qualifier for
  ##  the Gem's version, as a string
  ##
  ## @see gem_version
  ## @see gem_full_name
  def gem_name()
    @gem_spec.name
  end

  ## return the Gem version for this GemStoreTool
  ##
  ## @return [String] the version expression, as a string
  ##
  ## @see gem_name
  ## @see gem_full_name
  def gem_version()
    @gem_spec.version.version
  end
end

end ## RIKit module

=begin TBD - parsing an rdoc cdesc file with Marshal.load & subsq

str = File.read "#{ENV['HOME']}/.local/share/gem/ruby/3.0.0/doc/rdoc-6.3.3/ri/RDocTask/cdesc-RDocTask.ri"
obj = Marshal.load str

obj.class
=> RDoc::NormalClass
^ NB the format's visual representation does not provide a very clear
  distinction of class and instance methods, displaying all of those in
  the same methods list. (FIXME)

obj.class.instance_method(:inspect).source_location
=> ["/usr/lib/ruby/gems/3.0.0/gems/rdoc-6.3.1/lib/rdoc/normal_class.rb", 39]
^ TBD patching RDoc to store source locations in the cdesc/method/... marshal data

obj.method_list
=> <<Array of RDoc::AnyMethod>>

obj.method_list[0].visibility
=> :public

obj.method_list[0].file_name
=> <pathname relative to the gem's home>

obj.method_list[0].name
=> "new"

obj.method_list[0].singleton
=> true
# i.e in this context, it's a class method, as the
# obj.method_list[0].parent_name denotes a class

obj.method_list[10].name
=> "rdoc_target"

obj.method_list[10].singleton
=> false ## i.e an instance method

=end

