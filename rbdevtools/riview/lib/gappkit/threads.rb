## threads.rb - thread utilities used in RIView

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

## Thread class accepting a thread name in the constructor
class GAppKit::NamedThread < Thread
  def initialize(name = nil)
    self.name = name
    super()
  end

  def inspect()
    return "#<#{self.class.name} 0x#{self.__id__.to_s(16)} [#{self.name}] #{self.status}>"
  end

  def to_s()
    inspect()
  end
end

# Local Variables:
# fill-column: 65
# End:
