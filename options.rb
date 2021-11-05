## options.rb - trivial Option/ValueOption/OptionSet API

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
    return lambda { |hash, key| raise("Found no key #{key} in #{whence.class} #{whence.object_id}") }
  end

  def initialize(&keytest)
    ## FIXME cannot provide both the keytest and the hash default proc
    ## as both representing proc-format args?
    @table = Hash.new(&self.class.table_default(self))
    @keytest = ( keytest || OptionsConstants::THIS )
  end


  def add(obj, overwrite = false)
    ## NB if the object is modified later, such that it would no longer
    ## return the same value under the @keytest proc, then this may
    ## result in unexpected behaviors due to the subsequent mismatch of
    ## the object's key value and its storage under the AssocHash
    ##
    ## It may be recommended to use only a read-only value as the key
    ## for any object referenced in an AssocHash
    usekey=key(obj)
    if @table.member?(usekey)
      if (obj == @table[usekey])
        return obj
      elsif ! overwrite
        ## FIXME should  using not all of the print form of #{self} but truncated, in the condition message
        raise("An object is already registered for key #{usekey} in #{self.class} #{self}")
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

## alternately ...
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
    return lambda { |hash, key| raise("Found no key #{key} in #{whence.class} #{whence.object_id}") }
  end

  def initialize(&keytest)
    ## FIXME cannot provide both the keytest and the hash default proc
    ## as both representing proc-format args?
    @table = Hash.new(&self.class.table_default(self))
    @keytest = ( keytest || OptionsConstants::THIS )
  end


  def add(obj, overwrite = false)
    ## NB if the object is modified later, such that it would no longer
    ## return the same value under the @keytest proc, then this may
    ## result in unexpected behaviors due to the subsequent mismatch of
    ## the object's key value and its storage under the AssocHash
    ##
    ## It may be recommended to use only a read-only value as the key
    ## for any object referenced in an AssocHash
    usekey=key(obj)
    if @table.member?(usekey)
      if (obj == @table[usekey])
        return obj
      elsif ! overwrite
        ## FIXME should  using not all of the print form of #{self} but truncated, in the condition message
        raise("An object is already registered for key #{usekey} in #{self.class} #{self}")
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

## FIXME untested below

class ValueOption < Option
  def initialize(name, value = nil)
    super(name)
    @value = value
  end
  attr_accessor :value
end


class OptionSet < AssocHash
  ## FIXME update for the AssocHash implementation

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
