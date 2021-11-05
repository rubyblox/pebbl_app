## options.rb - Trivial options API

module OptionsConstants
  THIS = lambda { |a| a.itself }
end

require('forwardable')
class AssocHash

  extend(Forwardable)
  include(Enumerable)
  ## NB not forwarding :[]=
  ##
  ## The method AssocHash.add(..) would be used to add elements to the
  ## delegated hash @table, with conditional checking to prevent storage
  ## of objects having a duplicate key under the @keytest proc.
  ##
  ## While the :[]= method may represent a familiar method name for
  ## collections in Ruby, it would need at least an additional arg
  ## (i.e overwrite flag) and a check for parity between the key value
  ## provided to the method and that under which the object will be
  ## actually stored. Alternately, :add may be called directly
  def_delegators(:@table,
                 :[], :delete, :each, :keys, :values,
                 :length, :empty?,
                 :include?, :has_key?, :key?, :member?
                )

  def self.table_default(whence)
    ## NB convenience method for a more informative exception message
    ## under #initialize, such that the exception message may reference
    ## the AssocHash encapsulating the referring hash table
    ##
    ## FIXME need to define a new exception class, to include the
    ## AssocHash in the exception object, for purpose of debugging ...
    ##
    return lambda { |hash, key|
      raise("Found no key #{key} in #{whence.class} #{whence.object_id}")
    }
  end

  def self.overwrite_default(whence)
    return lambda { |key, obj|
      raise("An object is already registered for key #{key} \
in #{whence.class} #{whence.object_id}") }
  end

  def initialize(keytest: OptionsConstants::THIS,
                 default: self.class.table_default(self),
                 overwrite: self.class.overwrite_default(self)
                )
    @table = Hash.new(&default)
    @keytest = keytest
    @overwrite_proc = overwrite
  end


  def add(obj, overwrite = false)
    ## NB if an object added to an AssocHash is modified later, such
    ## that it would no longer produce the same value under the @keytest
    ## proc, such a change may result in unexpected behaviors due to the
    ## subsequent disparity of the object's active key value, compared
    ## to the object's storage under the AssocHash
    ##
    ## It may be recommended to use only a read-only value as the key
    ## for indexing under an AssocHash
    usekey=key(obj)
    if @table.member?(usekey)
      if (obj == @table[usekey])
        return obj
      elsif ! overwrite
        ## NB if the @overwrite_proc does not exit non-locally, e.g by
        ## 'raise', then the value may be overwritten after the
        ## @overwrite_proc is called
        @overwrite_proc.call(usekey,obj)
      end
    end
    @table[usekey]=obj
    return obj
  end

  def get(key)
    ## NB convenience method
    ##
    ## NB this and the :[] delegate method may both result in a raised
    ## exception, per how @table has been initialized
    ##
    ## see also: #member?
    return @table[key]
  end

  def key(obj)
    ## NB utility method, does not imply membership for the object in this AssocHash
    @keytest.call(obj)
  end

end


##
## Trivial options API
##

class Option
  ## a generally abstract Option class
  ##
  ## any Option implementation must provide a :value reader method
  def initialize(name)
    @name = name
  end
  attr_reader :name
end


class SimpleOption < Option
  ## subclass of Option that is not a ValueOption
  ##
  ## generally, the presence of a SimpleOption in an OptionMap
  ## would indicate a value of "true" for that option
  ##
  ## conversely, the absence of a SimpleOption for any
  ## named option would indicate a value of "false' for that option
  ##
  def value()
    ## NB OptionMap.get(name) => false
    ##    should indicate that no option of name 'name' is present
    ## whereas OptionMap.get(name) => nil
    ##    should indicate an option of 'name' is present, with a nil value
    return true
  end
end

class ValueOption < Option
  ## Option class that accepts an arbitrary value
  ##
  ## NB Here and elsewhere, this API uses a syntax assumed local
  ## to a single OptionMap. 
  ##
  ## Some Option expressions may require transformation before
  ## representation under an external syntax, e.g for representation
  ## under the syntax of any single shell command
  def initialize(name, value = nil)
    super(name)
    @value = value
  end
  attr_accessor :value
end


class OptionMap < AssocHash
  ## general container for Option instances

  NAMEPROC= lambda { |obj| obj.name }

  def initialize()
    super(keytest: NAMEPROC)
    # if ! options.nil?
    #   ## FIXME ... initialize from some provided values
    #   options.each do |opt, optv|
    #     oopt = Option.new(opt, optv)
    #     self.add(oopt)
    #   end
    # end
  end


  def getopt(name)
    ## return the option's value, if any option of the provided name
    ## is present, else return false
    if self.member?(name)
      oopt = self.opt_getobj(name)
      return oopt.value
    else
      return false
    end
  end

  def setopt(name, value = true)
    ## update the encapsulated @table to record the provided value
    ## for an option of the provided name
    ##
    ## NB this provides some implicit Option type conversion under the
    ## containing OptionMap, depending on the syntax of the provided
    ## value
    if self.member?(name)
      oopt = self.opt_getobj(name)
      ## updating the OptionMap per the provided value.
      ## this may operate destructively on the OptionMap
      if (value == true)
        if ! oopt.instance_of?(SimpleOption)
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
      elsif oopt.instance_of?(ValueOption)
        oopt.value = value
      else
        self.delete(name)
        self.opt_add(name, value)
      end
    elsif (value != false)
      ## NB this API will not store any option value of false
      ##
      ## If, in some mapping to an output syntax, any option value
      ## repreentative of a user-provided value of 'false' must be
      ## provided in the output, that may be handled at the time of the
      ## output transformation, or this API may be updated to support
      ## the particular usage case.
      self.opt_add(name,value)
    end
    return value
  end

  def remopt(name)
    if self.member?(name)
      oopt = opt_getobj(name)
      self.delete(oopt)
    end
  end

  protected 

  def opt_getobj(name)
    ## trivial encapsulation onto the present implementation as
    ## an AssocHash
    return self.get(name)
  end

  def opt_add(name, value = true)
    ## utility for #setopt
    ##
    ## Assumptions
    ## - No calling method should provide a value of false
    ## - No calling method should provide a name that is
    ##   already used for an Option in the OptionMap
    if (value == true)
      oopt = Option.new(name)
    else
      oopt = ValueOption.new(name, value)
    end
    self.add(oopt)
  end

end
