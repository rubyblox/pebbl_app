# riview.rb

require 'gtk3'

require('logger')
require('forwardable')
## mixin module for adding *log_*+ delegate methods to a class
module LoggerDelegate

  def self.extended(extclass)
    ## FIXME cannot pass parameters across Object#extend
    ##
    ## e.g the name of the instance variable to delegate to
    ##
    ## => available via a paramter to def_logger_delegate
    ## in the extending class
    extclass.extend Forwardable

    ## FIXME needs documentation (params)
    ##
    ## TBD YARD rendering for define_method in this context
    ##
    ## NB application must ensure that the instance variable is
    ## initialized with a Logger before any delegate method is
    ## called - see example under Application#initialize
    define_method(:def_logger_delegate) do | instvar, prefix=:log_ |
      use_prefix = prefix.to_s
      Logger.instance_methods(false).
        select { |elt| elt != :<< }.each do |m|
          extclass.
            def_instance_delegator(instvar,m,(use_prefix + m.to_s).to_sym)
        end
    end
  end
end


## Thread class accepting a thread name in the constructor
class NamedThread < Thread
  def initialize(name = nil)
    self.name = name
    super()
  end

  def inspect()
    return "#<#{self.class.name} 0x#{self.__id__.to_s(16)} [#{self.name}] #{self.status}>"
  end

  def to_s()
    inspect()
  end
end


class BuilderUI
  ## FIXME move some of the following into a module decl

  ## NB Glade
  ## - FIXME two main ways to use Glade UI definitions
  ##
  ##   - via Gtk::Builder
  ##
  ##   - via templates, assuming some specific syntax in the UI
  ##     definition file and correspondingly, in the Ruby sources
  ##     using the same
  ##
  ##     - thence, via UI decls distributed under a GResource bundle
  ##
  ##     - or via UI decls distributed as individual files
  ##
  ##     * NB for an application window defined via a template, this
  ##       entails defining the app menu bar in a separate UI file -
  ##       - see GtkApplication docs under devehelp, for a description
  ##         of the assumptions implemented in the same
  ##
  ## - FIXME this needs GtkApplication/Gtk::Application integration
  attr_reader :builder
  attr_reader :mapped_objects

  def initialize(file)
    @mapped_objects ||= [] ## FIXME not needed under a Gtk::Application impl
    @builder = Gtk::Builder.new()
    add_ui_file(file)
  end

  def add_ui_file(file)
    ## FIXME under some Glade XML, something errs here, and it puts
    ## the ruby process into a failed process state, e.g
    ##
    ## => "Object with ID  not found" i.e error parsing the Builder UI desc
    ##    NB the message provides a line, column number pair for the
    ##    error in the Builder UI (XML) file
    ##
    ## => an error with GtkMenuItem - which is not a "deprecated"
    ##    Gtk widget but appears to be a bit problematic
    ##

    ## FIXME the following may err and abort the calling process
    ## - can that be trapped before abort ?? overriding any existing
    ##   SIGABRT handling (FIXME needs a regular test case)
    begin
      # Signal.trap("SIGABRT","IGNORE")
      @builder.add_from_file(file)
    ensure
      # Signal.trap("SIGABRT","SYSTEM_DEFAULT")
    end
  end

  ## FIXME refactor some of the following onto Gtk::Application

  def map_object(object)
    unless @mapped_objects.find { |obj| obj.eql?(object) }
      @mapped_objects.push(object)
    end
    object.show
  end

  def destroy_object(object)
    if ( @mapped_objects.delete(object) )
      object.destroy
    end
  end

  def unmap_object(obj)
    obj.unmap
  end

  def unmap_objects()
    @mapped_objects.each { |obj|
      unmap_object(obj)
    }
  end

  def destroy_objects()
    @mapped_objects.each { |obj|
      destroy_object obj
    }
  end

end

class BuilderApp < BuilderUI
  ## FIXME integrate with Gtk::Application
  ## -> NB Gtk::Application::id_is_valid?(...)
  ##    via Gio::Application::id_is_valid?(...)
  ## -> NB dbus & Gtk::Application
  ## -> NB resource paths & Gtk::Application
  ## -> TBD desktop session managers (&& DBus) & Gtk::Application
  ## -> TBD menubars & Gtk::Application
  ##    -> See devehlp for GtkApplication, GApplication
  ## !> NB Gio::Application "startup" signal (devhelp)
  ## !> NB Gtk::Application app#add_window, app#windows, app#remove_window
  ##    && possible side effects of app#remove_window presumably when
  ##    app#windows then presents an empty set
  ## ! TBD Gio::Application app#run (?? GTK cmdline args ??)
  ## ! TBD Gio::Application app#activate
  ## ! TBD Gio::Application app#quit
  ## ! TBD Gio::Application app#open
  attr_reader :name

  extend LoggerDelegate
  def_logger_delegate(:@logger)

  LOG_LEVEL_DEFAULT = Logger::DEBUG

  def initialize(file, name: self.class.name,
                logger: nil)
    @name = name
    ## NB ensuring the logger is initialized before calling the
    ## superclass constructor
    if logger
      use_logger = logger
    else
      use_logger = Logger.new(STDERR)
      use_logger.level = LOG_LEVEL_DEFAULT
      use_logger.progname = name
    end
    @logger = use_logger
    super(file)
  end

  def add_ui_file(file)
    ## NB Verbose logging under debug - the superclass method
    ## may produce errrors under Gtk, such that may abort the
    ## Ruby process
    log_debug("Adding UI file to builder: #{file}")
    super
    log_debug("Added UI file to builder: #{file}")
  end

  def run()
    log_debug("Starting GTK Main loop - in thread #{Thread.current}")
    Gtk.main()
    log_debug("Run returning - in thread #{Thread.current}")
  end

  def quit()
    log_debug("GTK Quit - in thread #{Thread.current}")
    Gtk.main_quit()
  end

  def run_threaded()
    ## TBD set the thread's name
    ##
    ## NB does not need to call g_thread_init
    ## assuming GLib >= 2.32 on the host
    ## cf. https://docs.gtk.org/glib/threads.html
    log_debug("Run : from thread #{Thread.current}")
    ## FIXME Is there no way to create a thread without
    ## running it immediately, in Ruby?
    ## The constructor does not allow for setting a thread name, here

    # GLib::Thread.init if GLib::Thread.supported?
    ## ^ NB should not be necessary w/ recent GLib releases.
    ## It does not change the present uselessness of this method, either

    NamedThread.new(@name) { run() }
  end

  def ui_object(id)
    builder.get_object(id)
  end

  def map_object(object)
    log_debug("Mapping object #{object}")
    super
  end

  def unmap_object(object)
    ## FIXME this log message appears normally now
    log_debug("Unmapping object #{object}")
    super
  end

  def destroy_object(object)
    ## FIXME this log message does not ever appear
    log_debug("Destroying object #{object}")
    super
  end
