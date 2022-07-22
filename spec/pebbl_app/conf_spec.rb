## rspec tests for PebblApp::Conf

## the library to test
require 'pebbl_app/conf'

## API used in tests
require 'optparse'
require 'securerandom'

describe PebblApp::Conf do
  let!(:name) { described_class.to_s }
  subject {
    described_class.new(name)
  }

  it "sets an option" do
    expect(subject.option?(:option)).to be false
    subject[:option] = true
    expect(subject.option?(:option)).to be true
  end

  it "deconfigures an option" do
    subject[:option] = true
    expect(subject.option?(:option)).to be true
    subject.deconfigure(:option)
    expect(subject.option?(:option)).to be false
  end

  it "stores an option value" do
    subject[:option] = "value"
    expect(subject.option?(:option)).to be true
    expect(subject[:option]).to be == "value"
    subject.deconfigure(:option)
  end

  it "uses a block for option value fallback" do
    expect(subject.option(:nonexistent, false) do |name|
             :fallback
           end).to be == :fallback
  end

  it "returns a default option value" do
    expect(subject.option(:nonexistent, :not_found)).to be == :not_found
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

  it "accepts a command_name" do
    name = Random.uuid
    inst = described_class.new(name)
    expect(inst.command_name).to be == name
  end


  it "sets the command_name as the option parser's program name" do
    parser = subject.make_option_parser
    expect(parser.program_name).to be == subject.command_name
  end


  it "accepts and applies an option parser configuration in an extending class" do
    class ConfTest < described_class
      attr_reader :test_str
      def configure_option_parser(parser)
        parser.on("-t", "--test STR", "Option test") do |str|
          @test_str = str
        end
      end
    end
    opts = %w(-t defined)
    opts_initial = opts.dup
    inst = ConfTest.new
    expect { inst.parse_opts!(opts) }.to_not raise_error
    expect(opts).to_not be == opts_initial
    expect(opts).to be_empty
    expect(inst.test_str).to be == "defined"
  end

  it "destructively modifies argv in parse_opts!" do
  end


  it "configures parsed args from a provided argv" do
    initial = ARGV.dup
    begin
      ARGV.clear
      ARGV.push("--anti-option")
      subject.configure(argv: ["other.filename"])
      expect(subject.parsed_args).to be == ["other.filename"]
    ensure
      ARGV.clear
      initial.each do |arg|
        ARGV.push arg
      end
    end
  end
end
