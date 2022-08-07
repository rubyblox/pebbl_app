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
    ## @see contained
    def [](name)
      contained[name.to_sym]
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
    ##     include Named
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
    ## top-level DSL name if this is called to define a top-level DSL
    ##
    ## @param class_name [String] The DSL class name for the class. This
    ## will be applied via Dry::Core::ClassBuilder but will not be
    ## initialized as a constants under the Object constants namespace.
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

      if (contained.keys.include?(syname))
        cls = contained[syname]
        if ! base_class.eql?(cls.superclass)
          msg = "Incompatible base class provided for existing class #{cls}: #{base_class}"
          raise ArgumentError.new(msg)
        elsif ! (class_name == cls.name)
          msg = "Incompatible class name provided for existing class #{cls}: #{class_name}"
          raise ArgumentError.new(msg)
        else
          cls.instance_eval(&cb) if cb
        end
      else
        cls = self.define(class_name, base_class: base_class,  &cb)
        self.add_dsl(syname, cls)
      end
      return cls
    end

    ## Initialize and return a new DSL, without registering the DSL to
    ## the implementing class
    ##
    ## @see dsl for registered evaluation of a DSL class expression
    ##
    ## @see dsl_methods for defining a DSL method within a DSL class
    ##  expression, such that the method will be evaluated at instance
    ##  scope when called under apply
    def define(name = nil, base_class: nil, &cb)
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
      if cb
        blk = proc { |subclass| subclass.instance_eval(&cb) }
      else
        blk = (proc {}).freeze
      end
      builder.call(&blk)
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
      ## deferring initialization until after initialize_scope
      ##
      ## also calling the constructor after initialize_methods.
      ##
      ## the constructor can thus be called with a bound __scope__
      ## and can override any instance methods defined under
      ## initialize_methods
      inst = allocate
      initialize_scope(inst, inst)  ## root object
      initialize_methods(inst)
      self.send_wrapped(inst, :initialize, *args)
      if block
        inst.instance_eval(&block)
      end
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
      dsl_methods.keys.include?(name.to_sym)
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
    ## Register a DSL component class for a provided component name
    ##
    ## @param name [Symbol] the component name
    ## @see dsl [Class] the DSL component class
    ## @return [Class] the DSL component class
    def add_dsl(name, dsl)
      syname = name.to_sym
      self.contained[syname] = dsl
      ## TBD
      # self.define_singleton_method(syname) do |*args|
      #   dsl.new(*args)
      # end
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
      if Hash === (last = args.last)
        args = args[...-1]
        inst.send(mtd, *args, **last)
      else
        inst.send(mtd, *args)
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
          sub = cls.allocate
          cls.initialize_scope(sub, inst)
          cls.initialize_methods(sub)
          ## deferring initialization
          cls.send_wrapped(sub, :initialize, *args)
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

  ## bind a `dsl` expression  callback method, if set
  def accept_block(&cb)
    self.instance_eval(&cb)
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

module Named

  attr_reader :name ## profile/structure/field name

  def initialize(name, *args)
    super(*args)
    @name = name
  end

  def to_s
    sname = (@name || "(anonymous)")
    "#<%s 0x%06x %s>" % [ self.class, __id__, sname ]
  end

  def inspect
    self.to_s
  end
end

module Anonymous
  def to_s
    "#<%s 0x%06x>" % [ self.class, __id__ ]
  end

  def inspect
    self.to_s
  end
end

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


## a general example, short of the OptionGroup API

$EG = DslBase.define(:Example) do
  include Named

  ## define an 'applied' instance method for this class.
  ##
  ## This method will be inherited by subclases, thus will be available
  ## to the component classes for :component_a and :component_b
  ##
  define_method(:applied) do |component|
    ## This simple example does not provide component storage
    puts "Applied: #{__scope__} => #{component}"
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


## $EG.apply(:a).component_b("b").inst_method_b("...")
# >> Applied: #<Example 0x004b00 a> => #<Component_b 0x004b14 b>
# >> b => "..."
# => #<Component_b 0x004b14 b>

##
## OptionGroup API
##

 ## TBD define under a PebblApp::OptionsDSL module extending self
## & e.g Vty.extend(PebblApp::OptionsDSL)

require 'mixlib/config'

class OptionsElement < DslBase
  attr_reader :profile

  def components
    ## an analogy to the DSL class field 'contained'
    ## but implemented at an instance scope
    @components ||= Hash.new do |_, name|
      raise ArgumentError.new("Component not found for #{self}: #{name.inspect}")
    end
  end

  def component?(name)
    components.keys.include?(name.to_sym)
  end

  def applied(feature)
    name = DslBase.to_component_name(feature.class.name)
    ## in a general case, this will quietly overwrite the component
    ## storage for any component instance of the same component name
    ##
    self.components[name] = feature

    ## overwrite any instance method for this feature, to return the
    ## initialized instance of this feature
    ##
    ## typically this would ovwerite any feature constructor method
    ## defined under DslBase.apply
    whence = self
    whence.define_singleton_method(name) do
      feature
    end

  end
end


class Structure < OptionsElement
  include Named
end

class Sequence < OptionsElement
  include Named
end


class Option < Structure

  class << self
    def initialize_methods(inst)
      super(inst)
    end
  end

  def initialize(name, optional: true)
    super(name)
    @optional = optional ? true : false
  end

  def optional?
    @optional
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
class Feature < OptionsElement

  ## the effective name of each profile feature is derived from the
  ## feature's class itself - this, contrasted to the effecitve name
  ## of a parameter object, e.g as with the :shell instance
  include Anonymous

  alias_method :option, :__scope__

  attr_reader :callback

  def callback?
    @callback ? true : false
  end

  def accept_block(&cb)
    STDERR.puts"accept_block in #{self}"
    ## protocol method, via DslBase.dsl
    ## see alternate implementation: DslBase#accept_block
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

end

## Option Feature class for default value callbacks and literal default
## values
##
## **Initialization and Setting a Default Value**
##
## An **OptionDefault** can be initialized to a **Option** within a DSL
## **option** expression, using the method `option_default`. If a literal
## default value will be used for the containing **Option** definition,
## the value may be provided with the `default_value` keyword argument
## to the `option_default` method.
## The `option_default` method will be avaialble within a singleton
## scope, within a DSL `option` expression.
##
## Any default value or default callback will be used under the `apply`
## method for the containing Option.
##
## If no `option_default` is provided to the `option` expression, it will
## be assumed that the `option` has no default value.
##
## @see Option
class OptionDefault < Feature

  def initialize(**options)
    if options.keys.include?(:default_value)
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

class ConfigShim
  def initialize()
    ## ensure that all singleton methods form Mixlib::Config
    ## will be available at an instance scope
    self.extend OptionConfig
  end
end

