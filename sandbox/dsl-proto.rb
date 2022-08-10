 # DSL classes, Options DSL, Tests (sandbox)

require 'dry/core/class_builder'
require 'dry/validation'



## Generic base class for definition of domain-specific languages
## extending the Ruby programing language
##
## - generally inspired by Dry::Schema, Dry::Validation, and Mixlib::Config
class DslBase

  class << self

    include PebblApp::ScopeUtil

    ## @!group DSL API methods

    ## @!group Naming for DSL Components

    def component_name?()
      instance_variable_defined?(:@component_name)
    end

    def component_name()
      if component_name?
        @component_name
      else
        msg = "No component_name registered for #{self}"
        raise RuntimeError.new(msg)
      end
    end

    def register_component_name(name)
      if component_name?
        msg = "component_name %p already registered for %s" % [
          component_name, self
        ]
        ArgumentError.new(msg)
      else
        @component_name = name
      end
    end

    ## @!endgroup

    ## Return a hash table representing the set of DSL component classes
    ## defined for this class.
    ##
    ## Each key in this table will represent a component name, such as
    ## provided to the `dsl` method. The value for that key will
    ## represent the DSL component class for the component name.
    ##
    ## Each component class may or may not represent a subclass
    ## of this class, and may be defined without registration in the
    ## namespace of Object constants.
    ##
    ## @note The value returned by this method will not be inherited by
    ## subclasses
    ##
    ## @see dsl for defining DSL classes within a scoped block
    ##
    ## @see define for defining DSL classes within a scoped block and
    ##  without registration to the containing DSL class' _contained_
    ##  list
    ##
    ## @see [] for accessing an individual DSL component class
    ##
    def contained
      svar_bind(:@contained) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "DSL name not found in #{self}: #{name.inspect}"
          )
        end
      end
    end

    ## Return a DSL component class for a provided DSL component name
    ##
    ## @param name [Symbol] a DSL component name
    ## @return [Class] a DSL component class
    ## @raise [ArgumentError] if no component class is found for the
    ##  provided name
    ## @see contained for retrieving the set of named component classes
    ##  for a DSL class
    def [](name)
      contained[name.to_sym]
    end

    ## Return the base class for this DSL class
    ##
    ## If this class represents a top-level DSL class, the base class
    ## will be the class itself
    ##
    ## @see contained for retrieving the set of named component classes
    ##  for a DSL base class
    def __scope__()
      if instance_variable_defined?(:@__scope__)
        instance_variable_get(:@__scope__)
      else
        self
      end
    end

    ## @param base [Class] the base class for this DSL class
    def register_scope(scope)
      if instance_variable_defined?(:@__scope__)
        raise RuntimeError.new("__scope__ is already defined for #{self}: #{__scope__.inspect}")
      else
        STDERR.puts("[DEBUG] register_scope for #{self.inspect} : #{scope.inspect}")
        if instance_variable_defined?(:@component_name)
          scope.contained[self.component_name] = self
        else
          scope.contained[self] = self
        end
        instance_variable_set(:@__scope__, scope)
      end
    end

    ## Define or return a DSL class or a DSL component, registering the
    ## definition to its containing context.
    ##
    ## When evaluated at the source top level, this method may be
    ## applied for defininig a top-level DSL class as to be registered
    ## under the class of the call to the topmost class' `dsl` method.
    ##
    ## When evaluated within a DSL class expression, this method will
    ## define and register a DSL component definition to the containing
    ## DSL class expression.
    ##
    ## @note As an alternative to `dsl` at the top level, the `apply`
    ##  method may be used to begin a DSL class expression. Subsequently,
    ##  within the block of the expression, the `dsl` method may be
    ##  used to define any named DSL components to the containing
    ##  DSL definition.
    ##
    ## @note **Method Scope:** For any block provided to this method,
    ##  the block will be evaluated with the new DSL class as the scoped
    ##  `self`.
    ##
    ## @note **Class Names and the Object Namespace:** In effect, the
    ##  class returned by this method will represent an anonymous
    ##  class. The class' name will be available via a singleton `name`
    ##  method and will be visible as the class' effective name under
    ##  a printed representation of the class. However, the class' name
    ##  will not be initialized as a constant under the Object
    ##  namespace.
    ##
    ##  The set of component classes to a DSL definition may be accessed
    ##  with the `components` method or individually with the `[]` method
    ##  on the containing DSL class.
    ##
    ##  The class may also be accessed via the `subclasses` method on the
    ##  provided base_class. However, it cannot be guaranteed that any
    ##  two subclasses will have distinct names within the subclasses
    ##  list, for any two anonymous classes defined with this method.
    ##
    ## @example
    ##   eg_dsl = DslBase.define() do
    ##
    ##     # Each DSL instance must respond to an instance method, `applied`
    ##     define_method(:applied) do |component|
    ##       puts "Applied: #{__scope__} => #{component}"
    ##     end
    ##
    ##     dsl(:component_a) do
    ##       # In this example, the Component_a class will be defined
    ##       # as a subclass of the containing DSL class. Thus,
    ##       # the class will inherit the `applied` method defined
    ##       # in its effective base class.
    ##
    ##       def class_method(arg)
    ##         puts "A => #{arg.inspect}"
    ##       end
    ##     end
    ##
    ##     dsl(:component_b) do
    ##       dsl_method(:inst_method) do |arg|
    ##         puts "b => #{arg.inspect}"
    ##         return self
    ##       end
    ##     end
    ##   end
    ##
    ##   example = eg_dsl.apply(:a)
    ##   => #<Example 0x008df4 a>
    ##
    ##   example.component_b(:b).inst_method("...")
    ##   >> Applied: #<Example 0x008df4 a> => #<Component_b 0x008e08 b>
    ##   >> b => "..."
    ##   => #<Component_b 0x008e08 b>
    ##
    ## @param name [Symbol] The DSL component name for the class, or
    ## top-level DSL name if the class will be defined as a top-level DSL
    ##
    ## @param class_name [String] The DSL class name for the class. This
    ## class name will be applied via Dry::Core::ClassBuilder and will
    ## be generally visible in the singleton scope. The class_name will
    ## not be initialized as a constant under the Object constants
    ## namespace.
    ##
    ## @param base_class [Class] the base class for the definition of
    ##  the component class. If a singleton class is provided, the first
    ##  non-singleton class in the class' `ancestors` will be used as
    ##  the effective superclass.
    ##
    ## @param cb [Proc] optional callback. If provided, the callback
    ##  will be evaluted with the DSL class as the scoped `self`
    ##
    ## @return [Class] the defined DSL class
    ##
    ## @see define for defining a DSL class without registration to the
    ##  containing class' _contained_ list
    ##
    ## @see dsl_methods for defining a DSL method within a DSL class
    ##  expression, such that the method will be evaluated at instance
    ##  scope when called under apply
    def dsl(name, class_name: to_class_name(name),
            base_class: nil, &cb)
      base_class ||= self
      syname = name.to_sym

      if (contained.include?(syname))
        cls = contained[syname]
        msg = false
        if ! base_class.eql?(cls.superclass)
          msg = "Incompatible base_class provided for existing %p class %s: %p" % [
            syname, cls, base_class
          ]
        elsif ! (class_name == cls.name)
          msg = "Incompatible class_name provided for existing %p class %s: %p" % [
            syname, cls, class_name
          ]
        elsif ! (name == cls.component_name)
          msg = "Incompatible component name provided for existing %p class %s: %p" % [
            syname, cls, name
          ]
        elsif (self != (cscope = cls.__scope__))
          msg = "Existing component class %p => %s has incompatible scope %p" % [
            syname, cls, cscope
          ]
        end
        raise ArgumentError.new(msg) if msg
      else
        ## deferring evaluation of the callback until after the class'
        ## scope is set
        cls = self.define(class_name, base_class: base_class)
        cls.register_component_name(name)
        cls.register_scope(self)
      end
      cls.instance_eval(&cb) if cb
      return cls
    end

    ## Initialize and return a new DSL, without registering the DSL to
    ## the implementing class
    ##
    ## @param name (see dsl)
    ##
    ## @param base_class (see dsl)
    ##
    ## @see dsl for evaluation of a named DSL class expression
    ##
    ## @see dsl_methods for defining a DSL method within a DSL class
    ##  expression, such that the method will be evaluated within an
    ##  instance scope when called under apply
    ##
    def define(name = nil, base_class: nil, &cb)
      ## NB this does not register the new class to the base_class
      base_class ||= self
      name ||= (to_class_name(base_class.name) + "Model")
      if base_class.singleton_class?
        ## The first ancestor not the singleton class would provide a
        ## non-singleton class, such that this non-singleton class has
        ## base_class as its singleton class.
        ##
        ## This may be applicable whether the base_class is a singleton
        ## class of a class or is a singleton class of some non-class
        ## object.
        ##
        ## If a singleton class of a non-class object, the new class
        ## will be defined as a subclass of that object's class.
        ##
        ## As the new class will not be available under the Object
        ## constants namespacem, this will not ovewrtie any existing
        ## class of the same name.
        ##
        impl_class = base_class.ancestors[1]
      else
        ## base_class is not a singleton class
        impl_class = base_class
      end
      builder =
        Dry::Core::ClassBuilder.new(name: name, parent: impl_class)
      ## NB this differs significantly to the behaviors and side effects
      ## if providing the callback directly to the Dry class builder.
      ##
      ## In the following approach, then in order for the callback to
      ## access the class it's being called for - rather than using an
      ## arg to hold the class - the class can be accessed as 'self' in
      ## the scope of the callback.
      ##
      ## Methods defined under this approach will have a coresponding
      ## scope, contrasted to if the callback was provided directly to
      ## the Dry class builder
      if cb
        blk = proc { |subclass| subclass.instance_eval(&cb) }
        builder.call(&blk)
      else
        builder.call
      end
    end


    ## Create and return a new instance of this DSL class
    ##
    ## @note Initailization for the instance will be deferred until
    ##  after the __scope__ for the instance has been set via
    ##  initialize_scope.
    ##
    ## @note For a DSL instance initialized with this method, the
    ##  __scope__ of the instance will be set as the instance itself. This
    ##  may be construed as indicating that the instance is a top-level
    ##  DSL instance. This would be contrasted to the __scope__ value
    ##  set from any a component method, such that the value would
    ##  represent the containing scope for the component instance.
    ##
    ## @note Before return, each DSL component method and each DSL
    ##  instance method for this DSL class will be defined as a
    ##  singleton method on the instance, via `initialize_methods`
    ##
    ## @see dsl for definiing a DSL class to be registered within a
    ##  containing base class.
    ##
    ## @see define for defining a DSL class without registration in a
    ## containing base class
    ##
    ## @see dsl_methods for declaring a method to be defined for a
    ##  DSL instance, such that the method will be available within a
    ##  singleton scope to the instance, subsequent of a call to `apply`
    ##
    ## @param args [Array] arguments for the constructor method
    ##
    ## @param block [Proc] optional block. If provided, this block will
    ##  be evaluated in a scope with the initialized instance as the
    ##  scoped `self` in the call
    ##
    ## @return [DslBase] a new DSL instance
    ##
    def apply(*args, &block)
      inst = self.send_wrapped(self, :new, *args)
      initialize_scope(inst, inst) ## root object
      initialize_methods(inst)
      inst.accept_block(&block) if block
      inst.applied(inst)
      return inst
    end


    ## Return the hash table of DSL methods defined for this class
    ##
    ## @note The hash table will be used for purposes of API
    ##  definition during the apply method. When a DSL instance of this
    ##  class is initialized with apply, then for each DSL method
    ##  represented in this table, a singleton method will be defined on
    ##  the initialized instance. For each method defined with
    ##  dsl_method within the scope of a DSL class expression, the
    ##  method's block will be evaluated at an instance scope.
    ##
    ## @return [Hash] a hash table pairing each method name with the
    ##  block form provided in the method's initial definition
    def dsl_methods
      svar_bind(:@dsl_methods) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "DSL method not found in #{self}: #{name.inspect}"
          )
        end
      end
    end

    ## Return true if the provided name represents a method derfined as
    ## a dsl_method in this class
    ##
    ## @param name (see dsl_method)
    ## @return [boolean] a boolean value
    def dsl_method?(name)
      dsl_methods.include?(name.to_sym)
    end

    ## Define a DSL isntance method such as for application under
    ## apply. The method's block will be evaluated within the scope of
    ## an initialized DSL object.
    ##
    ## This method is defined as a utility for instance method
    ## definition within dsl expressions
    ##
    ## @note The actual method defined for each dsl_method will be
    ##  defined as a singleton method on each instance created under
    ##  `apply`. As such, each dsl_method will not be inherited by
    ##  subclasses. This behavior may be subject to adaptation in some
    ##  later revision of this API - such as to support an additional
    ##  'inherit' arg, to be handled under orchestration with an
    ##  `inherited` method on this class. (FIXME)
    ##
    ## @note Any method defined with dsl_method in effect will shadow
    ##  any existing instance method of the same name, when defined under
    ## `apply`. This behavior may be subject to adaptation in a later
    ##  revision of this API, such as to add an additional `shadow`
    ##  keyword arg to indicate (when false) that no DSL method should
    ##  be defined if it would override an instance method on the
    ##  initialized instance. (FIXME)
    ##
    ## @param name (see smethod_define)
    ## @param block (see smethod_define)
    ## @return [Proc] the block that will be applied for the method's
    ##  definition
    ## @see dsl
    ## @see define
    ## @see apply
    def dsl_method(name, &block)
      name = name.to_sym
      dsl_methods[name.to_sym] = block
    end

    ## @!endgroup

    ##
    ## @!group Utility methods
    ##

    ## Compute a default class name for the component name of a DSL
    ## component class
    ##
    ## @param name [String] the DSL component name
    ##
    ## @return [String] a string that may be used as a class name
    ##
    ## @see to_component_name
    def to_class_name(name)
      sname = name.to_s
      c = sname.split(/[[:punct:]]+/.freeze)
      c.shift if c.first.empty?
      return c.map { |elt| elt[0].upcase + elt[1...] }.join
    end

    ## Compute the component name of some DSL component class' name
    ##
    ## @param name [String] a DSL class name
    ## @return [Symbol] a component name, as a symbol
    ##
    ## @see to_class_name
    ##
    def to_component_name(name)
      last = name.split(/::/).last
      PebblApp::NameUtil.flatten_name(last).to_sym
    end

    ## @private
    ## Initialize an instance varible for the __scope__ on the
    ## provided instance
    def initialize_scope(inst, scope)
      inst.instance_variable_set(:@__scope__, scope)
    end

    ## @private
    ## send a provided set of args to a method on an object
    ##
    ## If the last object in the args sequence is a hash value, the
    ## value will be interpreted as providing an options list for the
    ## receiving method. Otherwise, the args sequence will be passed to
    ## the receiving method without adaptation.
    ##
    ## @param inst [Object] a receiving instance
    ## @param mtd [Symbol] a method name on the receiving instance
    ## @param args [Array] args for the receiving method
    ## @return [Object] return value from the receiving method
    def send_wrapped(inst, mtd, *args)
      mobj = inst.method(mtd)
      if Hash === (last = args.last)
        args = args[...-1]
        mobj.call(*args, **last)
      else
        mobj.call(*args)
      end
    end

    ## @private
    ## For a single instance of this DSL class, then for each DSL
    ## component kind defined to this DSL class, define a method on
    ## the instance's singleton class for the component name.
    ##
    ## For each component method defined with this procedure, the
    ## component method will initialize an instance of the component
    ## class, using all args provided to the method at the time of
    ## call. For any block provided to the component method, the block
    ## will be called under instance_eval with the initialized instance
    ## as the block's `self` scope.
    ##
    ## For each DSL component initialized with a component method, the
    ## component instance will receive a call to set the @__scope__ on
    ## the component as the containing instance for which the component
    ## was initalized. The component's constructor will not be called
    ## until after the @__scope__ has been set on the component instance.
    ##
    ## Lastly, the component method will call the `applied` method on
    ## the instance of this DSL class, with the new component instance
    ## provided as an argument in the call.
    ##
    ## This method is used generally for scoped evaluation under `apply`
    ##
    ## @see apply for initializing a DSL instance
    ##
    ## @see contained which provides the set of component classes to a
    ##  DSL class.
    ##
    def initialize_methods(inst)
      self.contained.each do |dslname, cls|
        ##
        ## for each dslname in contained.keys, define a class method
        ## that will initialize a scoped instance of the corresponding
        ## class
        ##
        smethod_define(dslname, inst) do |*args, &block|
          sub = cls.send_wrapped(cls, :new, *args)
          cls.initialize_scope(sub, inst)
          cls.initialize_methods(sub)
          sub.accept_block(&block) if block
          inst.applied(sub)
          return sub
        end
      end
      self.dsl_methods.each do |mtdname, cb|
        smethod_define(mtdname, inst, &cb)
      end
    end

    ## @!endgroup
  end ## class << DslBase

  ## return the scope of this DSL object
  ##
  ## If this is a top-level DSL object, this method should return the
  ## object itself
  ##
  attr_reader :__scope__

  def accept_block(&cb)
    self.instance_eval(&cb) if cb
  end

  ## @!method applied(component)
  ## handle some component object initialized for a scoped instance
  ## as under self.class.apply
  ##
  ## @abstract This method should be defined in any implementing class
  ##
  ## @param instance [DslBase] a DSL component object
  ##
  ## @see DslBase.apply

end


##
## Mixins and protocol classes
##

require 'dry/schema'

## @see CompilerResult
class OptionWarning
  attr_reader :option, :feature, :message

  def initialize(option, feature, message)
    @param = option
    @feature = feature
    @message = message
  end
end

## Utility class for Option#compile
##
class CompilerResult
  attr_reader :contract, :profile

  def initialize(contract, profile, defer_warnings: ! $DEBUG)
    @contract = contract
    @profile = profile
    @defer_warnings = defer_warnings
  end

  def defer_warnings?
    @defer_warnings
  end

  def warnings()
    @warnings ||= Array.new
  end

  def push_warning(profile, option, feature, message)
    w = OptionWarning.new(option, feature, message)
    self.warnings.push(w)
   if ! self.defer_warnings?
     Kernel.warn("%s option %s (%s) : %s" % [profile, option, feature, message],
                 uplevel: 1)
   end
   return w
  end
end

##
## a general example, short of the OptionGroup API
##

class NamedTestModel < DslBase
  attr_reader :name, :nodes

  def initialize(name)
    super()
    @name = name
    @nodes = Array.new
  end

  def to_s
    sname = (@name || "(anonymous)")
    "#<%s 0x%06x %s>" % [ self.class, __id__, sname ]
  end

  def inspect
    self.to_s
  end

  def applied(node)
    puts "Applied: #{__scope__.name} => #{node}"
    ## trivial storage
    self.nodes << node
  end

