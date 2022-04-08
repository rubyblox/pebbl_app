## threads.rb - thread utilities used in RIView

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

## Thread class accepting a thread name in the constructor
class GAppKit::NamedThread < Thread

  attr_reader :run_block

  def initialize(name = nil, &block)
    super(&block)
    self.name = name
    @run_block = block
  end

  def binding()
    ## NB notwithstanding the documentation under RI, but in
    ## review of Ruby's proc.c, the Binding.local_variable**
    ## methods may not in fact evaluate a string
    @run_block.binding
  end

  def local_variable_defined?(name)
    self.binding.local_variable_defined?(name.to_sym)
  end


  def local_variable_get(name)
    ## FIXME does not perform any checking on the local
    ## variable's read state
    self.binding.local_variable_get(name.to_sym)
  end



  def local_variable_set(name, value)
    ## FIXME does not perform any checking on the new value,
    ## and does not perform any locking on the local
    ## variable's writable state
    ##
    ## See also: FieldBindingStorage
    ## @ rbproject:rbproject/lib/rbproject/fieldclass.rb
    ## ... object pools @ the pond gem
    ## ... and TBD patching for Ruby's absent read/writable mutex impl
    ##     ... such that the patch may need to define an exclusive mutex lock
    ##         even for changing the read/writable state of a
    ##         primary rw-mutex-proxy (plus cv ??) object
    self.binding.local_variable_set(name.to_sym)
  end



  def inspect()
    return "#<#{self.class.name} 0x#{self.__id__.to_s(16)} [#{self.name}] #{self.status}>"
  end

end

# Local Variables:
# fill-column: 65
# End:
