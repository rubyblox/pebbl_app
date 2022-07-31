## DSL classes, Profile DSL, Tests (sandbox)

require 'dry/core/class_builder'
require 'dry/validation'


## Generic base class for custom language bindings in Ruby
class DSLBase

  class << self

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
      if self.singleton_class.instance_variable_defined?(:@contained)
        self.singleton_class.instance_variable_get(:@contained)
      else
        h = Hash.new do |_, name|
          raise ArgumentError.new(
            "DSL name not found in #{self}: #{name.inspect}"
          )
        end
        self.singleton_class.instance_variable_set(:@contained, h)
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

    ## Define or return a DSL class.
    ##
    ## For any block provided to this method, the block will be
    ## evaluated with the new DSL class as the scoped `self`.
    ##
    ## In effect, the class returned by this method will represent an
    ## anonymous class. The class' name will be available via a singleton
    ## `name` method and will be visible as the class' effective name
    ## under printed representations of the class. However, the class'
    ## name will not be initialized as a constant under the Object
    ## namespace.
    ##
    ## The component class may be accessed via the `components` method
    ## or the `[]` method on the containing DSL implementation class, or
    ## via the `subclasses` method on the provided base_class.
    ##
    ## @example
    ##   eg_dsl = DSLBase.define(:example) do
    ##     include Named
    ##
    ##     define_method(:applied) do |component|
    ##       puts "Applied: #{__scope__} => #{component}"
    ##     end
    ##
    ##     dsl(:component_a) do
    ##       def class_method(arg)
    ##         puts "A => #{arg.inspect}"
    ##       end
    ##     end
    ##
    ##     dsl(:component_b) do
    ##       define_method(:inst_method) do |arg|
    ##         puts "b => #{arg.inspect}"
    ##         return __self__
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
    ## @param base_class [Class] the superclass for the definition of
    ##  the component class
    ##
    ## @param cb [Proc] optional callback. If provided, the callback
    ##  will be evaluted with the DSL class as the scoped `self`
    ##
    ## @return [Class] the defined DSL class
    ##
    ## @see define for defining a DSL class without registration to the
    ##  containing class' _contained_ list
    def dsl(name, class_name: to_class_name(name),
            base_class: self, &cb)
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
        cls = define(name, class_name: class_name,
                     base_class: base_class,  &cb)
        self.add_dsl(syname, cls)
      end
      return cls
    end

    ## Initialize and return a new DSL, without registering the DSL to
    ## the implementing class
    ##
    ## @see dsl
    def define(name, class_name: to_class_name(name),
               base_class: self, &cb)
      if base_class.singleton_class?
        ## assumption: the first ancestor not the singleton class
        ## would provide a non-singleton class, such that this
        ## non-singleton class has base_class as its singleton class
        ##
        ## this may be applicable whether the base_class is
        ## a singleton class of a class or a singleton class
        ## of some non-class object
        impl_class = base_class.ancestors[1]
      else
        ## base_class is not a singleton class
        impl_class = base_class
      end
      builder =
        Dry::Core::ClassBuilder.new(name: class_name, parent: impl_class)
      blk = proc { |subclass| subclass.instance_eval(&cb) } if cb
      builder.call(&blk)
    end


    ## Create and return a new instance of this DSL class
    ##
    ## @note Initailization for the instance will be deferred until
    ##  after the __scope__ for the instance has been set as via
    ##  initialize_scope.
    ##
    ## @note For any instance initialized with this method, the
    ##__scope__ of the instance will be set as the instance itself. This
    ## may be construed as indicating that the instance is a top-level
    ## DSL component, contrasted to the __scope__ value set with any
    ## component method on the instance.
    ##
    ## Before return, any DSL component methods will be defined on the
    ## instance as with `initialize_methods`
    ##
    ## @see initialize_scope
    ## @see initialize_methods
    ##
    ## @param args [Array] arguments to apply in the instance's
    ##  constructor
    ##
    ## @param block [Proc] optional block. If provided, this block will
    ##  be evaluated with the initialized instance as the scoped `self`
    ##  in the call
    ##
    ## @return [DSLBase] a new DSL instance
    ##
    def apply(*args, &block)
      inst = allocate
      initialize_scope(inst, inst)  ## root object
      initialize_methods(inst)
      self.send_wrapped(inst, :initialize, *args)
      if block
        inst.instance_eval(&block)
      end
      return inst
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
      return (sname[0].upcase + sname[1...])
    end

    ## Compute the component name of some DSL component class' name
    ##
    ## @param name [String] a DSL class name
    ## @return [Symbol] a component name, as a symbol
    ##
    ## @see to_class_name
    def to_component_name(name)
      name.downcase.to_sym
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
    ## Initialize instance varibles for __self__ and __scope__ on the
    ## provided instance
    def initialize_scope(inst, scope)
      ## FIXME rather than @__self__/__self__
      ## provide an dsl_method / dsl_method? / dsl_methods API,
      ## initializing each as a singleton method under initialize_methods
      ## def dsl_method(name, &block) ...
      inst.instance_variable_set(:@__self__, inst) ## remove after dsl_method
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
        inst.singleton_class.define_method(dslname) do |*args, &block|
          sub = cls.allocate
          cls.initialize_scope(sub, inst)
          cls.initialize_methods(sub)
          ## deferring initialization
          cls.send_wrapped(sub, :initialize, *args)
          if block
            sub.instance_eval(&block)
          end
          inst.applied(sub)
          return sub
        end
      end
    end

    ## @!endgroup
  end ## class << DSLBase

  ## return the scope of this DSL object
  ##
  ## If this is a top-level DSL object, this method should return the
  ## object itself
  ##
  attr_reader :__scope__

  ## return this DSL object
  ##
  ## This method is defined as a utility method for instance methods
  ## defined within the scope of a class `dsl` expression
  ##
  attr_reader :__self__

  ## @!method applied(component)
  ## handle some component object initialized for a scoped instance
  ## as under self.class.apply
  ##
  ## @abstract This method should be defined in any implementing class
  ##
  ## @param instance [DSLBase] a DSL component object
  ##
  ## @see DSLBase.apply

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

