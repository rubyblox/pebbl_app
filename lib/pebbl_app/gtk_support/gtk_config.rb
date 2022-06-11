## GtkConfig for Pebbl App

require 'pebbl_app/support/config'

require 'optparse'

class PebblApp::GtkSupport::GtkConfig < PebblApp::Support::Config

  def display=(dpy)
    ## set the display, independent of parse_opts
    self.options[:display] = dpy
  end

  def display()
    if self.option?(:display)
      self.options[:display]
    elsif (dpy = ENV['DISPLAY'])
      dpy
    else
      false
    end
  end

  def unset_display()
    self.deconfigure(:display)
  end

  def display?()
    self.option?(:display) ||
      ENV.has_key?('DISPLAY')
  end

  def configure_option_parser(parser)
    parser.on("-d", "--display DISPLAY",
              "X Window System Display, overriding DISPLAY") do |dpy|
      self.display = dpy
    end
  end


  def gtk_args()
    args = self.parsed_args.dup
    if ! self.display?
      raise PebblApp::GtkSupport::ConfigurationError.new("No display configured")
    elsif self.option?(:display)
      args.push(%(--display))
      args.push(self.option(:display))
    end
    return args
  end

end