end

$EG_MODEL = NamedTestModel.define("Example") do
  # include Named

  ## define an instance method for this DSL class,
  ## within the scope of a DSL class expression
  define_method(:tbd) do |arg|
    puts "tbd: #{__scope__} / #{self} : #{arg}"
  end

  dsl(:component_a) do
    def class_method_a(arg)
      puts "A => #{arg.inspect}"
    end
  end

  dsl(:component_b) do
    dsl_method(:inst_method_b) do |arg|
      puts "b => #{arg.inspect}"
      return self
    end
  end
end


## $EG_MODEL[:component_a].__scope__.eql?($EG_MODEL)
# => true

## $EG_MODEL.apply(:a).singleton_methods(false)
# => [:component_a, :component_bb]

## $EG_MODEL.apply(:a).singleton_methods(false)

## $EG_MODEL[:component_b].dsl_methods
# => {:inst_method_b=>#<Proc:0x0000000806ae63a8 sandbox/dsl-proto.rb:...>
## ^ should not be empty

## $EG_MODEL.apply(:a).component_b("b").singleton_methods(false)
# => [:inst_method_b]
## ^ shold not be empty

## $EG_MODEL.apply(:a).component_b("b").inst_method_b("...")
# >> b => "..."
# => #<Component_b 0x004b14 b>

$EG = $EG_MODEL.apply("e.g") do component_a("a"); component_b("b"); end

# $EG.nodes
## => [#<ComponentA 0x002e7c a>, #<ComponentB 0x002e90 b>]

# $EG.nodes.first.nodes
## => []

##
## OptionGroup API
##

require 'mixlib/config'

## Base class for DSL definitions in the OptionGroup API
class OptionBase < DslBase

  def initialize(name = false, **options)
    super(**options)
    @name = name if name
  end

  class << self
    def to_component_name(name)
      if (String === name)
        name.to_sym
      else
        ## symbol, other
        name
      end
    end
  end ## class << OptionBase

  ## @see name
  def named?()
    self.instance_variable_defined?(:@name) ||
      self.class.component_name?
  end

  ## @see named?
  ## @:raise ...
  def name
    if self.instance_variable_defined?(:@name)
      @name
    elsif self.class.component_name?
      self.class.component_name
    end
  end

  def to_s
    sname = named? ? name : "(anonymous)"
    "#<%s 0x%06x %s>" % [ self.class, __id__, sname ]
  end

  def inspect
    self.to_s
  end

end ## OptionBase


## DSL class for Option definitions within an OptionGroup model
class Option < OptionBase

  class << self
    def initialize_methods(inst)
      super(inst)
    end
  end

  def initialize(name, optional: true)
    super(name)
    @optional = optional ? true : false
  end

  ## Return true if this Option has been defined as _optional_ in
  ## the containing OptionGroup
  ##
  ## @return [boolean]
  def optional?
    @optional
  end

  def schema_feature?
    defined?(@schema)
  end

  def schema_feature
    if schema_feature?
      @schema
    else
      raise RuntimeError.new("No schema syntax defined for #{self}")
    end
  end

  ## @return [Hash] hash table of features
  ##
  ## @see feature?
  ## @see []
  def features
    @features ||= Hash.new do |_, kind|
      raise ArgumentError.new("Feature not found for #{self}: #{kind.inspect}")
    end
  end

  ## Return true if a feature has been applied for the provided kind
  ##
  ## @param kind [symbol]
  ## @return [boolean]
  ## @see features
  ## @see []
  def feature?(kind)
    features.include?(kind)
  end

  ## @param kind [symbol]
  ## @return [Feature]
  ## @raise [ArgumentError] if no feature has been applied for the
  ##  provided kind
  ## @see feature?
  ## @see features
  def [](kind)
    features[kind]
  end

  ## Register a feature as applied for this Option
  ##
  ## @param feature [Feature] the feature that has been applied
  ##
  ## @return [Feature] the applied feature
  ##
  ## @raise [RuntimeError] if a feature of the same feature kind has
  ##  already been applied for this Option
  ##
  ## @see DslBase.apply
  ##
  def applied(feature)
    if (name = feature.name)
      if (name == :schema)
        if defined?(@schema)
          raise RuntimeError.new("Schema sytntax already defined for #{self}")
        else
          @schema = feature
        end
      elsif self.feature?(name)
        msg = "Feature already exists for name %p in %s" % [
          name, self
        ]
        raise RuntimeError.new(msg)
      else
        ## define a singleton method for this feature, to return the
        ## initialized instance of this feature
        ##
        ## typically this would ovwerite any feature constructor method
        ## defined under DslBase.apply

        self.define_singleton_method(name) do
          feature
        end

        self.features[name] = feature
      end
    else
      STDERR.puts ("[DEBUG] applied anonymous feature #{feature} @ #{self}")
    end ## name
    return feature
  end

  def compile_schema(group, schema_dsl, results)
    if schema_feature?
      sch = schema_feature
    else
      sch = SchemaFeature.new
      results.push_warning(group, self.name, :schema,
                           "No schema syntax defined")
    end
    sch.compile(self, group, schema_dsl, results)
  end

  def compile_features(group, contract, results)
    optname = self.name
    self.features.each do |_, feature|
      feature.compile(self, group, contract, results)
    end

    store = group.config_store

    catch(:define) do |tag|
      if (rd_mtd = store.singleton_method(optname))
        rd_lmb = lambda { group.compile; rd_mtd.call(); }
        group.class.smethod_define(optname, group, &rd_lmb)
      else
        results.push_warning(group, optname, :reader,
                             "No reader method for #{opname} in backing store")
        throw tag
      end

      wr_name = (optname.to_s + "=").to_sym
      if (wr_mtd = store.singleton_method(wr_name))
        wr_lmb = lambda { |value|
          self.compile; wr_mtd.call(value)
        }
        group.class.smethod_define(wr_name, group, &wr_lmb)
      else
        results.push_warning(group, optname, :writer,
                             "No writer method for #{opname} in backing store")
        throw tag
      end
    end

  end


end

## Option Feature base class
##
## @abstract
##
## @see DslBase.dsl for producing a named top-level DSL class expression
##  or a component DSL class expression within some top-level DSL
##
## @see DslBase.define for defining an anonymous DSL class expression
##
## @see DslBase.apply for applying a DSL class expression to produce an
##  instance of a provided DSL class
##
## @see Schema (required) for defining a Dry::Schema expression to a
## Option
##
## @see Rule (optional) for defining a Dry::Validation rule to Option
## (will be applied under `validate` for an object initialized from a
## DSL class - FIXME move this to the docs for Rule)
##
## @see OptionDefault (optional) for defininig a default value to a
##  Option
##
## @see ShellOption (optional) for defining a command line argument
##  parser for a Option [FIXME add method]
class Feature < OptionBase

  alias_method :option, :__scope__

  attr_reader :callback

  def callback?
    @callback ? true : false
  end

  def accept_block(&cb)
    STDERR.puts"accept_block in #{self}"
    ## protocol method, via DslBase.dsl
    ##
    ## receives a block from a DSL class expression.
    ## see other implementation: DslBase#accept_block
    callback(&cb)
  end

  def callback_proc
    @callback
  end

  def callback_eval(scope)
    scope.instance_eval(&@callback) if @callback
  end

  def callback(&block)
    if callback?
      raise ArgumentError.new("Callback already bound for #{self}")
    else
      @callback = block
    end
  end

  def to_s
    begin
      scopename = self.__scope__.name
    rescue
      scopename = "(unscoped)"
    end
    sname = named? ? name : "(anonymous)"
    "#<%s 0x%06x %s %s>" % [ self.class, __id__, scopename, sname ]
  end
end

## Option Feature class for option schema features
##
## @see compile
class SchemaFeature < Feature

  ## @private
  ##
  ## This method serves a callback for schema defintion in a context of
  ## Dry::Schema and Dry::Validation
  ##
  ## This method will be called on the SchemaFeature defined to each
  ## Option within an OptionGroup.
  ##
  ## @param option [Option] the Option definition represented by this
  ##  schema feature defintion
  ##
  ## @param group [OptionGroup] the OptionGroup for the provided Option
  ##
  ## @param dsl [Dry::Schema::DSL] Schema DSL for the active schema
  ##  definition in the OptionGroup
  ##
  ## @results [CompilerResult] Storage for warnings during compile
  ##
  ## @see OptionGroup#compile
  def compile(option, group, dsl, results)
    optname = option.name
    if option.optional?
      macro = dsl.optional(optname)
    else
      macro = dsl.required(optname)
    end
    if self.callback?
      self.callback_eval(macro)
    else
      results.push_warning(group, optname, :schema,
                           "No schema callback defined")
    end
  end
end

## Option Feature class for option rule features
##
## @see compile
class RuleFeature < Feature

  ## @private
  ##
  ## Callback method for defining an option validation rule
  ## with Dry::Validation
  ##
  ## @see OptionGroup#compile
  def compile(option, group, contract, results)
    optname = option.name
    if self.callback?
      if option.optional?
        ## r: storage for this rule, available when 'self' will have a
        ## different scope than in this method block
        r = self
        contract.rule(optname) do
          ## This block will be scoped to the evaluation of a Dry
          ## Validation rule. Dry::Validation::Evaluator === self
          ##
          ## The 'key?' method, here, should return a non-falsey value
          ## when the given option name is present in some input value
          ## to be validated.
          ##
          ## For optional values, this provides an initial check to
          ## ensure that the callback should not be called if the
          ## option is not present in the input value. This may serve
          ## to minimize some coding, when defininig a validation rule
          ## for an optional option value.
          ##
          ## If the option is present but was provided with a nil or
          ## false value, the callback should still be called here
          ##
          ## Callbacks should be able to call the 'value' method
          ## in this scope, to access the option's value from within
          ## the callback.
          ##
          r.callback_eval(self) if key?(optname)
        end
      else
        ## a required option value. This will always dispatch to the
        ## callback, within a Dry::Validation::Contract rule
        contract.rule(optname, & self.callback_proc)
      end
    else
      ## no callback, though a 'rule' feature was provided
      results.push_warning(group, optname, self.name,
                           "Rule defined with no callback")
    end
  end
end

## Option Feature class for default value callbacks and literal default
## values
##
## **Initialization and Setting a Default Value**
##
## An **OptionDefault** can be initialized to an **Option** within a DSL
## **option** expression, using the method `default`.
##
## If a constant default value will be used for the containing
## **Option** definition, the value may be provided with the
## `default_value` keyword argument to the `default` method.
##
## If a block is provided to the `default` method, the block will
## be called with no arguments, to provide a default value for the
## containing parameter. This block will override any provided
## `default_value`.
##
## The `default` method will be avaialble within a singleton
## scope, within a DSL `option` expression.
##
## Any default value or default callback will be used under the `apply`
## method for the containing Option.
##
## If no `default` is provided to the `option` expression, it will
## be assumed that the `option` has no default value.
##
## @see Option
class OptionDefault < Feature

  def initialize(**options)
    if options.include?(:default_value)
      @default_value=options[:default_value]
    end
  end

  ## return the default value for this profile feature
  def default_value()
    if self.instance_variable_defined?(:@default_value)
      @default_value
    elsif (cb = self.callback_proc)
      @default_value = cb.yield
    else
      false
    end
  end

  ## @private
  ##
  ## Callback method for defining a default option value under
  ## OptionGroup#compile and OptionGroup#validate methods
  ##
  ## This method uses Mixlib::Config under the provided option
  ## group
  ##
  ## @see OptionGroup#compile
  def compile(option, group, contract, results)
    optname = option.name
    store = group.config_store
    if defined?(@default_value)
      store.default(optname, @default_value)
    elsif defined?(@callback)
      store.default(optname, & @callback)
    else
      results.push_warning(group, optname, self.name,
                           "No default value or callback was provided")
    end
  end
end ## OptionDefault class

## Encapsulation for applications of Mixlib::Config in an OptionGroup
## instance scope
module OptionConfig
  ## This method extends Mixlib::Config, for customization in
  ## OptionGroup instance configuration
  def self.extended(whence)
    whence.extend Mixlib::Config
    whence.config_strict_mode true
  end
end

class ConfigStore
  def initialize()
    ## ensure that all singleton methods form Mixlib::Config
    ## will be available at an instance scope
    self.extend OptionConfig
  end
end

