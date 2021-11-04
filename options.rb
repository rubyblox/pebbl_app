## options.rb - trivial Option/ValueOption/OptionSet API


require('set')

class Option
  def initialize(name)
    @name = name
  end
  attr_reader :name
  def value()
    ## NB OptionSet.get(name) => false
    ##    should indicate that no option of name 'name' is present
    ## whereas OptionSet.get(name) => nil
    ##    should indicate an option of 'name' is present, with a nil value
    return true
  end
end


# ## ??
# class MappedSet < Set
#   def initialize(keytest)
#     super()
#     @keytest = keytest
#     @membermap = {}
#   end
#   ## Hash ??
#   def [](key)
#     return membermap[key]
#   end
#
#   def []=(key, obj)
#     if super.member?(key)
# #      super.delete_if() ... keytest ... key
#       super.add(obj)
#       membermap[key] = obj; ## redundant now
#     else
#       super
#   end
# end

module OptionsConstants
  THIS = lambda { |a| a.itself }
  ## FIXME need to store the actual hash and key in the exception, for debugging ..
  KEYFAIL = lambda { |hash, key| raise("No value provided for key #{key} in #{hash.class} {...}") }
  ## for convenience, in AssocHash.initialize
  KEYTRUE = lambda { |hash, key| return true }
  KEYFALSE = lambda { |hash, key| return false }
  KEYNIL = lambda { |hash, key| return nil }
end

## alternately ...
class AssocHash < Hash

  ## FIXME cannot provide two &procsarg (??)
  # def initialize(&keytest, &defaultProc)
  #   super(&defaultProc || OptionsConstants::KEYFAIL)
  #   @keytest = ( keytest || OptionsConstants::THIS )
  # end

  ## FIXME cannot provide a non-proc arg after a &procarg (??)
  # def initialize(&keytest, default)
  #   super(default) ## TBD probably doesn't accept a proc here
  #   @keytest = ( keytest || OptionsConstants::THIS )
  # end

  ## FIXME using a static "hash default" function here. See previous
  ## FIXME may define an AssocHashConfig class, to work around this & more ...
  def initialize(&keytest)
    super(&OptionsConstants::KEYFAIL)
    @keytest = ( keytest || OptionsConstants::THIS )
  end
  
  ## TBD "print method" for this extension on Hash 
  ## => revise this implementation to use delegation

  protected def []= ( key, value )
    ## NB encapsulating this setter
    super[key] = value
  end

  def add(obj, overwrite = false)
    usekey=key(obj)
    if self.member?(usekey) 
      if (obj == self[usekey])
        return obj
      elsif ! overwrite
        ## TBD not using all of the print form of #{self} but truncated, in the condition message
        raise("An object is already registered for key #{usekey} in #{self.class} #{self}")
      end
    end
    ## FIXME []= is being processed as a method on obj here?
    # self[usekey]=obj
    ## ?? and still ! what is being read as 'self' here? and yet it still evaluates ????
    self.[]=(usekey,obj)
    return obj
  end

  def get(key)
    ## NB convenience method
    ##
    ## NB this and the delegate method may both result in a raised exception
    ##
    ## see also: Hash#exists?
    return self[key]
  end

  def key(obj)
    ## NB utility method, does not imply membership for the object in this AssocHash
    @keytest.call(obj)
  end

end

## FIXME untested below

class ValueOption < Option
  def initialize(name, value = nil)
    super(name)
    @value = value
  end
  attr_accessor :value
end


class OptionSet < Set
  def initialize(options = nil)
    ## FIXME "Object doesn't support #inspect" during "new"
    ## FIXME cannot call nil.each ??
    if ! options.nil?
      options.each do |opt, optv|
        oopt = Option.new(opt, optv)
        self.add(oopt)
      end
    end
  end

  protected def addOption(name, value = true)
    if (value == true)
      oopt = Option.new(name)
    else
      oopt = ValueOption.new(name, value)
    end
    self.add(oopt)
  end

  protected def getoptObj(name)
    ## NB encapsulation for this class' present implementation
    ## onto Set

    ## FIXME how to actually implement this now?
    return self[name]
  end

  def getopt(name)
    ## return the option's value if it's a ValueOption, 
    ## else retrurn true
    oopt = self.getoptObj(name)
    if oopt.instance_of(ValueOption)
      return oopt.value
    else
      return true
    end
  end

  def setopt(name, value = true)
    ## TBD if an option exsits for the provided name
    ## and is a ValueOption, this will set the value
    ## of that option to 'true', rather than removing
    ## the option and adding a plain boolean Option.
    ##
    ## This behavior may serve to present some ambiguity
    ## for any exclusively value-oriented parse of
    ## the options in this OptionSet
    oopt = self.getoptObj(name)
    if oopt
      oopt.value = value
    else
      oopt = self.addOption(name, value)
    end
    return value
  end

  def remopt(name)
    oopt = getoptObj(name)
    if oopt
      self.delete(oopt)
    end
  end
end
