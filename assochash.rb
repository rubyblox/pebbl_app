## assochash.rb - Hash with configurable key evaluation

## Namespace for the *AssocHash* class
module AssocHash
end

## Base class for *AssocHash* key exception classes
class AssocHash::KeyException < RuntimeError

  ## key value for this exception
  attr_reader :key

  ## container context for this exception
  attr_reader :container

  ## Base class constructor
  ## @param key [any] Key value for the exception
  ## @param container [AssocHash] Container context for this exception
  ## @param msg [String] Message for the exception. A generic default value
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

  ## an object that is already stored in the *container*
  attr_reader :stored_object

  ## an object that was provided as to be stored under the same
  ## *key* as the *stored_object*
  attr_reader :new_object

  def initialize(key, stored, new, container,
                 msg = "Unable to store #{new} for key #{key} in #{container}. Object already stored: #{stored}})")
    super(key,container,msg)
    @stored_object = stored
    @new_object = new
  end
end


require('forwardable')

## *AssocHash* provides a *Hash* delegate class with dispatched
## evaluation for determining a hash key value for any object
## to be added to the delegate *Hash*. This behavior is
## implemented principally in the *#add* method. 
##
## The *#add*  method furthermore provides support for
## conditional evaluation under a condition of duplicate key
## values for non-equivalent objects.
##
## In addition to the special handling for object storage via
## *#add*, this class provides some extensions onto the
## _default_ behaviors of the delegate *Hash* object.
##
##
## @see  AssocHash::AssocHash#add
class AssocHash::AssocHash

  ## Class constant for providing a default +key_proc+ in
  ## *#initialize*.
  ##
  ## @see #initialize
  ITSELF_LAMBDA = lambda { |a| a.itself }

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
  ##
  ## FIXME rdoc does not grok this delegation call - all of these
  ## methods will have to be documented separately, here
  def_delegators(:@table,
                 :[], :delete, :each, :keys, :values,
                 :length, :empty?,
                 :include?, :has_key?, :key?, :member?)


  ## Convenience method for providing a <em>default proc</em>
  ## as a +lambda+ form to the +default+ parameter in the
  ## *AssocHash* constructor.
  ##
  ## @param whence [AssocHash] context of the returned
  ##  function. This object may not be fully initialized
  ##  when this *table_default* class method is called.
  ##
  ## @return [lambda] lambda form to use as a <em>default
  ##  proc</em> for in an initialized *AssocHash*
  ##
  ## @note The object +whence+ may not have been fully initialized 
  ##  when this *table_default* class method is evaluted
  ##
  ## @see #get
  ## @see AssocHash::KeyNotFoundError
  def self.table_default(whence)
    return lambda { |hash, key|
      raise new KeyNotFoundError(key, whence)
    }
  end

  ## Convenience method for providing a default +lambda+ form to
  ## the +overwrite+ parameter in the *AssocHash* constructor
  ##
  ## @param whence [AssocHash] context of the returned function.
  ##    
  ## @return [lambda] a +lambda+ form to use as a default
  ##  +overwrite+ form within an initialized *AssocHash*. The
  ##  form would be called such as when testing for a condition
  ##  of _object overwrite_ in *AssocHash#add*. This function, as
  ##  returned, will raise a **KeyOverwriteError**
  ##
  ## @note The object +whence+ may not have been fully initialized 
  ##  when this *overwrite_default* class method is evaluted
  ##
  ## @see AssocHash#add
  ## @see AssocHash::KeyOverwriteError
  ##
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
    return lambda { |whence, key, obj|
      raise new KeyOverwriteError(key, whence.get[key], obj, whence)
    }
  end


  ## Creates a new *AssocHash*
  ##
  ## @param key_proc [lambda] The +lambda+ form to call for
  ##  computing a key value for an object, such that the key
  ##  value will be used when adding the object to this
  ##  *AssocHash*. The form must accept one argument, an object,
  ##  and should return a key value that may be used when storing
  ##  the object in this *AssocHash*. The default form will
  ##  return the object itself.
  ##
  ## @param default [any] Hash _default_ to use for the delegate
  ##  *Hash*. 
  ##
  ##  If this parameter's value is a +lambda+ form or otherwise
  ##  of type *Proc* then that form will be used as a <em>default
  ##  proc</em> for the delegate *Hash.* The form should accept
  ##  two arguments: A *Hash* or *AssocHash* object and a _key_
  ##  value that was not located under that object. Whether the
  ##  first object is a *Hash* or *AssocHash* will be depdendent
  ##  on the nature of the calling form - such as for whether the
  ##  default form was reached by direct access onto the delegate
  ##  *Hash* object or by direct access to the *AssocHash*
  ##  instance.  The form should either perform a non-local exit
  ##  of control -- such as with `raise` or `throw` -- or return
  ##  a value to use as the default for the specified key.
  ##
  ##  If provided as a value of a type other than *Proc*, then
  ##  that value will be used as the Hash _default_ value.
  ##
  ##  The default value of the +default+ parameter in this
  ##  constructor is a +lambda+ form that will raise an exception
  ##  of type *AssocHash::KeyNotFoundError*
  ##
  ## @param overwrite [lambda] A +lambda+ form or general
  ##  *Proc* to use when evaluating an object for overwrite
  ##  under *#add*. The default form will raise an
  ##  *AssocHash::KeyOverwriteError*
  ##
  ## @see AssocHash#add
  ## @see AssocHash#get
  ## @see AssocHash#key
  ## @see AssocHash#member?
  ## @see KeyNotFoundError
  ## @see KeyOverwriteError
  ##
  def initialize(key_proc = ITSELF_LAMBDA,
                 default: self.class.table_default(self),
                 overwrite: self.class.overwrite_default(self))

    ## NB the 'default' lambda for the encapsualted hash object
    ## should never be reached under normal applications of this API
    if default.instance_of?(Proc)
      @table = Hash.new(&default)
    else
      @table = Hash.new(default)
    end

    @key_proc = key_proc
    @overwrite_proc = overwrite
  end


  ## Conditionally adds the provided object to this *AssocHash*,
  ## using a key value determined for the object.
  ##
  ## The key value will be determined by applying the +key_proc+
  ## form to the object, such that the +key_proc+ form was
  ## provided during the initialization of this *AssocHash*.
  ##
  ## === Conditional Stroage - Overview
  ##
  ## If an object _A_ is already stored in this *AssocHash* under
  ## the key determined from the +key_proc+ and that object _A_
  ## is not *equal?* to the object +obj+, then the +overwrite+
  ## form provided to this *AssocHash* will be evaluated, The
  ## +overwrite+ form will be called as a proc, providing this
  ## *AssocHash* as the call's first argument and the resulting
  ## _key_ value and _obj_ as its second and third arugments. If
  ## the +overwrite+ form returns a _falsey_ value or performs a
  ## non-local exit of control, then the object _A_ will not be
  ## overwritten with this +obj+.
  ##
  ## Otherwise, +obj+ will be stored for the determined key,
  ## in this *AssocHash*.
  ##
  ## @param obj [any] The object to conditionally store in this
  ##  *AssocHash*.  It will be assumed that this object responds
  ##  to any methods in the +key_proc+
  ##
  ## @return [any] +false+ if the +overwrite+ form was
  ##  evaluated and returned a _falsey_ value, otherwise +obj+
  def add(obj)
    ## FIXME move the next paragraphs into the top-level class docs
    ##
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
      if (obj.equal? table[usekey])
        return obj
      elsif ! @overwrite_proc.call(self,usekey,obj)
        return false
      end
    end
    @table[usekey]=obj
  end

  ## Returns the object registered for the provided +key+ value in
  ## this +AssocHash+
  ##
  ## This method and the +#[]+ delegate method may each result
  ## in a rasied exception, as per the behaviors of the +default+
  ## provided during initialization of this *AssocHash*.
  ##
  ## @see #member?
  def get(key)
    return @table[key]
  end

  ## Calls the *key_proc* for this *AssocHash* on the provided
  ## object, such as to determine the key that would be used for
  ## storage of the object.
  ##
  ## @param obj [any] the object to provided to the *key_proc*
  ##  for this *AssocHash*
  def key(obj)
    @key_proc.call(obj)
  end
  
  ## the +overwrite+ proc used in this *AssocHash*
  attr_reader :overwrite_proc

  ## the +key_proc+ used in this *AssocHash*
  attr_reader :key_proc

  ## the delegate *Hash* object encapsulated by this *AssocHash*
  attr_reader :table

end


# Local Variables:
# fill-column: 65
# End:
