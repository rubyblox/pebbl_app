## assochash.rb - Hash with configurable key evaluation

## *AssocHash( namespace
module AssocHash
  THIS = lambda { |a| a.itself }
end

## Base class for *AssocHash* key exception classes
class AssocHash::KeyException < RuntimeError

  ## key value for the exception
  attr_reader :key

  ## container context for the provided key value
  attr_reader :container

  ## Base class constructor
  ## @key [any] Key value for the exception
  ## @container[AssocHash] container context of this *KeyException*
  ## @msg [String] message for the exception. A generic default value
  ##  is provided, for purpose of convenience
  def initialize (key, container,
                  msg = "KeyException: #{key} in #{container}" )
    super(msg)
    @key = key
    @container = container
  end

end

## Error class for "Key not found' exceptions
class AssocHash::KeyNotFoundError < AssocHash::KeyException
  def initialize(key, container,
                 msg = "Key not found: #{key} in #{container}")
    super
  end
end

## Error class for attempted overwrite of a bound value
## in an *AssocHash*
class AssocHash::KeyOverwriteError < AssocHash::KeyException
  attr_reader :stored_object
  attr_reader :new_object

  def initialize(key, stored, new, container,
                 msg = "Unable to store #{new} for key #{key} in #{container}. Object already stored: #${stored}})")
    super(key,container,msg)
    @stored_object = stored
    @new_object = new
  end
end


require('forwardable')
## Hash delegate class, for storing objects of
## a single type using a hash key value computed
## from a key_proc function on each value in the hash
class AssocHash::AssocHash

  extend(Forwardable)
  include(Enumerable)
  ## NB not forwarding :[]=
  ##
  ## The method AssocHash.add(..) would be used to add elements to the
  ## delegated hash @table, with conditional checking to prevent storage
  ## of objects having a duplicate key under the @key_proc proc.
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


  ## Convenience method for initialization of the encapsulated Hash
  ## object, under the *AssocHash* constructor, such that the default
  ## <em>default proc</em> for the encapsulated **Hash** would raise a
  ## *KeyNotFoundError*
  ##
  ## @param whence [AssocHash] context of the returned function
  ## @return [lambda] lamda form to use a default <em>default proc</em>
  ##  for the encapsulated Hash object, raising a *KeyNotFoundError*
  def self.table_default(whence)
    return lambda { |hash, key|
      raise new KeyNotFoundError(key, whence)
    }
  end

  ## convenience method for class defaults
  ## @param whence [AssocHash] context of the returned function
  ## @return [lambda] lamda form to use when testing for object
  ##  overwrite in the *AssocHash*. This function will raise a
  ##  KeyOverwriteError
  def self.overwrite_default(whence)
    ## NB
    ##
    ## - 'whence' would be of type AssocHash
    ## - 'obj' in the lambda would represent an object that
    ##   was to to be stored in whence, while an object
    ##   is already stored for 'key'
    ##
    ## This lambda would be called during a call to
    ## AssocHash#add, such that an object was provided to
    ## the call and that object is inequivalent to an
    ## object already stored in the AssocHash denoted by
    ## whence.
    ##
    ## In the general case of a lambda as an overwrite_proc
    ## for an AssocHash, If the lambda returns false or nil
    ## or performs a non-local exit (e.g with raise or throw)
    ##  then the new object -- here denoted by obj -- will
    ## not be stored for the key value. If this function
    ## returns a non-falsey value, the the object will be
    ## stored for that key value.
    ##
    ##
    ## This class method is used as a utility during
    ## AssocHash#initialize, in providng a default lambda
    ## for the  'ovewrite' parameter to the constructor.
    ## The default AssocHash#ovewrite_proc lambda would thus
    ## raise an error, preventing overwrite under any equivalent
    ## key value
    ##
    return lambda { |key, obj|
      raise new KeyOverwriteError(key, whence.get[key], obj, whence)
    }
  end


  ## Create a new *AssocHash*
  ## @param key_proc [lambda] Function to call for computing
  ##  an object's key value, as when adding an object to
  ##  this AssocHash
  ## @param default [any]
  ## @param overwrite [lambda]
  def initialize(key_proc: AssocHash::THIS,
                 default: self.class.table_default(self),
                 overwrite: self.class.overwrite_default(self))
    @table = Hash.new(&default)
    @key_proc = key_proc
    @overwrite_proc = overwrite
  end


  ## Cdd the provided object to this AssocHash
  ##
  ## This assumes that the 'obj' will respond to the *key_proc* form
  def add(obj)
    ## NB if an object added to an AssocHash is modified later, such
    ## that it would no longer produce the same value under the @key_proc
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
      elsif ! @overwrite_proc.call(usekey,obj)
        return false
      end
    end
    @table[usekey]=obj
  end

  ## may raise an exception, per the 'default proc' configuration
  ## of the encapsulated hash table
  ##
  ## @see Hash.include?
  def get(key)
    ## NB convenience method
    ##
    ## NB this and the :[] delegate method may both result in a raised
    ## exception, e.g if the @table has been initialized under this
    ## assoc hash such that the default lambda (proc) for the table
    ## would raise an error. This would be the default behavior, under
    ## the AssocHash constructor
    ##
    ## see also: the #member? delegate method on AssocHash
    return @table[key]
  end


    ## utility method, does not imply membership for the object in this AssocHash
    def key(obj)
      @key_proc.call(obj)
    end

    protected

    attr_reader :overwrite_proc
    attr_reader :key_proc
    attr_reader :table

end

