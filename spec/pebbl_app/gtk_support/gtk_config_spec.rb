## rspec tests for PebblApp::GtkSupport::GtkApp

## the library to test:
require 'pebbl_app/gtk_support/gtk_config'

describe PebblApp::GtkSupport::GtkConfig do
  subject {
    described_class.new(described_class)
  }

  ## tests specs defined here may modify DISPLAY in the test
  ## environment. The initial value should be restored after
  ## each test.
  ##
  ## This text context requires that some DISPLAY is available.
  ## See also: Xvfb(1)
  let!(:display_initial) { ENV['DISPLAY'] }

  before(:each) do
    subject.parsed_args=[]
    subject.unset_display
    # subject[:debug] = true ## FIXME not used now
  end

  after(:each) do
    ENV['DISPLAY'] = display_initial
  end

  it "Uses a GtkConfig for config" do
    expect(subject).to be_a PebblApp::GtkSupport::GtkConfig
  end

  it "parses arg --display DPY" do
    subject.parse_opts(%w(--display :10))
    expect(subject.display).to be == ":10"
  end

  it "parses arg --display DPY to gtk_args" do
    subject.parse_opts(%w(--display :10))
    expect(subject.gtk_args).to be == %w(--display :10)
  end

  it "parses arg --display=DPY" do
    subject.parse_opts(%w(--display=:11))
    expect(subject.display).to be == ":11"
  end

  it "parses arg --display=DPY to gtk_args" do
    subject.parse_opts(%w(--display=:11))
    expect(subject.gtk_args).to be == %w(--display :11)
  end

  it "parses arg -dDPY" do
    subject.parse_opts(%w(-d:12))
    expect(subject.display).to be == ":12"
  end

  it "parses arg -dDPY to gtk_args" do
    subject.parse_opts(%w(-d:12))
    expect(subject.gtk_args).to be == %w(--display :12)
  end

  it "parses arg --gtk-init-timeout TIME to gtk_args" do
    subject.parse_opts(%w(--gtk-init-timeout 5))
    expect(subject.option(:gtk_init_timeout)).to be == 5
  end

  it "parses arg -tTIME to gtk_args" do
    subject.parse_opts(%w(-t10))
    expect(subject.option(:gtk_init_timeout)).to be == 10
  end


  it "resets parsed args" do
    subject.parsed_args=[]
    subject.configure(argv: [])
    expect(subject.parsed_args).to be == []
  end

  it "configures gtk_args from a provided argv" do
    initial = ARGV.dup
    begin
      ARGV.clear
      ARGV.push("--anti-option")
      subject.configure(argv: ["other.filename"])
      expect(subject.gtk_args).to be == ["other.filename"]
    ensure
      ARGV.clear
      initial.each do |arg|
        ARGV.push arg
      end
    end
  end

  it "indicates when no display is configured" do
    ENV.delete('DISPLAY')
    null_argv = []
    subject.configure(argv: null_argv)
    expect(subject.display?).to_not be_truthy
  end

  it "overrides env DISPLAY with any display arg" do
    if (initial_dpy = ENV['DISPLAY'])
      ENV['DISPLAY']= initial_dpy + ".nonexistent"
      subject.parse_opts(['--display', initial_dpy])
      expect(subject.display).to be == initial_dpy
    else
      RSpec::Expectations.fail_with("No DISPLAY configured in test environment")
    end
  end

end
