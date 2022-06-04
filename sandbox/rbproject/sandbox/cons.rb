## cons.rb - a list-like construct for Ruby

## alternately: A rudimentary, generally adaptable data type

module NilCons
    @@nlambda ||= lambda { || return nil }
    @@flambda ||= lambda { || return false }
    @@tlambda ||= lambda { || return true }
    ## NB can read but not set a car, cdr on nil
    NilClass.define_method(:car, &@@nlambda)
    NilClass.define_method(:cdr, &@@nlambda)
    NilClass.define_method(:list?, &@@tlambda)
    NilClass.define_method(:cons?, &@@flambda)

    # @@orig_equal ||= NilClass.instance_method(:==)
    @@eqlambda ||= lambda { |whence| 
	if (whence.is_a?(Cons))
	## NB there is a hack here
	  whence.cdr.nil? && whence.car.nil?
	elsif whence.nil?
	  return true
	else
	  return false 
	end 
    }
    NilClass.define_method(:==,@@eqlambda)

   ## FIXME also define Kernel.list? and Kernel.cons?  => false
end

class Cons
  attr_accessor :car, :cdr
  extend NilCons

  def self.penultimate(whence)
    wcdr = whence.cdr
    if wcdr.nil?
     return nil
    elsif wcdr.cdr.nil?
     return whence
    else
     self.penultimate(wcdr)
    end
  end

  def initialize(car, cdr=nil)
    @car = car
    @cdr = cdr
  end

  def ==(whence)
   if whence.nil?
     ## NB approximate equivlance - this interface defines that a Cons with a null CAR and null CDR is in effect equivalent (under ==) to nil
     ##
     ## This implementation shadows the == instance method in NilClass. As such:
     ##  + nil == Cons.new(nil) => true + (would return false without the shadowing)
     ##  + Cons.new(nil) == nil => true + (as defined in this method)
     ## Regardless, nil will retain identity as a distinct object:
     ##  + nil.eql?(Cons.new(nil)) => false
     ##  + Cons.new(nil).eql?(nil) => false
     ##
     ## See also: #cons?, #list? instance methods on each of the Cons and NilClass classes
     return (self.car.nil? && self.cdr.nil?)
   elsif whence.eql?(self)
     return true
   elsif whence.cons?
     return ( self.car == whence.car ) && ( self.cdr == whence.cdr )
   else
     return false
   end
  end


  def list?
   return true
  end

  def cons?
   return true
  end

  ## NB unlike Array#push, Array#pop, this operates on the head of the sequence
  ##
  ## this #push does not accept multiple arguments
  def push(elt)
   pcdr = @cdr
   pcar = @car
   @car = elt
   if ( pcar.nil? && pcdr.nil? )
    return self
   else
    @cdr = Cons.new(pcar, pcdr)
   end
  end

  ## NB unlike Array#push, Array#pop, this operates on the head of the sequence
  ##
  ## this #pop does not accept a count
  def pop()
    pcar=@car
    pcdr=@cdr
    if pcdr
      @car=pcdr.car
      @cdr=pcdr.cdr
    else
      ## NB in effect this would make self == nil (not per se possible with Common Lisp, which implements pop as a Common Lisp macro)
      @car=nil
      @cdr=nil
    end
    return pcar
  end

  ## Beginning at +self+, return the last element in this cons sequence that has a null +cdr+
  ##
  ## This method may return +self+
  ##
  ## *Remarks* unlike +Array#last+ this returns an instance of the same type as the sequence it's called on
  def last()
    p = self.class.penultimate(self)
    return p ? p.cdr : self
  end

  ## :nodoc: TBD implementing a converse of Cons#pop, Cons#push

  def shift() 
   p = self.class.penultimate(self)
   if (p.nil?)
     pcar = self.car
     self.car = nil
     self.cdr = nil
   else
     pcar = p.car
     if ( p.eql?(self) )
      p.car = nil
     elsif (pcdr = p.cdr).is_a?(Cons)
       p.car = pcdr.car
     else
       raise "Last element is not a Cons: #{pcdr}"
     end
     p.cdr = nil
   end
   return pcar
  end

  def unshift(elt)
   lst = last()
   last.cdr = Cons.new(elt)
  end

  def inspect()
    ## NB this method does not detect circular references, and does not provideE #n= referencing,
    ## such that may be implemented with a reference parser external to this class
    return "#<#{self.class} 0x#{self.__id__.to_s(16)} (#{self.car.inspect} #{self.cdr.inspect})>"
  end
end


# Local Variables:
# fill-column: 65
# End:
