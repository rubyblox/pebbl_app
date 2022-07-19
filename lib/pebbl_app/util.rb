## PebblApp::Util module

module PebblApp

  module Util
    class << self
      def freeze_array(ary)
        ary.tap { |elt| elt.freeze }.freeze
      end
    end ## class << Util
  end

end
