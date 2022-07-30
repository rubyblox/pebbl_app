## PebblApp::Util module

require 'pebbl_app'

module PebblApp

  ## Generic utility module
  module Util
    class << self

      ## Freeze a provided array and all elements of the array
      ##
      ## @param ary [Array] the array to freeze
      ##
      ## @return [Array] the frozen array
      def freeze_array(ary)
        ary.tap { |elt| elt.freeze }.freeze
      end
    end ## class << Util
  end

end
