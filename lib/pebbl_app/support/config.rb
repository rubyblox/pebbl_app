## PebblApp::Support::Config class definition

require 'pebbl_app/support'

require 'ostruct'
require 'optparse'
require 'forwardable'

class PebblApp::Support::Config

  ## Constants for PebblApp::Support::Config
  module Const
    GTK_INIT_TIMEOUT_DEFAULT = 15
  end

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

  def option(name)
    return self.options.send(name.to_sym)
  end

  ## create, configure, and return a new option parser for this
  ## application
  def make_option_parser()
    OptionParser.new do |parser|
      self.configure_option_parser(parser)
    end
  end

  def configure_option_parser(parser)
    ## FIME add a default -h / --help parser => usage docs from the parser
  end

  ## parse an array of command line arguments, using the option
  ## parser for this application.
  ##
  ## the provided argv will be destructively modified by this method.
  def parse_opts(argv = ARGV)
    self.options[:gtk_init_timeout] ||= Const::GTK_INIT_TIMEOUT_DEFAULT
    parser = self.make_option_parser()
    parser.parse!(argv)
  end

  ## return the set of parsed args for this application, or a new,
  ## empty array if no value was previously bound
  def parsed_args()
    @parsed_args ||= []
  end

  ## set the array of parsed args for this application
  def parsed_args=(value)
    @parsed_args=value
  end

  def configure(argv: ARGV)
    self.parse_opts(argv)
    self.parsed_args = argv
  end

end