## Base class of a Configuration Options Model for Desktop Applications
class OptionGroup < OptionBase
  class << self

    ## Initialize the DSL for this OptionGroup
    def model()
      ## using an instance variable at class scope, for storage of the
      ## self-referential @model value.
      ##
      ## In effect, the @model value indicates that this DSL class has
      ## been defined.
      if instance_variable_defined?(:@model)
        @model
      else
        dsl(:option, base_class: Option) do
          ## This option DSL class is later accessible in a profile definition
          ## as e.g OptionGroup[:base_conf][:option]
          ##
          ## In a profile instance <i>.options[<name>] => option
          ## with option methods: 'schema', 'rule', 'default'

          ## each DSL class is in effect an anonymous class,
          ## and defined with a singleton name via Dry::Core::ClassBuilder
          ##
          ## for any DSL class, the class.name method itself would return
          ## the name as defined with Dry::Core::ClassBuilder
          ##
          ## TBD accessing the structural name of the class, within Ruby,
          ## it being an anonymous class with a singleton name

          dsl(:schema, base_class: SchemaFeature) do
            ## define the option's schema
            ##
            ## in application: Required field.
            ##
            ## any callback defined in the :schema profile field
            ## will be evaluated in the scope of a Dry::Schema
            ## schema DSL
          end

          dsl(:rule, base_class: RuleFeature) do
            ## define a validation rule for the option.
            ##
            ## in application: This is an optional field,
            ##
            ##
            ## any callback defined in the :rule profile field
            ## will be evaluated in the scope of a Dry::Validation
            ## schema rule DSL
          end

          dsl(:default, base_class: OptionDefault) do
            ## define a default value initializer for the option
            ## for application with Mixlib::Config
            ##
            ## In application: This API supports options without an explicit
            ## default binding. The value 'false' will be used if no literal
            ## value or callback is provided under a field's default
            ##
            ## any callback defined in the :optional_default profile field
            ## will be evaluated in a normal instance scope for a profile
            ## instance
          end

        end ## dsl(:option) ...
        ## using 'self' as the model, towards retaining a model/instance alignment
        @model = self
      end ## if ...
    end  ## def model
  end ## class << OptionGroup

  ## Return the ConfigStore
  ##
  ## This value is used for Mixlib::Config support in each OptionGroup
  ##
  ## @return [ConfigStore]
  ## @private
  attr_reader :config_store

  ## Return the latest CompilerResult for validation of this OptionGroup
  ##
  ## Returns nil if this OptionGroup has not been successfully
  ## validated
  ##
  ## @see validate
  ## @see compile
  ## @see recompile
  attr_reader :compiler_result

  def initialize(name)
    super(name)
    ## Integration for Mixlib::Config
    ##
    ## @config_store should not be changed on the instance, once set
    store = ConfigStore.new
    @config_store = store
    self.extend Forwardable
    ## define forwarding for some singleton methods from Mixlib::Config
    ## - this API does not provide interop. for Mixlib::Config contexts
    %w(configuration configuration= configurables).each do |mtd|
      self.def_delegator(:@config_store, mtd)
    end
  end

  def applied(dsl)
    if Option === dsl
      name = dsl.name
      STDERR.puts("[DEBUG] adding #{self} option #{name} => #{dsl}") ## if $DEBUG
      self.options[name] = dsl
    elsif ! (self.eql?(dsl))
      raise ArgumentError.new("Uknown instance type: #{dsl}")
    end
  end

  ## Return the schema for the validation contract to this OptionGroup
  ##
  ## @return [Dry::Schema] the schema
  ##
  ## @see #contract
  ## @see #compile
  ## @see #recompile
  def schema
    self.contract.schema
  end

  ## Return the Dry::Validation rules for the validation contract to
  ## this OpitonGroup
  ##
  ## @return [Array<Dry::Validation::Rule>]
  ##
  ## @see #contract
  ## @see #compile
  ## @see #recompile
  def rules
    self.contract.rules
  end

  ## Compile and return the Dry Validation Contract for this OptionGroup
  ##
  ## @return [Dry::Validation::Contract]
  ##
  ## @see #compile
  ## @see #recompile
  def contract
    ## 'compile' will process all DSL data presently supported under the
    ## 'compile' method in the implementing class - i.e schema,
    ## validation rules, defaults, etc - at most once. See also recompile
    self.compile
    @contract
  end

  ## Recompile the Dry Validation Contract for this OptionGroup
  ##
  ## @return [CompilerResult]
  ##
  ## @see #contract
  ## @see #compile
  def recompile
    previous_class = @contract
    previous_instance = @contract_validate
    @contract = nil
    @contract_validate = nil
    @compiler_result = nil
    begin
      compile
    rescue
      @contract = previous_class
      @contract_validate = previous_instance
      raise
    end
  end

  ## Return a hash table representing all options configured for this
  ## OptionGroup
  ##
  ## @param defaults_p [boolean] If a truthy value, the return value will
  ##  include any default option values defined under the model for this
  ##  OptionGroup. If a falsey value, the return value will include only
  ##  the values that have been directly set for this OptionGroup
  ##
  ## @return [Hash] the set of option name and option value pairs
  ##
  ## @see #to_h
  def values(defaults_p = true)
    ## using a feature of Mixlib::Config here
    @config_store.save(defaults_p)
  end

  ## Return a hash table representing all options configured for this
  ## OptionGroup.
  ##
  ## The return value will include any default option values defined
  ## under the model for this OptionGroup
  ##
  ## @return [Hash] the set of option name and option value pairs
  ##
  ## @see #values
  ## @see #validate
  def to_h
    self.values(true)
  end


  ## Callback method for invalid option values detected under #validate
  ##
  ## This method will be called for any options whose syntax is
  ## determined to be invalid under the Dry Schema and Dry Validation
  ## Rules for this OptionGroup's configuration model
  ##
  ## @param opt [Symbol] symbolic name of the invalid option
  ##
  ## @see #validate
  ## @see #values
  ## @see #compile
  def option_invalid(opt)
    STDERR.puts("Unsetting invalid option #{opt.inspect} in #{self}") ## DEBUG
    ## NB if the default value is an invalid value, it will be missed here...
    @config_store.configuration.delete(opt)
  end

  ## Validate the set of option values for this OptionGroup instance
  ##
  ## @see #contract
  ## @see #option_invalid
  ## @see #values
  ## @return [...]
  def validate(data = self.to_h)
    if ! (Hash === data)
      raise ArgumentError.new("Unsupported data format: #{data.inspect}")
    end
    inst = (@contract_validate ||= self.contract.new)
    result = inst.call(data)
    if result.failure?
      result.errors.each do |msg|
        path = msg.path
        if path.length.eql?(1)
          opt = path[0]
          self.option_invalid(opt)
        else
          Kernel.warn("Unknown schema failure message syntax; #{msg}",
                      uplevel: 1)
        end
      end
    end
    return result
  end

  ## Return true if an option for the provided name has been set within
  ## this OptionGroup
  ##
  ## @param name [Symbol] the option name
  def option_set?(name)
    ## very simple, with Mixlib::Config
    self.configuration.include?(name)
  end

  ## Unset the named option for this OptionGroup
  #
  ## @param name (see #option_set?)
  def option_unset(name)
    self.configuration.delete(name)
  end

  ## Compile and the configuration model for this OptionGroup
  ##
  ## If the configuration model has been previously compiled, this
  ## method will return the CompilerResult from the earlier compilation.
  ##
  ## On first call, or if called under #recompile, this method will
  ## define the options schema, option rules, option default values, and
  ## option accessor methods for the scoped OptionGroup instance.
  ##
  ## @note This method should not be called until after the
  ## configuration model for this OptionGroup has been defined
  ##
  ## @return [CompilerResult]
  ##
  ## @see recompile
  ## @see contract
  ## @see validate
  def compile(defer_warnings: ! $DEBUG)
    if rslt = @compiler_result
      return rslt
    else
      # store = @config_store ## this only would require instance access
      STDERR.puts "[DEBUG] Building validation contract for #{self}" ## if $DEBUG

      ## NB this creates a new class singularly for the @contract,
      ## there receiving all schema & rule declarations for this class
      ##
      ## FIXME this contract is created and stored at an instance scope,
      ## but should be maintained at a class scope, applied from there
      ## for instance evaluation. (Not in all ways thread-safe, even here)
      ##
      ## - this change may require a substantial update to the API,
      ##   to allow for instance instialization from a method called at
      ##   class scope - at least for calls requiring an instance @config_store
      ##
      clsname = "<%s validation @ %s>" % [
        self.name, Time.now.strftime("%s".freeze)
      ]
      builder = Dry::Core::ClassBuilder.new(name: clsname,
                                            parent: Dry::Validation::Contract)
      cls = builder.call
      results = CompilerResult.new(cls, self, defer_warnings: defer_warnings)
      ## storage for this option group within the following block
      group = self

      ## compile all option schema definitions, before any processing
      ## for non-schema option features
      cls.schema do
        ## class schema scope via Dry::Validation
        ##
        ## in this block: Dry::Schema::DSL === self
        schema_dsl = self
        group.options.each do |_, opt|
          opt.compile_schema(group, schema_dsl, results)
        end
      end
      ## compile all non-schema option features
      self.options.each do |_, opt|
        opt.compile_features(group, cls, results)
      end
      @contract = cls
      @compiler_result = results
    end
  end

  def options()
    @options ||= Hash.new do |_, k|
      raise ArgumentError.new("Option not found in #{self}: #{k.inspect}")
     end
  end

  def [](name)
    self.options[name]
  end

end ## OptionGroup

##
## Tests @ OptionGroup class definition
##

# OptionGroup.model.__scope__
## => OptionGroup

# OptionGroup.model.contained
## => {:option=>Option} ## should only be this

# OptionGroup.model[:option].__scope__.eql?(OptionGroup)
## => true



##
## Tests @ Initial Implementation
##


## add'l test
# $PROFILE.options[:shell].features[:schema].callback_proc
## abbreviated ...
# $PROFILE[:shell][:schema].callback_proc

## - Testing implementation of the profile DSL

$MODEL = OptionGroup.model

$PROFILE = $MODEL.apply(:test_profile) do
  STDERR.puts("[DEBUG] in apply => #{self}")
  option(:shell, optional: true) do

    schema do
      maybe(:string)
    end

    rule do
      catch(:failed) do |tag|
        ## 'value' is a method defined in the Dry::Validation rule DSL
        begin
          argv = Shellwords.split(value)
        rescue ArgumentError => error
          throw tag, key.failure(error.message)
        end
        if argv.empty?
          throw tag, key.failure("Empty value")
        end
        require 'pebbl_app/shell' ## FIXME move to top level
        cmd = argv[0]
        if ! (path = PebblApp::Shell.which(cmd))
          throw tag, key.failure("Shell not available: #{cmd}")
        end
      end
    end

    default do
      ## NB Vte.user_shell
      'sh'
    end

  end

  option(:no_rule) do
    default(default_value: -1)
  end

  STDERR.puts("[DEBUG] end of apply => #{self}")
end

STDERR.puts "[DEBUG] Compiling profile #{$PROFILE}"
$PROFILE.compile

##
## Testing application of the profile DSL's implementation
##

## (FIXME broken over some trivial API change)

# $PROFILE.options
## => {:shell=>#<Option 0x01d060 shell>}

# $PROFILE.options[:shell].optional?
## => true

## $PROFILE.options[:shell].features
## => => {:schema=>#<Schema 0x003d18>, :rule=>#<Rule 0x003d2c>, :default=>#<OptionDefault 0x003d40>}

## $PROFILE.contract
##
## $PROFILE.shell="/bin/sh"
##
## rslt = $PROFILE.validate
##
## $PROFILE.to_h