class ParamWarning
  attr_reader :param, :feature, :message

  def initialize(param, feature, message)
    @param = param
    @feature = feature
    @message = message
  end
end

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

  def push_warning(profile, param, feature, message)
    w = ParamWarning.new(param, feature, message)
    self.warnings.push(w)
   if ! self.defer_warnings?
     Kernel.warn("%s param %s (%s) : %s" % [profile, param, feature, message],
                 uplevel: 1)
   end
   return w
  end
end


## a general example, short of the Profile API

$EG = DSLBase.define(:example) do
  include Named
  define_method(:applied) do |component|
    puts "Applied: #{__scope__} => #{component}"
  end
  dsl(:component_a) do
    def class_method_a(arg)
      puts "A => #{arg.inspect}"
    end
  end
  dsl(:component_b) do
    define_method(:inst_method_b) do |arg|
      puts "b => #{arg.inspect}"
      return __self__
    end
  end
end

## $EG.apply(:a).component_b("b").inst_method_b("...")
## >> b => "..."


##
## Profile API
##

## TBD define under a PebblApp::ProfileDSL module extending self
## & e.g Vty.extend(PebblApp::ProfileDSL)

require 'mixlib/config'

## Base class for a Configuration Profile DSL for Desktop Applications
class Profile < DSLBase
  include Named

  attr_reader :validation_results

  def initialize(name)
    ## TBD options via constructor args here
    super(name)
    self.extend ::Mixlib::Config
    self.config_strict_mode true
  end

  ## @private
  def applied(dsl)
    if Param === dsl
      STDERR.puts("[DEBUG] adding #{self} param #{name} => #{dsl}") ## if $DEBUG
      self.__scope__.params[dsl.name] = dsl
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
    @validation_results = nil ## not restored
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
    self.save(true)
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
          self.configuration.delete(path[0])
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
  def compile(defer_warnings = ! $DEBUG)
    ## should not be called until after all params have been defined...
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
      p = self.params
      ## evaluate all defined schema param definitions within the
      ## scope of a Dry::Schema initialized to to this profile instance
      cls.schema do
        p.each do |_, cparam|
          pname = cparam.name
          if cparam.optional?
            ## each of these should return a Dry::Schema param object,
            ## which will present a scope for any callback evaluation
            sparam = optional(pname)
          else
            sparam = required(pname)
          end
          ## this assumes the cparam.schema method call will return a
          ## non-falsey value generally of a Param 'Feature' type
          sch = cparam.schema
          if sch.callback?
            sch.callback_eval(sparam)
          else
            results.push_warning(profile, pname, :schema,
                                 "No schema callback defined")
          end
        end
      end
       p.each do |_, cparam|
         ## handle features other than the schema syntax for each
         ## parameter definition

         pname = cparam.name
         if cparam.component?(:rule)
           ## define a schema rule for the option, evaluating any 'rule'
           ## block fromthe profile definition within the scope of a
           ## 'rule' declaration for the Dry::Validation::Contract of this
           ## profile instance
           ##
           ## This should generally be evaluated after all parameter syntax
           ## declarations have been defined under the profile's Dry::Schema
           r = cparam.rule ## the DSL component
           if r.callback?
             if cparam.optional?
               cls.rule(pname) do
                 ## providing some additional implementation support,
                 ## such that the Dry::Validation rule's callback form
                 ## will be effectively wrapped in 'if value' for any
                 ## optional param
                 r.callback_eval(self) if value
               end
             else
               cls.rule(pname, &r.callback_proc)
             end
           else
             results.push_warning(profile, pname, :rule,
                                  "Rule defined with no callback")
           end
         end

         ## Mixlib::Config integration - default option value
         if cparam.component?(:option_default)
           dflt = cparam.option_default ## the DSL instance
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
             profile.default(pname, value)
           end
         else
           results.push_warning(profile, pname, :option_default,
                                "No option_default defined")
           ## defining it as only a configurable field
           profile.configurable(pname)
         end
       end
       @contract = cls
       @validation_results = results
    end
  end

  def params()
    @params ||= Hash.new do |_, k|
      raise ArgumentError.new("Configuration parameter not found: #{k}")
     end
  end
end ## Profile class


class ProfileElement < DSLBase
  attr_reader :profile

  def components
    ## an analogy to the DSL class field 'contained'
    ## but implemented at an instance scope
    @components ||= Hash.new do |_, name|
      raise ArgumentError.new("Component not found for #{self}: #{name}")
    end
  end

  def component?(name)
    components.keys.include?(name.to_sym)
  end

  def applied(feature)
    name = DSLBase.to_component_name(feature.class.name)
    self.components[name] = feature

    ## overwrite any instance method for this feature, to return the
    ## initialized instance of this feature
    ##
    ## typically this would ovwerite any feature constructor method
    ## defined under DSLBase.apply
    whence = self
    mtd = DSLBase.to_component_name(feature.class.name)
    whence.define_singleton_method(mtd) do
      feature
    end

  end
end


class Structure < ProfileElement
  include Named
end

class Sequence < ProfileElement
  include Named
  ## TBD in application for shell environment bindings
  ## where each sequence element will itself have a structure
  ## in this instance, generally a tuple (<name>, <value>)
  ##
  ## also for a list of environment variables to unset,
  ## generally of a format (<name>)
end

## TBD adapting this application profile DSL for project.yaml validation

class Param < Structure

  class << self
    def initialize_methods(inst)
      ## FIXME rewrite how this is handled at the class scope
      ## - dispatch to a separate define_initializer method for each |dslname, cls|
      ## - here, when the new sub instance is a Feature, set the feature
      ##   initializer method's block as the feature's callback, rather
      ##   than passing to instance_eval
      ## - in most instanaces here, the new instance will be a Feature
      ## - this would serve to simplify the dsl API, not requiring so
      ##   many 'callback' calls -  a callback should really be
      ##   provided in each feature definition (but must often be
      ##   used for other than instance eval on the feature)
      ## - retain the general instance_eval behavior for the Profile
      ##   class
      ## - TBD for the Feature class, which should not ever receive this method
      STDERR.puts "%%%% #{self} => #{inst}"
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

class Feature < ProfileElement

  ## the effective name of each profile feature is derived from the
  ## feature's class itself - this, contrasted to the effecitve name
  ## of a parameter object, e.g as with the :shell instance
  include Anonymous

  alias_method :param, :__scope__

  attr_reader :callback

  def callback?
    @callback ? true : false
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

class OptionDefault < Feature

  ## return the default value for this profile feature
  ##
  ## @see #def_default
  def default_value()
    if self.instance_variable_defined?(:@default_value)
      @default_value
    elsif (cb = self.callback)
      @default_value = cb.yield
    else
      false
    end
  end

  ## bind a callback or a default value for the profile feature
  ##
  ## If a callback block is provided, any _value_ provided in the call
  ## to this method will be discarded. The block will be called with no
  ## arguments, on the first call to #default_value. The value returned
  ## by the callback at that time will then be stored as a literal
  ## default value for this profile feature.
  ##
  ## If no callback block is provided, the _value_ will be used as the
  ## default value for this profile feature.
  ##
  ## @param value [Object] a default value, if no block is provided
  ##
  ## @see #default_value
  def def_default(value = false, &block)
    if block
      self.callback(&block)
    else
      @default_value = value
    end
  end
end

##
## Tests / Initial Implementation
##
##

## - Defining a profile DSL named :base_conf ...

Profile.dsl(:base_conf) do

  dsl(:param, base_class: Param) do
    ## This param DSL class is later accessible in a profile definition
    ## as e.g Profile[:base_conf][:param]
    ##
    ## In a profile instance <i>.params[<name>] => param
    ## with param methods: 'schema', 'rule', 'option_default'


    ## each DSL class is in effect an anonymous class,
    ## and defined with a singleton name via Dry::Core::ClassBuilder
    ##
    ## for any DSL class, the class.name method itself would return
    ## the name as defined with Dry::Core::ClassBuilder
    ##
    ## TBD accessing the structural name of the class, within Ruby,
    ## it being an anonymous class in implementation with as surface name


    dsl(:schema, base_class: Feature) do
      ## in application: Required field.
      ##
      ## define the param's schema
      ##
      ## any callback defined in the :schema profile field
      ## will be evaluated in the scope of a Dry::Schema
      ## schema DSL
    end

    dsl(:rule, base_class: Feature) do
      ## define a validation rule for the param.
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
      ## define a default value initializer for the param
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

  end
end

## add'l test
# $PROFILE.params[:shell].components[:schema].callback_proc

## - Testing implementation of the profile DSL

$PROFILE = Profile[:base_conf].apply(:test_profile) do
  param(:shell, optional: true) do
    schema do
      STDERR.puts(":shell schema self: #{self}") ## #<Schema ...> ok
      callback do
        ## FIXME lost for purposes of storage now,
        ## but still evaluated during schema definition?
        maybe(:string)
      end
    end

    rule do
      callback do
        ## FIXME wrong scope is being used here
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
    end

    option_default do
      def_default('/usr/bin/nonexistent') ## FIXME use vte
    end
  end

  param(:no_rule) do
    # schema do
    #   # callback do
    #   # end
    # end
  end
end

STDERR.puts "[DEBUG] Compiling profile #{$PROFILE}"
$PROFILE.compile


## Testing application of the profile DSL's implementation

## (FIXME broken over some trivial API change)

# $PROFILE.params
## => {:shell=>#<Param 0x01d060 shell>}

# $PROFILE.params[:shell].optional?
## => true

## $PROFILE.contract
##
## $PROFILE.shell="/bin/sh"
##
## rslt = $PROFILE.validate
##
## $PROFILE.update_valid(rslt)
##
## $PROFILE.to_h

##
## FIXME configuration & validation for environment variable bindings
## will be even less trivial than this
##
