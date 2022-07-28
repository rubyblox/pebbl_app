## GtkConf for Pebbl App

require 'pebbl_app'

require 'optparse'

module PebblApp

  class GtkConf < Conf

    def initialize(command_name = false)
      super(command_name)
      map_default(:gtk_init_timeout) do
        Const::GTK_INIT_TIMEOUT_DEFAULT
      end
    end

    ## set a display option for this instance
    ##
    ## This method will not modify the process environment.
    ##
    ## If a display option is provided for the application, the
    ## application should ensure that any authentication methods required
    ## for connecting to the display will be configured and available to
    ## the application, at runtime.
    def display=(dpy)
      ## set the display, independent of parse_opts!
      self.options[:display] = dpy
    end

    ## if a display option has been set for this instance, return the
    ## value as initialized for that configuration option. Else, if a
    ## 'DISPLAY' value is configured in the process environment, return
    ## that value. Else, return false
    def display()
      self.option(:display) do
        ## fallback block
        if ENV.has_key?(Const::DISPLAY_ENV)
          ENV[Const::DISPLAY_ENV]
        else
          false
        end
      end
    end

    ## if a display option has been set for this instance, remove
    ## that configuration option.
    ##
    ## This method will not modify the process environment.
    def unset_display()
      self.deconfigure(:display)
    end

    ## return true if a display has been configured for this instance,
    ## or if there is a 'DISPLAY' value configured in the process
    ## environment
    def display?()
      self.option?(:display) ||
        ENV.has_key?(Const::DISPLAY_ENV)
    end

    def gtk_init_timeout
      self.option(:gtk_init_timeout, Const::GTK_INIT_TIMEOUT_DEFAULT)
    end

    def gtk_init_timeout=(timeout)
      self.set_option(:gtk_init_timeout, timeout)
    end


    ## configure an argv options parser for this instance
    ##
    ## @param parser [OptionParser] the parser to configure
    def configure_option_parser(parser)
      parser.on("-d", "--display DISPLAY",
                "X Window System Display, overriding DISPLAY") do |dpy|
        self.display = dpy
      end
      parser.on("-t", "--gtk-init-timeout TIMEOUT",
                "Timeout in seconds for Gtk.init") do |timeout|
        self.options[:gtk_init_timeout] = timeout.to_r
      end
    end

    ## return an array of arguments for Gtk.init, as initialized under
    ## the #configure method for this instance
    ##
    ## @return [Array] the arguments for Gtk.init
    def gtk_args(args = ARGV)
      args = self.parsed_args.dup
      if ! self.display?
        raise PebblApp::ConfigurationError.new("No display configured")
      elsif self.option?(:display)
        args.push(%(--display))
        args.push(self.option(:display))
      end
      return args
    end

  end ## GtkConf class

end
