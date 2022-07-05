## ApiDb tests (sandbox)

require_relative 'api-yardwalk'

orig_dbg = $DEBUG

## traversal for one gem, by default: gio2

gem = (ENV['TRAVERSE_GEM'] || 'gio2')

begin
  $DEBUG = true
  traversal = ApiDb::YardGemWalk.new(gem, feature_files: "lib/#{gem}.rb")

  traversal.bind_preload do |code_obj|
    ## traversal preload
    ##
    ## this will be be called before processing any yard defs for
    ## each module
    ##
    ## tested with
    ##  gio2, glib2
    ##  gtk3
    ##  gdk3
    ##  vte3
    ##  libsecret
    ##  webkit2-gtk
    ##  gtksourceview3
    ##
    catch(:preload) do |tag|
      ## object deserialization in preload
      case code_obj
      when YARD::CodeObjects::ModuleObject
        begin
          p = code_obj.path
          rb_obj = Object.const_get(p)
        rescue NameError => err
          Kernel.warn(err, uplevel: 0)
          throw tag
        end
      else
        throw tag
      end

      ## dynamic code activation in preload
      case rb_obj
      when Class
        ## A Class is a Module.
        ##
        ## This preload workflow is mainly for a Module not a class.
        ##
        ## Generally not reached, given the throw when the YARD
        ## code object is not a ModuleObject
      when Module
        ## Preload for Gtk, Gdk, other library support
        ##
        ## This will require X11 display support in the loader environment
        ##
        ## see also: Xvfb
        if rb_obj.name == "Gtk"
          if  rb_obj.respond_to?(:init)
            STDERR.puts "[PRELOAD] Init Gtk for #{gem}" if $DEBUG
            rb_obj.init()
          else
            ## Gtk is initialized by side effect from
            ## some dependent modules. This may be reached
            ## anyway, in traversing YARD data
            STDERR.puts "Gtk already initialized (#{Gtk::Version::STRING})" if $DEBUG
          end
        elsif rb_obj.name == "Gdk"
          if rb_obj.respond_to?(:init)
          STDERR.puts "[PRELOAD] Init #{rb_obj} for #{gem}" if $DEBUG
            rb_obj.init
          end
        elsif rb_obj.respond_to?(:init)
          STDERR.puts "[PRELOAD] Init #{rb_obj} for #{gem}" if $DEBUG
          rb_obj.init()
        elsif rb_obj.const_defined?(:Loader)
          STDERR.puts "[PRELOAD] Loading #{rb_obj} for #{gem}" if $DEBUG
          ldr = rb_obj::Loader.new(rb_obj)
          if rb_obj.name == "GdkX11"
            ldr.load
          else
            ldr.load(rb_obj.name)
          end
        end
      end
    end
  end

  traversal.traverse_spec do |rb_obj, code_obj|
    ## debugging data for output
    extra = nil
    case code_obj
    when YARD::CodeObjects::MethodObject
      ## debug
      extra = " (#{code_obj.scope} scope)"
    end
    STDERR.puts "Traversed %s%s => %p" % [
      code_obj.path, extra, rb_obj
    ]

    ## coverage analysis - FIXME record any code_obj for a rb_obj == false
    ## then review and debug the YardWalk automatiom

    ## tbd for GUI applications
    ## - processing for yard => groonga transform
    ##   - a schema for storing yard CodeObject data in groonga
    ##   - an API for using this in command-line tooling (search,
    ##     display docs, visit source files) and in GUI
    ## - mapping a groonga db onto Gtk list/tree builders
    ## - using groonga with search widgets in Gtk
    ## - using groonga for an IRB-like autocomplete feature
    ##   for some application onto Vte
    ##   or onto some terminal-like app with GTK textview/sourceview

    ## adding defs to YARD - TBD
    ## - should start from a yardoc rebuild for each gem,
    ##   to ensure that the yardoc data loaded here will
    ##   not have been already processed from here
  end
ensure
  $DEBUG = orig_dbg
end
