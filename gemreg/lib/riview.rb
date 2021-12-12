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

## general-purpose mixin module for TemplateBuilder submodules
##
## @see ResourceTemplateBuilder
## @see FileTemplateBuilder
module TemplateBuilder
  def self.extended(extclass)

    ## set the template path to be used for this class
    ##
    ## @see ResourceTemplateBuilder::init
    ## @see FileTemplateBuilder::init
    def extclass.use_template(path)
      ## FIXME err if the variable is already defined/non-null
        @template = path
    end

    ## retrieve the template path to be used for this class
    ##
    ## @see ResourceTemplateBuilder::init
    ## @see FileTemplateBuilder::init
    def extclass.template
      @template
    end

    ## return a boolean value indicating whether this class hass been
    ## registered
    ##
    ## @see ::register
    def extclass.registered?()
      @registered == true
    end

    ## ensure that the +type_register+ class method is called exactly
    ## once, for this class
    ##
    ## @see Gtk::Container::type_register
    ## @see Gtk::Widget::type_register
    ## @see GLib::Object::type_register
    def extclass.register()
      if ! registered?
        self.type_register
        @registered=true
      end
    end
  end
end

module ResourceTemplateBuilder
  def self.extended(extclass)
    extclass.extend TemplateBuilder

    ## ensure that a resource bundle at the provided +path+ is
    ## registered at most once, for this class
    ##
    ## @see ::init
    ## @see ::resource_bundle_path
    ## @see ::resource_bundle
    def extclass.use_resource_bundle(path)
      ## NB storing the bundle in extclass, such that  _unregister and
      ## unref (??) can be called for the Resource bundle, during some
      ## pre-exit/pre-gc cleanup method
      if @bundle
        warn "Bundle for #{@bundle_path} already registered for #{self}. Ignoring #{path}"
      else
        ## FIXME this pathname expansion needs cleanup
        gem_dir=File.expand_path("..", File.dirname(__FILE__))
        use_path = File.expand_path(path,gem_dir)

        @bundle_path = use_path
        @bundle = Gio::Resource.load(use_path)
        @bundle._register ## NB not the same as GApplication app#register
      end
    end

    ## returns the string filename used for initializing the
    ## singleton Gio::Resource bundle for this class, or nil if no
    ## resource bundle has been registered
    ##
    ## @see ::use_resource_bundle
    ## @see ::bundle
    def extclass.resource_bundle_path
      @bundle_path
    end

    ## returns any singleton Gio::Resource bundle registered for this
    ## class, or nil if no bundle has been registered
    ##
    ## @see ::use_resource_bundle
    ## @see ::bundle_path
    def extclass.resource_bundle
      @bundle
    end

    ## set this class' template as a resource path
    ##
    ## The resource path for the configured template must provide a
    ## valid resource path onto the resource bundle initialized to this
    ## class
    ##
    ## This method is used by GTK
    ##
    ## @see ::use_resource_bundle
    ## @see ::use_template
    def extclass.init
      ## FIXME this could but presently does not validate the @template
      ## resource path onto any registered @bundle for the class

      ## FIXME this needs more project tooling
      ##
      ## see also glib-compile-resources(1) && Rake
      ##  ... --generate riview.gresource.xml ...
      ##
      ## NB glib-compile-schemas(1) && GApplication (&& Rake)

      ## NB here, @template must represent a GResource path, not a filename
      set_template(resource: @template)
    end
    extclass.register
  end
end

