## options.rb - Trivial options API

## Trivial Options API
module OptionMap
end

## TBD YARD tries to add docs to this require call (??)
require_relative('./assochash')


## *Option* base class.
##
## Any *Option* implementation must provide a +value+
## reader method
##
## @abstract
## @see SimpleOption
## @see ValueOption
class OptionMap::Option

  ## Baseline constructor for *Option* implementations
  ##
  ## @param name [Symbol] option name
  def initialize(name)
    @name = name
  end

  ## The name of the option, typically a *Symbol*
  attr_reader :name
end


## Subclass of *Option* that is not a *ValueOption*
##
## Generally, the presence of a *SimpleOption* in an *OptionMap*
## would indicate a value of "true" for that option
##
## Conversely, the absence of a *SimpleOption* for any
## named option would generally indicate a value of 'false'
## for that option
##
## @see ValueOption
## @see OptionMap
class OptionMap::SimpleOption < OptionMap::Option

  ## Return +true+
  ##
  ## @return [true] true
  def value()
    return true
  end
end


## **Option** class that accepts an arbitrary option value
##
## @see SimpleOption
## @see OptionMap
class OptionMap::ValueOption < OptionMap::Option

  ## Create a new *ValueOption* wth the provided +name+ and +value+
  ##
  ## @param name [Symbol] The option's name
  ## @param value [not false] The option's value
  def initialize(name, value)
    super(name)
    @value = value
  end

  ## The value of the option.
  ##
  ## To avoid ambiguity with the boolean interpretation of
  ## *SimpleOption*, this value should generally be other than
  ## +true+ or +false+
  attr_accessor :value
end


## General container for **Option** instances
##
## === Known Limitations
##
## This class does not presently provide any support for
## representation of option values as external to any single
## *OptionMap*. i.e this does not provide direct support for any
## mapping of option values onto any specific shell command
## syntax.
##
## @see Option
class OptionMap::OptionMap < AssocHash::AssocHash

  ## Internal constant for the *AssocHash* implementation
  NAMEPROC= lambda { |obj| obj.name }

  ## Create a new *OptionMap*, initialized with the set of provided +options+
  ##
  ## @param options [Hash|Array|nil] options to store in the new +OptionMap+.
  ##  If a *Hash*, each key in the hash will provide an option name and each
  ##  and each value, the corresponding option value. If an *Array*, every
  ## element will be interpreted as an option name, with all options in the
  ## array set to a value of 'true'
  ##
  def initialize(options = nil, default: false)
    ## FIXME provide an overwrite proc to super()
    super(NAMEPROC, default: default)
    if options.instance_of?(Hash)
      options.each do |opt, optv|
        self.setopt(opt,optv)
      end
    elsif options.instance_of?(Array)
      ## FIXME parse each elemment for splitting any name=value expression
      options.each do |opt|
        ## TBD string to symbol mapping
        ## - Trim any leading "-*"
        ## - TBD integration with ruby getopts equiv,
        ##   for OptionMap usage in cmdline apps
        ## - String#to_sym
        ##   NB :":Frob"
        self.setopt(opt,true)
      end
    end
  end

  ## Return the option's value, if any option of the provided +name+
  ## is present, else return false
  ##
  ## @param name [Symbol] option name
  ## @return [any] the value of the option, or +false+ if no option is
  ##  registered for the +name+
  def getopt(name)
    ## FIXME document this behavior: The default value
    ## for the OptionMap is now provided via either
    ## a default proc or default symbol provided
    ## during OptionMap initialization - using a
    ## semantics same as with Hash. If a proc,
    ## the default would be called with the
    ## OptionMap (NB not the delegete Hash itself) as its first
    ## arg and the key value that was "not found" as its
    ## second arg. If not a proc, the default
    ## will be returned as a literal value, for any
    ## option name not stored in the OptionMap
    ##
    ## Implementations should ensure that the default
    ## value (or the return value of the default proc)
    ## provided to the OptionMap will be valid as an
    ## option value, when returned from #getopt.
    ##
    ## In short, the default is to use
    ## a default value of false
    ##
    if self.member?(name)
      oopt = self.opt_getobj(name)
      return oopt.value
    elsif self.table.default_proc
      return self.table.default_proc.call(self,name)
    else
      return self.table.default
    end
  end

  ## Record the provided +value+ for an *Option* of the provided +name+
  ##
  ## @param name [Symbol] option name
  ## @param value [any] option value
  ## @return the value for the option
  def setopt(name, value = true)
    if self.member?(name)
      oopt = self.opt_getobj(name)
      ## updating the OptionMap per the provided value.
      ## this may operate destructively on the OptionMap
      if (value == true)
        if ! oopt.instance_of?(OptionMap::SimpleOption)
          ## NB type conversion under the containing OptionMap
          self.delete(name)
          self.opt_add(name)
          ## else: no-op - value of 'true' is already represented by the
          ## presence of a SimpleOption
        end
      elsif (value == false)
        self.delete(name)
      # elsif (value.nil?)
      #   ## FIXME TBD - assumption: Relevant only for a ValueOption,
      #   ## but would be context-dependant as to what action here,
      #   ## e.g retain the option but produce an empty value later,
      #   ## such as with "--name=" in some syntax transformations, or
      #   ## delete the option, immediately.
      #   ##
      #   ## Presently, the API will retain any ValueOption that has a
      #   ## value of nil. This may be handled during any later mapping
      #   ## to any specific shell command syntax or other usage.
      #
      ## assumption: the value (neither true nor false) requires a ValueOption
      elsif oopt.instance_of?(OptionMap::ValueOption)
        oopt.value = value
      else
        self.delete(name)
        self.opt_add(name, value)
      end
    elsif (value != false)
      ## NB this API will not store any option value of false
      ##
      ## If, in some mapping to an output syntax, any option value
      ## representative of a user-provided value of 'false' must be
      ## provided in the output, that may be handled at the time of the
      ## output transformation, or this API may be updated to support
      ## the particular usage case.
      self.opt_add(name,value)
    end
    return value
  end

  ## remove any option of the provided +name+
  ##
  ## @param name [Symbol] option name
  ## @return [Boolean] true if an option of the provided +name+ was stored in the *OptionMap+
  def remopt(name)
    self.delete(name)
  end

  protected

  ## trivial encapsulation onto the present implementation as an *AssocHash+
  ##
  ## @param name [Symbol] option name
  def opt_getobj(name)
    return self.get(name)
  end

  ## utility method for +#setopt
  ##
  ## Assumptions
  ## - No calling method should provide a value of false
  ## - No calling method should provide a name that is
  ##   already used for an Option in the +OptionMap+
  ##
  ## @param name [Symbol] option name, unique onto the +OptionMap+
  ## @param value [not false] option value
  def opt_add(name, value = true)
    if (value == true)
      oopt = OptionMap::SimpleOption.new(name)
    else
      oopt = OptionMap::ValueOption.new(name, value)
    end
    self.add(oopt)
  end

end

# Local Variables:
# fill-column: 65
# End:
