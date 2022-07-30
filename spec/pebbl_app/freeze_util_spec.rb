## rspec tests for PebblApp::FreezeUtil

require 'pebbl_app/freeze_util' ## the library to test

describe PebblApp::FreezeUtil do

  context "freeze_array" do
    it "freezes an array and array elements to output (array of strings)" do
      ary = %w(a b c)
      out_ary = described_class.freeze_array(ary)
      expect(ary.eql?(out_ary)).to be true ## oddly ...
      expect(ary.frozen?).to be false
      expect(out_ary.frozen?).to be true
      expect(ary[0].frozen?).to be true
      expect(out_ary[0].frozen?).to be true
      expect(out_ary.find { |elt| ! elt.frozen? }).to be nil
    end
  end
end