module FileTemplateBuilder
  def self.extended(extclass)
    extclass.extend TemplateBuilder

    ## load this class' template as a file
    ##
    ## This method is used by GTK
    ##
    ## @see ::use_template
    def extclass.init
      ## FIXME this pathname expansion needs cleanup
      gem_dir=File.expand_path("..", File.dirname(__FILE__))
      use_path = File.expand_path(@template,gem_dir)
      if File.exists?(use_path)
        ## NB ~/.local/share/gem/ruby/3.0.0/gems/gio2-3.4.9/lib/gio2/file.rb
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
          gfile.unref()
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
  extend FileTemplateBuilder

  ## FIXME integrate with an extension onto Gtk::Application

  self.use_template("ui/appwindow.glade")
  ## FIXME needs more integration with the type decls in the template file
  ##
  ## FIXME needs interop with RIView initialization
  ## ... indep. of window class impl - use one (template or no template)

  # self.use_resource_bundle(...)
  #self.use_template("/space/thinkum/RIView/ui/riview.glade")


  ## NB any Gtk::Builder may not have immediate access to this any
  ## declarations in this class' template
  ##
  ## see also
  ## ** self::bind_template_child && ?? AppWindow aw#get_template_child **
  ## also self.template_children

  ## FIXME just use bind_template_child_full(name,true,0)
  ## for each needed name/obj under the template decl in the UI file
  ##
  ## then access later via the same name, using a Gtk::Builder
  ## for the class && the name
  #self.bind_template_child("WindowLayoutBox") ## test ...
  self.bind_template_child("MenuClose", internal_child: true)

  self.bind_template_child_full("RIPageView", true, 0)

  ## FIXME objects that should be shared across every Window in RIView
  ## - RITagTable01 (presently defined in the UI file)
  ## - configuration UI (TBD - see docs)
  ##   - NB needs gschema additions in this project
  ##
  ## FIXME initialized similarly for every window, though distinct in each:
  ## - RITreeStore
  ##   - could be reused, except for the "expanded" column
  ##   - initialize from a common data source in the application class


  ## FIXME have to manage the beloved menubar and menu in separate UI
  ## files, for this thing?
  ## - & actions (by necessity, are actually not deprecated)

  def initialize(application = nil)
    if application
      super(application: application)
    else
      super()
    end

    name = self.class.name
    close_proc = lambda { |obj|
      application.remove_window(self) if application
      self.unmap()
      self.destroy()
      if (application && application.windows.length.zero?)
        Gtk.main_quit
      end
    }
    self.signal_connect("destroy", &close_proc)
    self.name=name
    self.set_title(name)


    # mclose = self.get_template_child(self.class, "MenuClose")
    ## same as ....
    # mclose = self.MenuClose
    ## or ..., given the :internal_child param on the bind call above ...
    # ** mclose = self.get_internal_child(Gtk::Builder.new,"MenuClose") **
    ## ^ FIXME apply that onto the ObjectFactory pattern for this impl

    # self.present
    # Gtk.main
  end
end

class RIDocView < Gtk::TextView
  extend FileTemplateBuilder
  ## FIXME only one template-based class per UI file...?
  self.use_template("ui/docview.ui")
=begin e.g
aw = AppWindow.new
notebook = aw.get_internal_child(Gtk::Builder.new,"RIPageView")
docview = RIDocView.new

...docview.buffer.tags... ??

notebook.append_page(docview)
...

FIXME may have to make a dynamic object of Gtk::TextBuffer
for the docview, in order to reuse a common tags table - can provide the
tags table only in the TextBuffer constructor. Initialize and set via
application
- the TextBuffer must be new for each tab of the RIPageView notebook,
  but each should reuse a common tags table, such that would be
  configured for its visual qualities under application preferences
=end
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



class GBuilderApp < Gtk::Application

  def self.builder=(builder)
    if @builder && (@builder != builder)
      warn "Builder #{@builder} already initialized for #{self}. Ignoring #{builder}"
    else
      @builder = builder
    end
  end

  def self.builder
    @builder
  end

  def self.add_ui_file(file)
    ## NB this assumes that the UI file
    ## does not contain any template decls.
    ##
    ## i.e each object initialized from the file
    ## will be initialized at most once
    ## for this class
    if File.exists?(file)
      begin
        # Signal.trap("SIGABRT","IGNORE")
        @builder.add_from_file(file)
      ensure
        # Signal.trap("SIGABRT","SYSTEM_DEFAULT")
      end
    else
      raise "File not found: #{file}"
    end
  end

  def initialize(name)
    super(name)
    self.class.builder ||= Gtk::Builder.new
  end

  def run()
    self.register() || raise("register failed")
    ## super(gtk_cmdline_args) # TBD
    Gtk.main()
  end

  def run_threaded()
    NamedThread.new("#{self.class.name} 0x#{self.__id__.to_s(16)}#run") {
      run()
    }
  end

  def quit()
    self.windows.each { |w|
      w.unmap
      w.destroy
    }
    super()
    Gtk.main_quit()
  end
end

=begin TBD
class GTemplateBuilderApp < GBuilderApp
  extend FileTemplateBuilder
end
=end

class RIViewApp < GBuilderApp

  def initialize()
    super("space.thinkum.riview") ## ??
    ## FIXME set a filesystem base directory in the class
    self.signal_connect("startup") {
      ## forms to run subsq. of successful register()
      ##
      ## NB this will be activated by register() only once per process.
      self.map_app_window_new
    }
  end

  def map_prefs_window()
    ## TBD
  end

  def map_app_window_new()
    w = AppWindow.new(self)
    self.add_window(w)
    w.present
  end
end
