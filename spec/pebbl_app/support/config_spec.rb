## rspec tests for PebblApp::Support::Config

## the library to test
require 'pebbl_app/support/config'

describe PebblApp::Support::Config do
  let(:app) {
    PebblApp::Support::App.new
  }
  subject {
    described_class.new(app)
  }

  it "sets the app cmd name as the option parser's program name" do
    parser = subject.make_option_parser
    expect(app.app_cmd_name).to be == parser.program_name
  end

  it "adds help text to the option parser" do
    parser = subject.make_option_parser
    usage_lines = []
    parser.top.summarize do |l|
      ## if the array of text lines should be stored in normal display
      ## order, then #unshift should be used here.
      ##
      ## using #push instead, it serves to ensure that the "-h" this will
      ## search for is at the start of the usage_lines array
      usage_lines.push l
    end
    expect(usage_lines).to include("-h")
  end


  it "configures parsed args from a provided argv" do
    initial = ARGV
    begin
      ARGV=["--anti-option"]
      subject.configure(argv: ["other.filename"])
      expect(subject.parsed_args).to be == ["other.filename"]
    ensure
      ARGV = initial
    end
  end
end