## Base class of a Configuration Options Model for Desktop Applications
class OptionGroup < DslBase
  class << self

    ## Return a new DSL subclass for this OptionGroup
    def model()
      ## using an instance variable at class scope, for storage of the
      ## self-referential @model value.
      ##
      ## In effect, the @model value indicates that this DSL class has
      ## been defined.
      if instance_variable_defined?(:@model)
        @model
      else
        ## this defines an implicit subclass, albeit not such that could
        ## be reached by way of Object constants

        self.instance_eval do
          dsl(:option, base_class: Option) do
            ## This option DSL class is later accessible in a profile definition
            ## as e.g OptionGroup[:base_conf][:option]
            ##
            ## In a profile instance <i>.options[<name>] => option
            ## with option methods: 'schema', 'rule', 'option_default'

            dsl(:schema, base_class: Feature) do
              ## in application: Required field.
              ##
              ## define the option's schema
              ##
              ## any callback defined in the :schema profile field
              ## will be evaluated in the scope of a Dry::Schema
              ## schema DSL
            end

            dsl(:rule, base_class: Feature) do
              ## define a validation rule for the option.
              ##
              ## in application: This is an optional field,
              ##
              ##
              ## any callback defined in the :rule profile field
              ## will be evaluated in the scope of a Dry::Validation
              ## schema rule DSL
            end

            dsl(:option_default, base_class: OptionDefault) do
              ## ^ avoiding override of the 'default' method from Mixlib::Config
              ##
              ## define a default value initializer for the option
              ## for application with Mixlib::Config
              ##
              ## In application: This API supports options without an explicit
              ## default binding. The value 'false' will be used if no literal
              ## value or callback is provided under a field's option_default
              ##
              ## any callback defined in the :optional_default profile field
              ## will be evaluated in a normal instance scope for a profile
              ## instance
            end

          end ## dsl(:option) ...
        end ## self.instance_eval
        ## using 'self' as the model, towards retaining a model/instance alignment
      @model = self
      end ## if ...
    end  ## def model
  end ## class << OptionGroup

  include Named ## TBD not neccessarily needed here & in DSLBase
  attr_reader :validation_results

  def initialize(name)
    ## TBD options via constructor args here
    super(name)
    ## Interation for Mixlib::Config
    ##
    ## @config_shim should not be changed on the instance, once set
    shim = ConfigShim.new
    @config_shim = shim
    self.extend Forwardable
    ## define forwarding for some singleton methods from Mixlib::Config
    ## - this API does not provide interop. for Mixlib::Config contexts
    %w(configuration configuration= configurables).each do |mtd|
      self.def_delegator(:@config_shim, mtd)
    end
  end

  ## @private
  def applied(dsl)
    if Option === dsl
      self.__scope__.options[dsl.name] = dsl
    else
      raise ArgumentError("Uknown instance type: #{dsl}")
    end
  end

  ## Return the schema for this profile's validation contract
  ##
  ## @return [Dry::Schema] the schema
  def schema
    self.contract.schema
  end

  def rules
    self.contract.rules
  end

  def contract
    ## 'compile' will process all DSL data presently supported under the
    ## 'compile' method in the implementing class - i.e schema,
    ## validation rules, defaults, etc - at most once. See also recompile
    self.compile
    @contract
  end

  def recompile
    previous_class = @contract
    previous_instance = @contract_validate
    @contract = nil
    @contract_validate = nil
    @validation_results = nil
    begin
      compile
    rescue
      @contract = previous_class
      @contract_validate = previous_instance
      raise
    end
  end

  def to_h
    ## using a feature of Mixlib::Config here
    @config_shim.save(true)
  end

  ## @see #contract
  ## @see #update_valid
  def validate(data = self.to_h)
    if ! (Hash === data)
      raise ArgumentError.new("Unsupported data format: #{data.inspect}")
    end
    inst = (@contract_validate ||= self.contract.new)
    inst.call(data)
  end


  ## @param result [Dry::Validation::Result]
  ## @see #validate
  def update_valid(result = self.validate)
    if result.failure?
      result.errors.each do |msg|
        path = msg.path
        if path.length.eql?(1)
          @config_shim.configuration.delete(path[0])
        else
          Kernel.warn("Unknown schema failure message syntax; #{msg}",
                      uplevel: 1)
        end
      end
    end
    ## else leave the instance unmodified
  end

  def option_set?(name)
    ## very simple, with Mixlib::Config
    self.configuration.keys.include?(name.to_sym)
  end

  ## @return [nil or CompilerResult]
  ##
  ## @see dsl
  ## @see define
  ##
  ## @see apply
  ##
  ## @see compile
  def compile(defer_warnings = ! $DEBUG)
    ## should not be called until after all options have been defined...
    ##
    ## NB returns a contract class, stored in @contract
    ##
    ## See also: validate, recompile methods in usage of the @contract
    ## class and the @contract_validate instance of this class
    if rslt = @validation_results
      return rslt
    else
      profile = self
      STDERR.puts "[DEBUG] Building validation contract for #{self}" ## if $DEBUG
      clsname = "<%s validation @ %s>" % [profile.name, Time.now.strftime("%s".freeze)]
      builder = Dry::Core::ClassBuilder.new(name: clsname,
                                            parent: Dry::Validation::Contract)
      cls = builder.call

      results = CompilerResult.new(cls, self, defer_warnings: defer_warnings)

      opts = self.options
      ## evaluate all defined schema option definitions within the
      ## scope of a Dry::Schema initialized to to this profile instance
      cls.schema do
        opts.each do |_, opt|
          optname = opt.name
          if opt.optional?
            ## each of these should return a Dry::Schema param object,
            ## which will present a scope for any callback evaluation
            ##
            ## NB The representation of 'param' patterns in Dry::Schema
            ## may be mainly oriented towards development of HTTP
            ## applications, e.g vis a vis GET/POST parameters.
            ##
            ## The concept may be generally congruous to the 'options'
            ## pattern presented here
            sopt = optional(optname)
          else
            sopt = required(optname)
          end
          ## this assumes the opt.schema method call will return a
          ## non-falsey value generally of a Option 'Feature' type
          sch = opt.schema
          if sch.callback?
            sch.callback_eval(sopt)
          else
            results.push_warning(profile, optname, :schema,
                                 "No schema callback defined")
          end
        end
      end
       opts.each do |_, opt|
         ## handle features other than the schema syntax for each
         ## option definition

         optname = opt.name
         if opt.component?(:rule)
           ## define a schema rule for the option, evaluating any 'rule'
           ## block fromthe profile definition within the scope of a
           ## 'rule' declaration for the Dry::Validation::Contract of this
           ## profile instance
           ##
           ## This should generally be evaluated after all option syntax
           ## declarations have been defined under the profile's Dry::Schema
           r = opt.rule ## the DSL component
           if r.callback?
             if opt.optional?
               cls.rule(optname) do
                 ## providing some additional implementation support,
                 ## such that the Dry::Validation rule's callback form
                 ## will be effectively wrapped in 'if value' for any
                 ## optional option
                 r.callback_eval(self) if value
               end
             else
               cls.rule(optname, &r.callback_proc)
             end
           else
             results.push_warning(profile, optname, :rule,
                                  "Rule defined with no callback")
           end
         end

         ## Mixlib::Config integration - default option value
         if opt.component?(:option_default)
           dflt = opt.option_default ## the DSL instance
           if value = dflt.default_value
             ## Given the implementation of OptionDefault#default_value :
             ##
             ## If a callback was defined in the profile definition,
             ## this will set the default value to the value returned
             ## by that callback at this time.
             ##
             ## Else, if a literal default value was set, this will bind
             ## that value as the default.
             ##
             ## Else, this will use the value 'false' as a fallback default.
             ##
             ## The following 'default' method should call through to a
             ## setter method defined for configurable fields under
             ## Mixlib::Config
             ##
             shim.default(optname, value)
           end
         else
           results.push_warning(profile, optname, :option_default,
                                "No option_default defined")
           ## defining it as only a configurable field
           shim.configurable(optname)
         end
         ## define forwarding for the reader and writer methods
         ##
         ## - using lambdas for the early check on args
         ##
         ## - forwarding to methods on @config_shim via direct call
         ##   to each method object. These methods will have been
         ##   defined on the @config_shim as a result of the
         ##   option_default handling, above.
         ##
         ## - each forwarding method will call self.compile before
         ##   dispatching to the next receiving method
         ##
         opt_s = optname.to_s
         rd_mtd = shim.singleton_method(optname)
         rd_lmb = lambda { self.compile; rd_mtd.call(); }
         self.class.smethod_define(optname, self, &rd_lmb)

         wr_name = (opt_s + "=").to_sym
         wr_mtd = shim.singleton_method(wr_name)
         wr_lmb = lambda { |value| self.compile; wr_mtd.call(value)}
         self.class.smethod_define(wr_name, self, &wr_lmb)
       end
       @contract = cls
       @validation_results = results
    end
  end

  def options()
    @options ||= Hash.new do |_, k|
      raise ArgumentError.new("Option not found in #{self}: #{k.inspect}")
     end
  end

end ## OptionGroup

##
## Tests / Initial Implementation
##


## add'l test
# $PROFILE.options[:shell].components[:schema].callback_proc

## - Testing implementation of the profile DSL

$MODEL = OptionGroup.model

$PROFILE = $MODEL.apply(:test_profile) do
  STDERR.puts("[DEBUG] in apply => #{self}")
  option(:shell, optional: true) do

    schema do
      STDERR.puts(":shell schema self: #{self}")
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

    option_default do
      ## NB Vte.user_shell
      '/usr/bin/nonexistent'
    end

  end

  option(:no_rule) do
    option_default(default_value: -1)
  end

  STDERR.puts("[DEBUG] end of apply => #{self}")
end

STDERR.puts "[DEBUG] Compiling profile #{$PROFILE}"
$PROFILE.compile


## Testing application of the profile DSL's implementation

## (FIXME broken over some trivial API change)

# $PROFILE.options
## => {:shell=>#<Option 0x01d060 shell>}

# $PROFILE.options[:shell].optional?
## => true

## $PROFILE.options[:shell].components
## => => {:schema=>#<Schema 0x003d18>, :rule=>#<Rule 0x003d2c>, :option_default=>#<OptionDefault 0x003d40>}

## $PROFILE.contract
##
## $PROFILE.shell="/bin/sh"
##
## rslt = $PROFILE.validate
##
## $PROFILE.update_valid(rslt)
##
## $PROFILE.to_h
