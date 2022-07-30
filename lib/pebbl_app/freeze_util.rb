## PebblApp::FreezeUtil module

require 'pebbl_app'

module PebblApp

  ## Generic utility module for frozen data in Ruby applications
  ##
  ## This module will define the following methods, in scope with any
  ## application of 'include' or 'extend'
  ##
  ## - `freeze_array` also available asPebblApp::FreezeUtil.freeze_array
  ##
  module FreezeUtil

    ## Freeze a provided array and all elements of the array,
    ## returning the frozen array
    ##
    ## **Implementation Notes:**
    ##
    ## - Although the output value may generally be **eql?** to the
    ##   input value, the output value should be applied as the frozen
    ##   array.
    ##
    ## - This method should produce an effect of freezing all elements
    ##   in the input array, and similarly in the output array. The
    ##   output array may represent the actual frozen array, after this
    ##   method.
    ##
    ## @param ary [Array] the array to freeze
    ##
    ## @return [Array] the frozen array
    def freeze_array(ary)
      ary.map { |elt| elt.freeze }.freeze
    end

    self.extend self
  end

end
