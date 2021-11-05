## assochash.rb - Hash with configurable key evaluation

module AssocHashConstants
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
                 :include?, :has_key?, :key?, :member?)

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
    ## NB another convenience method for class defaults
    ##
    ## FIXME this needs a more specific conditions API
    return lambda { |key, obj|
      raise("An object is already registered for key #{key} \
in #{whence.class} #{whence.object_id}") }
  end

  def initialize(keytest: AssocHashConstants::THIS,
                 default: self.class.table_default(self),
                 overwrite: self.class.overwrite_default(self))
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