end

module TemplateBuilder
  def self.extended(extclass)
    def extclass.use_resource_bundle(path)
      ## FIXME store the GResource for later _unregister, unref, etc
      resource = GIO::Resource.load(path)
      resource._register
    end
    def extclass.use_template(path)
      ## FIXME err if the variable is already defined/non-null
        @template = path
    end
    def extclass.template
      @template
    end
    def extclass.registered?()
      @registered == true
    end
    def extclass.register()
      if ! registered?
        self.type_register
        @registered=true
      end
    end
    def extclass.init
      ## FIXME fails under AppWindow.init
      ##
      ## set_template needs a GResource path, and does not accept
      ## a filename
      ##
      ## FIXME this needs a lot more project tooling
      gem_dir=File.expand_path("..", File.dirname(__FILE__))
      use_path = File.expand_path(@template,gem_dir)
      if File.exists?(use_path)
        ## FIXME provide an alternate method using Gio::Resource
        ## see GResource::g_resource_load in the GNOME GIO reference manual
        ## vis a vis local use_resource_bundle(...) which should be
        ## called first
        ##
        ## see also glib-compile-resources(1) && Rake
        ##  ... --generate riview.gresource.xml ...
        ##
        ## NB here, @template must represent a GResource path, not a filename
        #set_template(resource: @template)

        ## here, only the glade UI file is used...
        ##
        ## cf. ~/.local/share/gem/ruby/3.0.0/gems/gio2-3.4.9/lib/gio2/file.rb
        ## && GFile, GFileInputStream pages under GNOME devhelp
        gfile = Gio::File.open(path: use_path)
        fio = gfile.read
        nbytes = File.size(use_path)
        begin
          bytes = fio.read_bytes(nbytes)
          self.set_template(data: bytes)
        ensure
          ## TBD no #unref available for GLib::Bytes here
          ##
          ## TBD The template bytes data may be reused internally in Gtk ?
          fio.unref()
          ffile.unref()
        end
      else
        raise "Template file does not exist: #{use_path}"
      end
    end
    extclass.register
  end
end

class AppWindow < Gtk::ApplicationWindow
  ## ^ NB class name must match that provided in the ui template definition
  extend TemplateBuilder

  ## FIXME integrate with an extension onto Gtk::Application

  self.use_template("ui/appwindow.glade")
  ## FIXME needs more integration with the type decls in the template file
  ##
  ## FIXME needs interop with RIView initialization
  ## ... indep. of window class impl - use one (template or no template)

  # self.use_resource_bundle(...)
  #self.use_template("/space/thinkum/RIView/ui/riview.glade")


  def initialize()
    super()
    # self.present
    # Gtk.main
  end
end


class RIView < BuilderApp

  def initialize(name: self.class.name)
    ## FIXME support initializing gem_dir from a gem spec's full_gem_path
    gem_dir=File.expand_path("..",File.dirname(__FILE__))
    glade_file=File.expand_path("ui/riview.glade",gem_dir)
    super(glade_file, name: name)

    ## FIXME do the following for each window mapping request

    window = ui_object("RIView")

    close_proc = lambda { |obj|
      # window = obj.window ## FIXME may not be the ApplicationWindow
      ## NB using 'window' from the binding environment here

      unmap_object(window) ## NB This would DNW with what widget.window returns
      destroy_object(window)
      self.quit if @mapped_objects.length.zero?
    }
    window.signal_connect("destroy", &close_proc)
    window.name=name
    window.set_title(name)


    mclose = ui_object("MenuClose")
    mclose.signal_connect("activate", &close_proc)
  end

  def run()
    ## FIXME add the window to a list of locally window-mapped UI objects,
    ## for use in #quit
    window = ui_object("RIView")
    map_object(window)
    #  window.raise ## private method ????
    super()
  end

  def quit()
    ## destroy any initialized UI objects - top-level app windows, mainly
    unmap_objects()
    destroy_objects()
    super()
  end

end
