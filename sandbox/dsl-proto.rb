# DSL classes, Options DSL, Tests (sandbox)


require 'dry/core/class_builder'
require 'dry/validation'

require 'securerandom'

## Generic base class for definition of domain-specific languages
## extending the Ruby programing language
##
## - generally inspired by Dry::Schema, Dry::Validation, and Mixlib::Config
class DslBase

  class << self

    include PebblApp::ScopeUtil

    ## @!group DSL API - class methods

    ## @!group Naming and Reference for DSL Components

    ## If this class is a prototype class, return the prototype role for
    ## the class. This value will typically be a string
    attr_reader :__role__

    def component_name?()
      defined?(@component_name)
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
      if (! component_name?)
        @component_name = name
      elsif(! component_name.eql?(name))
        msg = "component_name %p already registered for %s" % [
          component_name, self
        ]
        ArgumentError.new(msg)
      else
        name
      end
    end

    ## @!endgroup

    ## @!group DSL reference

    ## Return the DSL model for this DSL class
    ##
    ## This method should be avaialble within block forms on `model`
    ##
    ## @raise [RuntimeError] if no DSL model is defined
    ##
    ## @see model for defining a DSL model to this class
    ##
    def __model__()
      if instance_variable_defined?(:@__model__)
        instance_variable_get(:@__model__)
      else
        raise RuntimeError.new("__model__ not initialized for #{self}")
      end
    end

    ## return the DSL model scope of this DSL class
    ##
    ## If this is a top-level DSL model class, this method should return
    ## the class itself
    ##
    def __scope__()
      if defined?(@__scope__)
        @__scope__
      else
        self ## TBD self.model ??
      end
    end

    def path
      if defined?(@path)
        @path
      else
        _scope = __scope__
        if _scope.eql?(self)
          @path = [self]
        else
          @path = [* _scope.path, self]
        end
      end
    end

    def component_label(cls = self)
      begin
        if cls.respond_to?(:component_name?) && cls.component_name?
          name = cls.component_name
        else
          name = cls.name
        end
      rescue
        name = cls.name
      end
      if cls.instance_variable_defined?(:@__role__)
        format("%s[%s](%06x)", name, cls.instance_variable_get(:@__role__), cls.__id__)
      else
        format("%s(%06x)", name, cls.__id__)
      end
    end

    ## @!endgroup

    # @!group DSL components

    ## Return the hash table of DSL instance component definitions for
    ## this class
    def components
      instance_bind(:@components) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "Component not defined to #{self}: #{name.inspect}"
          )
        end
      end
    end

    ## Return the hash table of DSL macro component definitions for this
    ## class
    def macros
      instance_bind(:@macros) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "Macro not defined to #{self}: #{name.inspect}"
          )
        end
      end
    end

    ## return true if `name` denotes a DSL instance component for this class
    def component?(name = false)
      if name
        components.include?(name)
      elsif defined?(:@__component__)
        @__component__ ? true : false
      end
    end

    ## return true if `name` denotes a DSL macro component for this class
    def macro?(name = false)
      if name
        macros.include?(name)
      elsif defined?(:@__macro__)
        @__macro__ ? true : false
      end
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
      instance_bind(:@dsl_methods) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "DSL method not found in #{self}: #{name.inspect}"
          )
        end
      end
    end

    ## return true if `name` denotes a DSL singleton method for this class
    ##
    ## @param name (see dsl_method)
    ## @return [boolean] a boolean value
    def dsl_method?(name)
      dsl_methods.include?(name)
    end

    ## Define a DSL singleton method for the effective component scope
    ##
    ## The DSL method will be avaialble in a component singleton
    ## scope, under `apply`. The method's block will be evaluated within
    ## the scope of the containing component. For a DSL method applied
    ## within an instance component, `self` in the method block will
    ## return the scoped instance. For a macro component, `self` will
    ## return the macro's component definition, generally in the form of
    ## a class.
    ##
    ## This method is defined as a utility for singleton method
    ## definition within dsl component expressions.
    ##
    ## @note Any method defined with dsl_method, in effect, will shadow
    ##  any existing instance method or singleton method of the same
    ##  name, within each containing DSL component scope under `apply`.
    ##
    ## @note This method should generally be called within a DSL _model
    ##  scope_, rather than called directly on a class
    ##
    ## @param name a method name
    ## @param block the block to provide for the method definition
    ## @return [Proc] the `proc` that will be applied for the method's
    ##  definition. This `proc` will be equivalent to the provided
    ##  `block`
    ## @see model
    ## @see dsl
    ## @see define
    ## @see apply
    def dsl_method(name, &block)
      name = name.to_sym
      dsl_methods[name.to_sym] = block
    end

    ## Return any DSL component definition for the provided DSL
    ## component name, onto this class.
    ##
    ## @note This method should generally be called for a DSL _model
    ##  scope_, rather than called directly on a class providing a DSL
    ## _model scope_
    ##
    ## @raise [RuntimeError] if no component has been defined for the
    ##  provided name
    ##
    ## @see dsl
    ## @see dsl_method
    ## @see model
    def [](name)
      if macro?(name)
        macros[name]
      elsif component?(name)
        components[name]
      elsif dsl_method?(name)
        dsl_methods[name]
      else
        raise ArgumentError.new("DSL element not found in #{self}: #{name}")
      end
    end

    ## @private
    def register_component(name, component)
      msg = false
      if macro?(name)
        msg = "Component name already assigned to a macro: %p, %s" % [name, macros[name]]
      elsif component?(name)
        msg = "Component name already assigned to a component: %p, %s" % [name, components[name]]
      elsif dsl_method?(name)
        msg = "Component name already assigned to a DSL method: %p" % [name]
      end
      if msg
        raise RuntimeError.new(msg)
      else
        components[name]=component
      end
    end

    ## @private
    def register_macro(name, macro)
      msg = false
      if component?(name)
        msg = "Macro name already assigned to a component: %p, %s" % [name, components[name]]
      elsif dsl_method?(name)
        msg = "Macro name already assigned to a DSL method: %p" % [name]
      end
      if msg
        raise RuntimeError.new(msg)
      else
        macros[name] = macro
      end
    end

    ## @!group Definition and Application of DSL Components

    ## Define and return a DSL component, registering the definition as
    ## the DSL model for the containing class
    ##
    ## @note **Top-Level Definitions:** This method is implemented
    ##  principally for support of `dsl` definitions under some
    ##  top-level DSL model. In order to create any one or more `dsl`
    ##  definitions within some top-level DSL expression, subclasses
    ##  should generally define the top-level DSL model within a block
    ##  under `super` for the `model` method.
    ##
    ## @note **Method Scope:** For any top-level block provided to this
    ##  method, the block will be evaluated with the new DSL class as
    ##  the scoped self`. The scope for evaluation within blocks in
    ##  component definitions may vary by the implementation of the
    ##  corresponding component class.
    ##
    ## @example
    ## [FIXME] - see tests
    ##
    ## @param name [Symbol] The DSL component name for the class
    ##
    ## @param class_name [String] The DSL class name for the class. This
    ##  class name will be applied via Dry::Core::ClassBuilder and will
    ##  be generally visible in the singleton scope. The class_name will
    ##  not be initialized as a constant under the Object constants
    ##  namespace.
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
    ## @see define for defining a DSL class without affecting the model
    ##  of the containing class
    ##
    ## @see dsl_method for defining a DSL singleton method within a DSL
    ##  class expression, such that the method will be evaluated within
    ##  a component's singleton scope when called under `apply`
    ##
    ## @see model for accessing the top-level DSL component definition
    ##  for this class
    ##
    ## @see apply for applying a DSL component definition
    ##
    ## @see [] for scoped retrieval of DSL components by component name
    ##
    def dsl(name, macro: false, ## ?
            class_name: to_class_name(name),
            base_class: default_dsl_base_class(name), &cb)
      base_class ||= self

      syname = name.to_sym

      if component?(syname) || macro?(syname)
        cls = macro?(syname) ? macros[syname] : components[syname]
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
        elsif ! self.eql?(cscope = cls.__scope__)
          msg = "Existing component %s class %p has scope %s incompatible with scope %p" % [
            syname, cls, cscope, self
          ]
        end
        raise ArgumentError.new(msg) if msg
      else

        ## deferring evaluation of the callback until after the class'
        ## scope is set
        cls = self.define(class_name, base_class: base_class)
        cls.register_component_name(name)

        cls.instance_variable_set(:@__model__, cls)
        ## a top-level DSL expression, in effect, will define the DSL
        ## model for the containing class
        cls.instance_variable_set(:@model, cls)

        cls.register_component_name(name) ## before register_{component, macro}
        cls.initialize_scope(__model__)

        if macro
          STDERR.puts "-- Registering macro #{name.inspect} for {self}"
          cls.instance_variable_set(:@__macro__, cls)
          __model__.register_macro(name, cls)
        else
          STDERR.puts "-- Registering component #{name.inspect} for #{self}"
          cls.instance_variable_set(:@__component__, cls)
          __model__.register_component(name, cls)
        end
      end
      cls.accept_block(&cb) if cb
      return cls
    end

    ## Initialize and return a new DSL component defnition
    ##
    ## This method will return a new class, initialized per the provided
    ## arguments.
    ##
    ## @note This method will not register the class as providing the
    ##  DSL model for the containing class. The caller may provide any
    ##  further class initialization.
    ##
    ## @param name (see dsl)
    ##
    ## @param base_class (see dsl)
    ##
    ## @param cb (see dsl)
    ##
    ## @see dsl for defining the DSL model to the containing class
    ##
    ## @see dsl_method for defining a DSL singleton method within a DSL
    ##  class expression, such that the method will be evaluated within
    ##  a component's singleton scope when called under `apply`
    ##
    ## @see model for accessing the top-level DSL component definition
    ##  for this class
    ##
    ## @see apply for applying a DSL component definition
    def define(name = nil, base_class: self, &cb)
      ## set defaults
      name ||= to_class_name(base_class.name)

      if base_class.singleton_class?
        ## The first ancestor not the singleton class would provide a
        ## non-singleton class, such that this non-singleton class has
        ## base_class as its singleton class.
        ##
        ## This should be applicable whether the base_class is a
        ## singleton class of a class, or when it is a singleton class
        ## of some non-class object.
        ##
        ## If a singleton class of a non-class object, the new class
        ## will be defined as a subclass of that object's class.
        ##
        ## As the new class will not be available under the Object
        ## constants namespace, this will not ovewrite any existing
        ## class of the same name.
        ##
        ## This may result in duplicate names under a superclass'
        ## 'subclasses' array
        ##
        impl_class = base_class.ancestors[1]
      else
        ## base_class is not a singleton class
        impl_class = base_class
      end
      builder =
        Dry::Core::ClassBuilder.new(name: name, parent: impl_class)
      blk = proc { |subclass|
        ## Ensuring that the callback will be evaluated under instance
        ## scope for the new class
        subclass.instance_eval(&cb) if cb
      }
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
    ##  instance method for this DSL class' model will be defined as a
    ##  singleton method on the instance, via `initialize_methods`
    ##
    ## @see dsl for definiing a DSL class as the model for the
    ##  containing class.
    ##
    ## @see define for defining a DSL class without registration in the
    ##  containing class
    ##
    ## @see dsl_method for declaring a singleton method to be defined
    ##  for a DSL instance
    ##
    ## @param args [Array] arguments for the constructor method
    ##
    ## @param block [Proc] optional block. If provided, this block will
    ##  be evaluated in a scope with the initialized instance as the
    ##  scoped `self` in the call
    ##
    ## @return [DslBase] a new DSL instance
    ##
    def apply(*args, **options, &block)
      if component?
        ## creating a DSL component instance
        nxt = self.new(*args, **options)
      elsif macro?
        ## creating a macro prototype
        ##
        ## DSL component args will be discarded here, can be handled
        ## within 'apply' in any subclass
        nxt = prototype("macro")
      else
        ## generally reached for any top-level DSL component definition
        ## if the definition was initialized with 'define'
        nxt = prototype("applied")
      end
      ## methods from the model should be avaialble for instance_eval
      ## onto the DSL component
      self.model.initialize_methods(nxt)

      ## caller may provide any further initialization in a provided
      ## callback block
      ##
      ## the block may set the __scope__ of the component, such as in a
      ## component singleton method defined under initialize_methods
      ##
      ## unless set within the block or overidden in some other class,
      ## the default __scope__ will be the component itself
      nxt.instance_eval(&block) if block
      nxt.__scope__.applied(nxt)
      return nxt
    end

    ## @see dsl
    ## @see define
    ## @see apply
    ## @see __model__
    def model(&block)
      ## default ... see apply, subclasses
      mdl = false
      if instance_variable_defined?(:@model)
        mdl = instance_variable_get(:@model)
        STDERR.puts "[!DEBUG] using existing model #{mdl.inspect}"
      else
        STDERR.puts "[!DEBUG] initializing default model in #{self}"
        mdl = prototype("model")
        mdl.instance_variable_set(:@__model__, mdl) ## for initialization
        self.instance_variable_set(:@model, mdl) ## for later call @ self
      end
      mdl.instance_eval(&block) if block
      ## ^ NB evaluated in every call
      STDERR.puts "[!DEBUG] #{self} model => #{mdl.inspect}"
      mdl
    end

    ## @!endgroup
    ## @!endgroup

    ##
    ## @!group Utility methods
    ##

    ## Callback method for deteriminig the default base_class for
    ## classes defined under `dsl`. Implementing classes may override
    ## this method.
    ##
    ## @see dsl
    def default_dsl_base_class(component)
      self
    end

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
    ##
    ## @param name [String] a DSL class name
    ## @return [Symbol] a component name, as a symbol
    ##
    ## @see to_class_name
    ##
    def to_component_name(name)
      if name
        last = name.split(/::/).last
        PebblApp::NameUtil.flatten_name(last).to_sym
      else
        raise ArgumentError.new("Not a valid component name: #{name.inspect}")
      end
    end

    ## @private
    ## Initialize the __scope__ on the provided instance
    def initialize_scope(scope)
      if defined?(@__scope__)
        raise RuntimeError.new("__scope__ is already defined for #{self}")
      else
        @__scope__ = scope
      end
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
    def initialize_methods(receiver)
      STDERR.puts "-- initialize_methods @ #{self}"
      ## define component methods for instance, macro component kinds
      all = __model__.components.merge(__model__.macros)
      all.each do |_mtd, _class|
        STDERR.puts "[DEBUG def #{_mtd.inspect} => #{_class} for #{receiver.inspect} in #{self}"
        _lambda = lambda { |*_args, **_opts, &_block|
          _model = _class.model
          rslt = _model.apply(*_args, **_opts) do
            STDERR.puts "! _model.apply for #{receiver} : #{_model} => #{self} (#{self.class})"
            self.instance_variable_set(:@__scope__, receiver)
            self.accept_block(&_block) if _block
          end
          rslt
        }
        receiver.define_singleton_method(_mtd, &_lambda)
      end
      ## define each dsl_method
      __model__.dsl_methods.each do |mtdname, cb|
        receiver.singleton_class.define_method(mtdname, &cb)
      end
    end

    ## @private
    ## Return a new class named for some specific role under the
    ## superclass
    ##
    ## @param role [String]
    ##
    ## @param superclass [Class]
    ##
    ## @return [Class]
    def prototype(role, superclass = self)
      ## using a verbose method of class naming, for purpose of
      ## reference tracking in applications of prototype classes
      begin
        if  superclass.respond_to?(:path)
          _name = superclass.path.map() { |cls| component_label(cls) }.join("/")
        else
          _name = component_label(superclass)
        end
      rescue
        _name = component_label(superclass)
      end
      _builder = Dry::Core::ClassBuilder.new(name: _name, parent: superclass)
      _class = _builder.call
      _class.instance_variable_set(:@__role__, role)
      ## add the role and object ID for the new class
      _name.replace(name + format("[%s](%06x)", role, _class.__id__))
      _name.freeze
      return _class
    end

    def accept_block(&cb)
      STDERR.puts "! default accept_block in #{self}"
      self.instance_eval(&cb) if cb
    end

    ## @!endgroup
  end ## class << DslBase


  ## @!group DSL API - instance methods

  def __scope__()
    ## scoping for DSL component instances
    if defined?(@__scope__)
      @__scope__
    else
      self
    end
  end

  def accept_block(&cb)
    ## for applications under 'apply' with DSL component instances
    ##
    ## may be overridden in subclasses
    STDERR.puts "! Instance accept_block in #{self}"
    self.instance_eval(&cb)
  end

  def to_s
    ## using any class.name method, such as may be set via Dry class builder
    "#<%s 0x%06x>" % [self.class.name, __id__]
  end

  def inspect
    to_s
  end

  ## @!endgroup

end ## DslBase

##
## a general example & test, short of the OptionGroup API
##

class NamedTestBase < DslBase

  class << self
    def inherited(subc)
      if defined?(@nodes)
        ## ensure the value is carried to prototype subclasses
        ## for purpose of test
        subc.instance_variable_set(:@nodes, @nodes)
      end
    end

    def nodes
      ## trivial reference storage - class scope
      ##
      ## contained nodes will be accessible after 'apply' in the
      ## top-level DSL, and for each DSL element
      ##
      ## for component nodes, this class scoped method is
      ## accompanied with similar at the instance scope
      @nodes ||= Array.new
    end

    def applied(node)
      if node.__scope__.eql?(node)
        puts "Applied (top) #{node}"
      else
        puts "Applied: #{self.__scope__} << #{node}"
        self.nodes << node
      end
      return node
    end
  end

  attr_reader :name

  def initialize(name = false)
    @name = name
  end

  def nodes
    ## trivial reference storage, instance scope
    @nodes ||= Array.new
  end

  def applied(inst)
    ## component reference recording, instance scope
    nodes << inst
  end
end

##
## DSL model class for tests
##
class NamedTestModel < NamedTestBase
  ## how does this show as an anonymous class subsequently?
  class << self

    def default_dsl_base_class(_)
      NamedTestBase
    end

    def model(&block)
      super() do
        STDERR.puts "[!DEBUG] named test __model__ #{__model__}"

        dsl(:component_a) do

          STDERR.puts "[!DEBUG] component_a __model__ #{__model__}"

          def class_method_a(arg)
            puts "A => #{arg.inspect}"
          end
          dsl(:component_c, macro: true) do
            ## test for macro component reference within an instance component
            STDERR.puts "[!DEBUG] component_c __model__ #{__model__}"
          end
        end

        dsl(:component_b, macro: true) do
          STDERR.puts "[!DEBUG] component_b __model__ #{__model__}"

          dsl_method(:inst_method_b) do |arg|
            puts "b => #{arg.inspect}"
            return self
          end

          dsl(:component_d) do
            ## test for instance component reference within a macro component
            STDERR.puts "[!DEBUG] component_d __model__ #{__model__}"
          end
        end
      end ## super() block
      @model.accept_block(&block) if block
      @model
    end
  end ## class << NamedTestModel
end

# NamedTestModel.components
## => notably empty - components of the class, absent of model

# NamedTestModel.model.components
## => {:component_a=>ComponentA}
# NamedTestModel.model.macros
## => {:component_b=>ComponentB}

# NamedTestModel.apply.components
## => notably empty - similar to the initial class

## alternately
## _model ||= NamedTestModel.model; _model[:component_a][:component_c]
## _model ||= NamedTestModel.model; _model[:component_b][:component_d]
## _model ||= NamedTestModel.model; _model[:component_b][:inst_method_b]


$EG_TEST = NamedTestModel.apply do
  $EG_TEST_SELF = self

  component_a do
    $EG_TEST_A = self

    component_c do
      $EG_TEST_C = self
    end
  end

  component_b do
    $EG_TEST_B = self
    component_d do
      $EG_TEST_D = self
    end
  end
end

# $EG_TEST_SELF.eql?($EG_TEST)
# => true

# $EG_TEST.nodes
# => not empty. Component classes ComponentA, ComponentB

## testing an effective subclass produced via 'define' (no block)
$EG_DSL = NamedTestModel.define("Example")
$EG_MODEL = $EG_DSL.model

# $EG_MODEL.superclass
## => Example

# $EG_MODEL.superclass.eql?($EG_DSL)
## => true

# $EG_MODEL.components
## => {:component_a=>ComponentA}
# $EG_MODEL.macros
## => {:component_b=>ComponentB}

## $EG_MODEL[:component_a].__scope__.eql?($EG_MODEL)
# => true

## $EG_MODEL.apply(:a).singleton_methods(false)
# => includes :component_a, :component_b

## $EG_MODEL.apply(:a).component_b("b").singleton_methods(false)
# => includes :inst_method_b, :component_d

## $EG_MODEL[:component_b].dsl_methods
## => {:inst_method_b => #<Proc ...>}


$EG_APPLIED = $EG_DSL.apply

# $EG_APPLIED.component_a
## => new ComponentA component instance class on each call

# $EG_APPLIED.component_b
## => new ComponentB macro prototype class on each call

## b = $EG_APPLIED.component_b("b"); b.inst_method_b("...")
# >> b => "..."
# => #<Component_b 0x004b14 b>

## b = $EG_APPLIED.component_b("b"); b.inst_method_b("...").eql?(b)
## => true


##
## @!group OptionGroup API
##

##
## @!group OptionGroup API - Mixins and protocol classes
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


require 'mixlib/config'

## Base class for DSL definitions in the OptionGroup API
class OptionBase < DslBase
  class << self

    ## @private
    ##
    ## If superclass is an OptionBase class, ensure that any component
    ## name for the class is inherited by the prototype
    def prototype(role, superclass = self)
      ## more specific than definiing a method on 'inherited'
      proto = super
      if superclass.ancestors.include?(self) && superclass.component_name?
        proto.instance_variable_set(:@component_name, superclass.component_name)
      end
      proto
    end

    ## @private
    def to_component_name(name)
      if (String === name)
        name.to_sym
      else
        ## symbol, other
        name
      end
    end

  end ## class << OptionBase
