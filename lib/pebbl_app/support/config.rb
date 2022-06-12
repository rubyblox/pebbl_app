## PebblApp::Support::Config class definition

require 'pebbl_app/support'

require 'ostruct'
require 'optparse'
require 'forwardable'

class PebblApp::Support::Config

  include Enumerable
  extend Forwardable
  ## FIXME test each delegaged method
  def_delegators(:@options, :[], :[]=, :delete_field, :delete_field!,
                 :each_pair, :to_enum, :enum_for)

  attr_reader :for_app

  def initialize(for_app, options = nil)
    @for_app = for_app
    @options = options ? OpenStruct.new(options) : OpenStruct.new
  end

  def options
    @options ||= OpenStruct.new
  end

  def option?(name)
    sname = name.to_sym
    self.options.each_pair do |opt, v|
      if opt.eql?(sname)
        return true
      end
    end
    return false
  end

  def deconfigure(name)
    if self.option?(name)
      self.options.delete_field(name)
    end
  end

  def option(name, default = false, &fallback)
    opt = name.to_sym
    if self.option?(opt)
      return self.options.send(opt)
    elsif block_given?
      fallback.yield(opt)
    else
      return default
    end
  end

  ## create, configure, and return a new option parser for this
  ## application
  def make_option_parser()
    OptionParser.new do |parser|
      self.configure_option_parser(parser)
    end
  end

  ## configure an argv options parser for this instance
  ##
  ## @param parser [OptionParser] the parser to configure
  def configure_option_parser(parser)
    cmd = self.for_app.app_cmd_name
    parser.program_name = cmd
    parser.banner = "Usage: #{cmd} [options]".freeze
    parser.separator "".freeze
    parser.separator "Options:".freeze
    parser.on_head("-h", "--help", "Show this help") do
      puts parser
      exit unless self.option[:persist]
    end
  end

  ## configure any default options for this instance and parse
  ## the array of command line arguments as using the option parser for
  ## this instance.
  ##
  ## the provided argv will be destructively modified by this method.
  def parse_opts(argv = ARGV)
    parser = self.make_option_parser()
    parser.parse!(argv)
  end

  ## return the set of parsed args for this instance, or a new
  ## empty array if no value was previously bound
  def parsed_args()
    @parsed_args ||= []
  end

  ## set the array of parsed args for this instance
  def parsed_args=(value)
    @parsed_args=value
  end

  ## configure this instance, parsing any options provided in argv
  ## then setting this instance's parsed_args field to the resulting
  ## value of argv
  ##
  ## @param argv [Array<String>] options for this instance, using a
  ##        shell command string syntax for the set of options
  def configure(argv: ARGV)
    self.parse_opts(argv)
    self.parsed_args = argv
  end

end
