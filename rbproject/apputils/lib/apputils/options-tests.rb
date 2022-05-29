## options-test.rb - ad hoc tests for options.rb

require('apputils/options') ## the library to test


om = OptionMap::OptionMap.new({:a => 1, :b => true })

om.getopt(:a) == 1

om.getopt(:b) == true

om.getopt(:c) == false


on = OptionMap::OptionMap.new([:c, :d])

on.getopt(:c) == true

on.getopt(:d) == true

on.getopt(:a) == false