end ## OptionBase


## TBD adapting this application profile DSL for project.yaml validation

## DSL class for Option definitions within an OptionGroup model
class Option < OptionBase
  class << self

    def accept_block(&cb)
      STDERR.puts "! Option accept_block in #{self}"
      self.instance_eval(&cb) if cb
    end

    ## @private
    def inherited(subc)
      super
      if defined?(@optional)
        subc.instance_variable_set(:@optional, @optional)
      end
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

    def features
      instance_bind(:@features) do
        Hash.new do |_, name|
          raise ArgumentError.new(
            "Feature not found in #{self}: #{name.inspect}"
          )
        end
      end
    end

    def feature?(name)
      features.include?(name)
    end

    def compile_schema(group, schema_dsl, results)
      if schema_feature?
        sch = schema_feature
      else
        sch = prototype("schema_default", SchemaFeature)
        results.push_warning(group, self.component_name, :schema,
                             "No schema syntax defined")
      end
      sch.compile(self, group, schema_dsl, results)
    end

    def compile_features(group, contract, results)
      optname = self.component_name
      self.features.each do |_, feature|
        feature.compile(self, group, contract, results)
      end

      ## If no default was provided, ensure that the option will be
      ## listed as configurable for the Mixlib::Config integration
      if ! self.features.include?(:default)
        ## ... not reached (?)
        results.push_warning(group, optname, :default,
                             "No default defined")
        init = lambda { |store|
          store.configurable(optname)
        }
        group.config_initializers.push(init)
      end

      group.class_eval do
        rd_lmb = lambda {
          if rd_lmb.instance_variable_defined?(:@method)
            mtd = rd_lmb.instance_variable_get(:@method)
            mtd.call
          elsif self.instance_variable_defined?(:@config_store)
            store = self.instance_variable_get(:@config_store)
            mtd = store.method(optname)
            rd_lmb.instance_variable_set(:@method, mtd)
            mtd.call
          else
            raise RuntimeError.new("Unable to call #{optname} for #{self}")
          end
        }
        STDERR.puts "! define reader method #{optname} for #{self}"
        define_method(optname, &rd_lmb)

        wr_mtd = (optname.to_s + "=").to_sym
        wr_lmb = lambda { |value|
          if wr_lmb.instance_variable_defined?(:@method)
            mtd = wr_lmb.instance_variable_get(:@method)
            mtd.call(value)
          elsif self.instance_variable_defined?(:@config_store)
            store = self.instance_variable_get(:@config_store)
            mtd = store.method(wr_mtd)
            wr_lmb.instance_variable_set(:@method, mtd)
            mtd.call(value)
          else
            raise RuntimeError.new("Unable to call #{wr_mtd} for #{self}")
          end
        }
        STDERR.puts "! define writer method #{wr_mtd} for #{self}"
        define_method(wr_mtd, &wr_lmb)
      end

    end ## compile_features


    ## @private
    def apply(name, *args, optional: true, **rest, &block)
      STDERR.puts "!DEBUG applying option #{self} :: #{name}"
      rslt = super(*args, **rest) do
        ## component name is required for 'option' components
        self.instance_variable_set(:@component_name, to_component_name(name))
        self.instance_variable_set(:@optional, optional ? true : false)
        self.accept_block(&block) if block
        ## applied subsequently, in super(...)
      end
      STDERR.puts "!DEBUG option features: #{rslt.features}"
      rslt
    end

    ## @private
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

      STDERR.puts "! Option applied @ #{self} feature : #{feature.inspect}"

      if (name = feature.component_name)
        if (name == :schema)
          if defined?(@schema)
            ## TBD warn or pass to a callback instead of fail here
            raise RuntimeError.new("Schema sytntax already defined for #{self}")
          else
            @schema = feature
          end
        elsif self.feature?(name) && ! self.features[name].eql?(feature)
          msg = "Feature already exists for name %p in %s" % [
            name, self
          ]
          raise RuntimeError.new(msg)
        else
          self.features[name] = feature
        end
      else
        STDERR.puts ("[DEBUG] applied anonymous feature #{feature} @ #{self}")
      end
      return feature
    end


  end ## class << Option

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
  class << self

    alias_method :option, :__scope__

    attr_reader :callback

    def callback?
      defined?(@callback)
    end

    ## protocol method
    ##
    ## receives a block from a DSL source expression, during 'apply'
    ##
    ## This method stores the block for scoped evaluation under
    ## callback_eval, or for direct access to the block via
    ## callback_proc
    ##
    ## overrides DslBase#accept_block
    ##
    def accept_block(&cb)
      STDERR.puts "! Feature accept_block in #{__scope__} // #{self}"
      callback(&cb)
    end

    def callback_proc
      if callback?
        @callback
      else
        raise RuntimeError.new("No callback defined for #{self}")
      end
    end

    def callback_eval(scope)
      scope.instance_eval(&@callback) if callback?
    end

    def callback(&block)
      if callback?
        raise ArgumentError.new("Callback already bound for #{self}")
      else
        @callback = block
      end
    end

  end ## class << Feature

end ## Feature

## Option Feature class for option schema features
##
## @see compile
class SchemaFeature < Feature
  class << self

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

      if ! (optname = option.component_name)

         raise RuntimeError.new("Option has invalid component name: #{option}")
      end

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
end

## Option Feature class for option rule features
##
## This class can be applied using the `rule` method under an `option`
## expression in an **OptionGroup** definition. The method will be
## available under an `apply` block for the containing **OptionGroup**
##
## Within an `option` expression under an **OptionGroup** definition,
## the `rule` method should generally be provided with a block. The
## block will be evaluated  `compile` on the containing **OptionGroup**,
## within he scope of a Dry::Validation::Evaluator. The block should
## provide any method calls such as to validate any value provided for
## the containing **Option**. These methods would normally be avaialble
## under a `rule` expression with Dry::Validation.
##
## If the containing option is defined as `optional` then the callback
## will be called only when the containing option is present in the
## input value to be validated. The value may be present with a value of
## `nil` or `false.
##
## If the containing option is not defined as `optional` then the
## callback will be called under every validation of a given input
## value.
##
## After any failed validation, the corresponding option should be
## visible under the validation results for the provided input value.
##
## @example
##   FIXME - see tests
##
## @see DefaultFeature
## @see compile
## @see validate
class RuleFeature < Feature

  class << self

    ## @private
    ##
    ## Callback method for OptionGroup.compile
    ##
    def compile(option, group, contract, results)
      optname = option.component_name
      if self.callback?
        if option.optional?
          r = self
          contract.rule(optname) do
            ## This block will be scoped to the evaluation of a Dry
            ## Validation rule.
            ##
            ## In this block, Dry::Validation::Evaluator === self
            ##
            ## The call to the 'key?' method should return a non-falsey
            ## value when the given option name is present in some input
            ## value to be validated.
            ##
            ## For optional values, this provides an initial check to
            ## ensure that the callback should not be called if the
            ## option is not present in the input value. This may serve
            ## to minimize some coding, when defininig a validation rule
            ## for an optional option value.
            ##
            ## If the option is present but was provided with a nil or
            ## false value, the callback should still be called here.
            ##
            ## For validation within the callback. as in order to access
            ## the input value for validating the described option, the
            ## callback block should be able to call the 'value' method
            ## in the block. Other methods on the Dry Validation's
            ## Evaluator should also be available in the block.
            ##
            ## An example application is provided for validation of a
            ## shell command name, in the profile test.
            ##
            ## If called, the callback block for this RuleFeature should
            ## be immediately evaluated, scoped to the present Dry
            ## Evaluator
            r.callback_eval(self) if key?(optname)
          end
        else
          ## Callback for a required option value. This will always
          ## dispatch to the callback.
          ##
          ## The block will be evaluated within a scope similar to the
          ## optional case
          contract.rule(optname, & self.callback_proc)
        end
      else
        ## no callback, though a RuleFeature was provided in the DSL
        results.push_warning(group, optname, self.component_name,
                             "Rule defined with no callback")
      end
    end

  end
end

## Option Feature class for default value callbacks and literal default
## values
##
## **Initialization and Setting a Default Value**
##
## Within an `option` DSL expression describing an **Option** under an
## **OptionGroup**, an **OptionDefault** can be initialized for the
## **Option** using the method `default`.
##
## If a `:default_value` is provided in the `defualt` call,
## that value will be used as a default value for the described option.
##
## Any block provided to the `default` method will be applied under
## Mixlib::Config for determining a default value. The default value
## will be determined for any option not provided with an input value, at
## time of access.
##
## A default block will override any provided `:default_value`
##
## Example
## ~~~~
## (FIXME) see tests
## ~~~~
##
## The `default` method will be avaialble within a singleton
## scope, within a DSL `option` expression under an **OptionGroup**
##
## Any default value or default callback will be used under the `apply`
## method for the described Option.
##
## If no `default` is provided for an `option` expression, it will
## be assumed that the `option` has no default value.
##
## @see Option
##
class OptionDefault < Feature

  class << self

    ## @private
    def inherited(subc)
      super
      if defined?(@default_value)
        ## ensure the value is inherited by prototype subclasses
        subc.instance_variable_set(:@default_value, @default_value)
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
      optname = option.component_name
      init = nil
      if defined?(@default_value)
        ## not reached
        init = lambda { |store|
          store.default(optname, @default_value)
        }
      elsif defined?(@callback)
        init = lambda { |store|
          store.default(optname, & @callback)
        }
      else
        init = lambda { |store|
          store.configurable(optname)
        }
        results.push_warning(group, optname, self.component_name,
                             "No default value or callback was provided")
      end
      group.config_initializers.push(init) if init
    end

    def apply(*args, **options, &block)
      if options.include?(:default_value)
        @default_value = options[:default_value]
        options.delete(:default_value)
      end
      super
    end

  end ## class << OptionDefault

end ## OptionDefault class


## Encapsulation for applications of Mixlib::Config in an OptionGroup
## instance scope
##
## Instances of this class will extend Mixlib::Config at a singleton
## scope.
##
## Each instance will be initialized with a default configuration
## using Mixlib::Config `strict_mode` for the instance. This should
## generally affect the validation of any input value provided to a
## containing **OptionGroup**
##
module OptionConfig
  ## This method extends Mixlib::Config, for customization in
  ## OptionGroup instance configuration
  def self.extended(whence)
    whence.extend Mixlib::Config
    whence.config_strict_mode true
  end

  ## @private
  ## define forwarding for some singleton methods from Mixlib::Config,
  ## to forward to similarly named methods on the receiver
  ##
  ## @param receiver [Object] the object to receive the forwarding
  ##  methods
  def define_forwarding(receiver)
    ## TBD: this API does not provide interop. for Mixlib::Config contexts
    receiver.extend Forwardable
    %w(configuration configuration= configurables).each do |mtd|
      receiver.def_delegator(:@config_store, mtd)
    end
    receiver
  end
end

class ConfigStore
  def initialize()
    ## ensure that all singleton methods form Mixlib::Config
    ## will be available at an instance scope
    self.extend OptionConfig
  end
end


##
## Implementation class for defining a group of Option for some
## configuration scope
##
class OptionGroup < OptionBase
  class << self

    ## @private
    def config_initializers
      @config_initializers ||= Array.new
    end

    ## @private
    def applied(cls)
      ## called after this OptionGroup is evalued under 'apply',
      ## as a top-level DSL
      ##
      ## also called for any immediate macro elements of the OptionGroup
      STDERR.puts "! OptionGroup #{self} applied: #{cls}"
      precedence = cls.ancestors
      if precedence.include?(Option)
        options[cls.component_name] = cls
      elsif precedence.include?(self)
        ## top-level DSL applied
        cls.compile
      else
        msg = "Unrecognized component: %p (%s)" % [cls, cls.class]
        raise RuntimeError.new(msg)
      end
    end

    ## Initialize the DSL model for this OptionGroup
    def model(&block)
      if defined?(@model)
        @model
      else
        super() do
          ## NB OptionGroup.model.macros => {:option => ...}


          dsl(:option, macro: true, base_class: Option) do
            STDERR.puts "[!DEBUG] option DSL scope #{__scope__}"
            STDERR.puts "[!DEBUG] option DSL self #{self}"

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

            dsl(:schema, macro: true, base_class: SchemaFeature) do
              ## define the option's schema
              ##
              ## in application: Required field.
              ##
              ## any callback defined in the :schema profile field
              ## will be evaluated in the scope of a Dry::Schema
              ## schema DSL
            end

            dsl(:rule, macro: true, base_class: RuleFeature) do
              ## define a validation rule for the option.
              ##
              ## in application: This is an optional field,
              ##
              ##
              ## any callback defined in the :rule profile field
              ## will be evaluated in the scope of a Dry::Validation
              ## schema rule DSL
            end

            dsl(:default, macro: true, base_class: OptionDefault) do
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

        end ##
        @model.accept_block(&block) if block
        @model
      end
    end  ## def model

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
    ## configuration model for this OptionGroup has been defined.
    ##
    ## @note This method will be called automatically as at the end of
    ## `apply` for the defininig OptionGroup, furthermore at the
    ## beginning of the constructor.
    ##
    ## @note Once `compile` is initially called for an OptionGroup
    ## class, the results of that `compile` call will be cached for the
    ## individual class, then returned by any later call to
    ##`compile`. If the OptionGroup definition is updated after the
    ## initial call to `compile`, the method `recompile` may be called.
    ## `recompile` will clear any cached results from `compile` and
    ## will call `compile` again, for the class. On event of error,
    ##`recompile` will restore any initial values for the cached data.
    ##
    ## @return [CompilerResult]
    ##
    ## @see recompile
    ## @see contract
    ## @see validate
    def compile(defer_warnings: ! $DEBUG)
      ## Usage: Refer to the TestProfile example, mainly the 'profile'
      ## method defined there
      if rslt = @compiler_result
        return rslt
      else
        STDERR.puts "[DEBUG] Building validation contract for #{self}" ## if $DEBUG

        ## NB this creates a new class singularly for the @contract,
        ## there receiving all option/param schema & option/param rule
        ## definitions for this class

        cls = self.prototype("validation", Dry::Validation::Contract)

        results = CompilerResult.new(cls, self, defer_warnings: defer_warnings)
        ## storage for this option group within the following block
        group = self

        ## compile all option schema definitions, before any processing
        ## for non-schema features
        cls.schema do
          ## class schema scope via Dry::Validation
          ##
          ## in this block: Dry::Schema::DSL === self
          schema_dsl = self
          group.options.each do |_, opt|
            opt.compile_schema(group, schema_dsl, results)
          end
        end
        ## compile all non-schema features
        self.options.each do |_, opt|
          opt.compile_features(group, cls, results)
        end
        @contract = cls
        @compiler_result = results
      end
    end

    ## Return the set of options defined to this OptionGroup
    ##
    ## This value will generally be initialized during `compile`
    ##
    ## @see compile
    def options()
      @options ||= Hash.new do |_, k|
        raise ArgumentError.new("Option not found in #{self}: #{k.inspect}")
      end
    end

    def [](name)
      self.options[name]
    end

    ## Return the schema for the validation contract to this OptionGroup
    ##
    ## @return [Dry::Schema] the schema
    ##
    ## @see contract
    ## @see compile
    ## @see recompile
    def schema
      self.contract.schema
    end

    ## Return the Dry::Validation rules object for the validation
    ## contract to this OpitonGroup
    ##
    ## @return [Array<Dry::Validation::Rule>]
    ##
    ## @see contract
    ## @see compile
    ## @see recompile
    def rules
      self.contract.rules
    end

    ## Compile and return the Dry Validation Contract for this OptionGroup
    ##
    ## @return [Dry::Validation::Contract]
    ##
    ## @see compile
    ## @see recompile
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
    ## @see contract
    ## @see compile
    def recompile
      previous_class = @contract
      previous_instance = @contract_validate
      previous_init = @config_initializers
      @contract = nil
      @contract_validate = nil
      @compiler_result = nil
      @config_initializers = Array.new
      begin
        compile
      rescue
        @contract = previous_class
        @contract_validate = previous_instance
        @config_initializers = previous_init
        raise
      end
    end

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

  ## Return the profile name for this OptionGroup
  attr_reader :profile_name

  ## Initialize a new OptionGroup
  ##
  ## This constructor will define a set of singleton methods for the
  ## instance. These methods will provide support, in effect, for reading
  ## or setting the value of each named option defined in the class
  ## scope for the OptionGroup
  ##
  ## @param name [Object] the profile name for this OptionGroup. This
  ##  value is stored internal to each OptionGroup instance
  ##
  ## @see validate
  def initialize(name)
    super()
    @profile_name = name

    ## Integration for Mixlib::Config
    ##
    ## @config_store should not be changed on the instance, once set
    store = ConfigStore.new
    @config_store = store
    self.extend Forwardable
    store.define_forwarding(self)
    self.class.config_initializers.each do |proc|
      proc.yield(store)
    end
  end

  ## Return a Hash representing all options configured for this
  ## OptionGroup
  ##
  ## @param defaults_p [boolean] If a truthy value, the return value will
  ##  include any default option values defined for this OptionGroup. If
  ##  a falsey value, the return value will include only #  the values
  ##  that have been directly set for options to this OptionGroup
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
    inst = (@contract_validate ||= self.class.contract.new)
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
    @config_store.configuration.include?(name)
  end

  ## Unset the named option for this OptionGroup
  #
  ## @param name (see #option_set?)
  def option_unset(name)
    @config_store.configuration.delete(name)
  end

  def to_s
    conf_set = self.configuration.keys.map(&:to_s).join(" ")
    "#<%s 0x%06x (%s)>" % [
      self.class.name, __id__, conf_set
    ]
  end

  def inspect
    to_s
  end

end ## OptionGroup

# @!endgroup OptionGroup API - Mixins and protocol classes
# @!endgroup OptionGroup API

##
## Tests @ OptionGroup class definition
##

# mdl = OptionGroup.model; mdl.__scope__.eql?(mdl)
## => true

## OptionGroup does not iself define any options for its model


##
## Tests @ Initial Implementation
##

###
### testing w/ the class-scoped approach  ..
###

class TestProfile < OptionGroup
  class << self

    def profile(name)
      ## Apply the OptionGroup.model DSL for defininig a single
      ## configuration profile, for purpose of tests
      ##
      ## The call to 'apply' will finally compile the defined
      ## OptionGroup class, before returning that class.
      ##
      ## For the class returned by this profile method, any zero or more
      ## instances can be initialized from the class, with each serving
      ## as a usable OptionGroup instance. i.e as defined here, the
      ## 'shell' and 'item' fields can read/written on the instance,
      ## with validation for values as set.
      prototype =  apply(name) do

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

        end ## :shell

        option(:item) do
          default(default_value: -1)
        end ## :item

        STDERR.puts("[DEBUG] end of apply => #{self}")
      end
      prototype
    end

  end ## class << TestProfile

end

##
## Testing application of the profile DSL's implementation
##

=begin TESTS

$PROFILE_CLS = TestProfile.profile(:tbd)

$PROFILE_CLS.options
## => => {:shell=>Option[macro](..), :item=>Option[macro](...)}

$PROFILE = $PROFILE_CLS.new(nil)

$PROFILE.configurables
## => {:shell => #<Mixlib::...>, :item => #<Mixlib::...> }

$PROFILE.shell = "bash"
$PROFILE.shell

$PROFILE.item = 1

$PROFILE_CLS.recompile

$PROFILE.shell = "nosh"
$PROFILE.validate
$PROFILE.shell ## should be the default value now

=end
