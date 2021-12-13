## interactive tests for assochash.rb

require('./assochash')

module ATestConstants
  KEYTEST = lambda { |a| a.hash }

  NOVALUE = false.hash

  DEFAULT = lambda { |h,k| return NOVALUE }
end

##
## testing for general functionality
##

ah = AssocHash.new(keytest: ATestConstants::KEYTEST,
                   default: ATestConstants::DEFAULT)

ah.add("token") == ah.add("token")

ah.add("token") != ah.add("other")

ah.delete(true)
ah.get(true.hash) == ATestConstants::NOVALUE

ah.add(true)
ah.get(true.hash) != ATestConstants::NOVALUE
ah.get(true.hash) == true

ah.add(false)
ah.get(false.hash) != ATestConstants::NOVALUE
ah.get(false.hash) == false

ah.add(nil)
ah.get(nil.hash) != ATestConstants::NOVALUE
ah.get(nil.hash) == nil


##
## testing for the overwrite lambda
##

TestObj = Struct.new(:name, :token)

to1 = TestObj.new(:A,:TO1)
to2 = TestObj.new(:A,:TO2)

th = AssocHash.new(keytest: lambda { |a| a.name },
                   default: ATestConstants::DEFAULT,
                   overwrite: lambda { |k,obj| puts "Discarding #{k} => #{obj}"; return false }
                  )

th.add(to1)
th.add(to2)

th.get(:A) == to1
th.get(:A) != to2
