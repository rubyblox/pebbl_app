
## the library to test
require 'pebbl_app/shell'

describe PebblApp::Shell do


  context "implementation of which" do
    let(:file_test) {
      ## providing a block for the ShProc.which tests, this avoids
      ## the peculiarities of File.executable? on Microsoft Windows
      ## platforms, also avoiding any peculiaries of file permissions
      ## for the ./whoami file under git, on other platforms
      (proc { |f| true }).freeze
    }


    it "finds a file in env PATH" do
      initial = ENV['PATH']
      begin
        ENV['PATH'] = __dir__
      ensure
        ENV['PATH'] = initial
      end
      expect(
        described_class.which('whoami', &file_test)
      ).to_not be false
    end

    it "finds a file under an enumerable path" do
      expect(
        described_class.which('whoami', [__dir__],  &file_test)
      ).to_not be false
    end

  end
end
