## vtytest.rb - prototyping for a Vte::Terminal app after Emacs comint
##
## installation: from the project root directory
## $ rake bundle:install
##
## usage: from the project root directory
## $ ./bin/vtytest
##
## This application requires a working X11 display.
##
## The shell environment should also have been configured for
## xauth support, if required for the X11 display server.
##
## UI files for Glade: from the project root directory
## ./ui/appwindow.vtytest.ui
## ./ui/prefs.vtytest.ui
##

require 'pebbl_app/gtk_support/gtk_app_prototype'

require 'gtk3'

if ! ENV['DISPLAY']
  ## try to prevent a Gtk::InitError if no DISPLAY is available
  ##
  ## Gtk.init may accept a --display arg, unused for purposes of this test
  Kernel.warn("#(File.basename($0)}: No X11 display found in environment", uplevel: 0)
  exit(-1)
end

begin
  Gtk.init(*ARGV)
  rescue Gtk::InitError => e
    this = File.basename($0)
    STDERR.puts "[DEBUG] #{this}: Failed in Gtk.init"
    STDERR.puts e.full_message
    ## FIXME could initialize either pry or irb here, if found
    begin
      irb = Gem::Specification.find_by_name("irb")
    rescue
      STDERR.puts "irb not found"
      exit(-1)
    end
    ## drop into irb and disable $DEBUG
    ## - Some $DEBUG output may interfere with tty i/o under IRB
    irb.activate
    $DEBUG = false
    $INIT_ERROR = e
    require %q(bundler/setup)
    require %q(irb)
    require %q(irb/completion)
    STDERR.puts "[DEBUG] #{this}: Gtk::InitError stored as $INIT_ERROR"
    IRB.start(__FILE__)
end

require 'vte3'
require 'shellwords'

## Prototype for GLib type extension support in PebblAPp
module BoxedProto
  def self.extended(whence)
    ## register the class, at most once
    if ! whence.class_variable_defined?(:@@registered)
      ## FIXME does not detect duplcate registrations
      ## of differing implmentation classes
      whence.type_register
      whence.class_variable_set(:@@registered, true)
    end
  end
end

## Base module for template support in this prototype
module CompositeProto
  def self.extended(whence)
    whence.extend BoxedProto

    ## common method for init with file-based or resource-path-based
    ## composite classes
    def initialize_template_children
      self.template_children.each do |id|
        Kernel.warn("Binding template child #{id} for #{self}", uplevel: 0) ## DEBUG
        bind_template_child(id)
      end

      self.set_connect_func do |name|
        Kernel.warn("Binding method #{name} for #{self}", uplevel: 0) ## DEBUG
        method name
      end
    end
  end ## self.extended
end

## prototype module for classes using a template definition with
## GTK Builder, when the template is initialized directly from a
## UI file source
##
module CompositeFileProto
  def self.extended(whence)
    whence.extend CompositeProto

    ## initialize a file-based template for this class, using the class
    ## constant TEMPLATE to determine the template file's pathname
    def init
      if File.exists?(self::TEMPLATE)
        ## NB Gio::File @ gem gio2 lib/gio2/file.rb
        ## File, GFileInputStream topics under GNOME devhelp
        gfile = false
        fio = false
        begin
          gfile = Gio::File.open(path: self::TEMPLATE)
          fio = gfile.read
          nbytes = File.size(self::TEMPLATE)
          bytes = fio.read_bytes(nbytes)
          Kernel.warn("Setting template data for #{self} @ #{self::TEMPLATE}",
                      uplevel: 0)
          self.set_template(data: bytes)
        ensure
          ## TBD no #unref available for GLib::Bytes here
          fio.unref() if fio
          gfile.unref() if gfile
        end
      else
        raise "Template does not exist: #{self::TEMPLATE}"
      end
      self.initialize_template_children
    end ## whence.init

  end
end


## configuration support for VtyApp
##
## an instance of this class is returned from VtyApp#config
class VtyConfig < PebblApp::GtkSupport::GtkConfig

  ## command line options parsing vor VtyApp
  def configure_option_parser(parser)
    super(parser)
    parser.on("-c", "--command COMMAND", "Command to use for shell") do |cmd|
      self.options.shell = cmd
    end
  end

end

##
## preferences window for VtyApp
##
class VtyPrefsWindow < Gtk::Dialog
  TEMPLATE ||=
    File.expand_path("../ui/prefs.vtytest.ui", __dir__)

  extend BoxedProto
  extend CompositeFileProto

  class << self
    ## configuration for initialize_template_children in init
    def template_children
      %w(shell_cmd_entry io_model_combo prefs_stack prefs_sb)
    end
  end ## class << self


  def initialize(**args)
    super(**args)
  end

  ## unmap and recycle the window
  def close
    self.unmap
    self.destroy
  end

  ##
  ## -- signal receivers for the window --
  ##
  ## mapped to actionable widgets via the Glade UI editor, "signals" panel
  ##

  def vty_io_model_changed(obj)
    ## mapped to the 'changed' signal in the io_model_combo widget
  end

  def vty_default_shell_changed(obj)
    ## mapped to the 'changed' signal in the shell_cmd_entry widget
  end


  ## close the prefs window without updating configuration changes
  def prefs_cancel(obj)
    ## mapped to the "clicked" signal for a button in the dialog window
    Kernel.warn("cancel @ #{obj} => #{self}", uplevel: 0)
    self.close
  end

  ## apply configuration changes without closing the window
  def prefs_apply(obj)
    ## mapped to the "clicked" signal for a button in the dialog window
  end

  ## apply configuration configuration changes and close the window
  def prefs_ok(obj)
    ## mapped to the "clicked" signal for a button in the dialog window
    self.close
  end
end


##
## Main application window class, VtyApp
##
class VtyAppWindow < Gtk::ApplicationWindow
  TEMPLATE ||=
    File.expand_path("../ui/appwindow.vtytest.ui", __dir__)

  extend BoxedProto
  extend CompositeFileProto

  class << self
    ## configuration for initialize_template_children in init
    def template_children
      %w(vty vty_send vtwin_vty_menu vty_app_menu vty_menu
         vty_entry vty_entry_buff vty_entry_completion)
    end
  end ## class << self


  def initialize(app)
    Kernel.warn("Initializing #{self}", uplevel: 0)
    super(application: app)
    ## bind actions, signals ...
  end

  ###########################################3
  ## signal receiver methods
  ## - configured e.g via the 'signals' tab in the Glade UI editor
  ## - the "handler" there may represent a method name,
  ##   while the "user data" widget selected there may represent
  ##   the recipient of the method
  ## - receiver method args may vary by signal type,
  ##   typically including at least one arg representing
  ##   the active widget when the signal is sent

  def vtwin_close
    self.close
  end

  def vty_eof
    ## self.class.send_vte_eof(self.vte) ...
  end

  def vty_reset
    self.vty.reset(false, false)
  end

  ## present an application preferences window, creating a new
  ## preferences window if not already initialized for the VtyApp
  def vtwin_show_prefs(obj)
    Kernel.warn("Prefs method received data: #{obj.inspect}",
                uplevel: 0)
    app = self.application
    app.ensure_prefs_window(app.active_window || self).present
  end

  def vtwin_show_about(obj)
  end

  def vtwin_new
    win = self.class.new(self.application)
    win.show
  end

  def vtwin_save_text
    ## self.class.save_vte_text(...)
  end

  def vtwin_save_data
    ## self.class.save_vte_data(...)
  end

  def vtwin_send
    ## from the 'send' button - send any text in vty_entry_buff
    ## to the input stream of the pty/pipe
  end

  def vtwin_received_eof(vty)
  end

  def vtwin_received_exit(vty)
  end

end


class VtyApp < Gtk::Application
  include PebblApp::GtkSupport::GtkAppPrototype

  class << self
    ## internal instance tracking for VtyApp
    ## - not integrated with dbus
    def started
      if class_variable_defined?(:@@started)
        @@started
      else
        false
      end
    end

    def started=(inst)
      @@started = inst
    end
  end ## class << self

  def default_shell=(cmd)
    @default_shell = cmd
  end

  def default_shell
    ## TBD - should be implemented as a configurable property
    ## of the app and/or window
    if instance_variable_defined?(:@default_shell)
      return @default_shell
    elsif self.config.option?(:shell)
      return self.config.options[:shell]
    else
      return Vte.user_shell
    end
  end


  def action_group_name()
    ## a hack for map_simple_action
    ##
    ## this hard-codes the name of an action group for the application,
    ## assuming this matches an action group created somewhere in GTK
    ## for the application
    ##
    return "app".freeze
  end

  ## utility method for GAction initialization
  ##
  ## used for binding a callback to app.quit
  def map_simple_action(name, group: nil,
                        accel: nil, &handler)
    ## GSimpleAction is the name of a class
    if (! group)
      if (name.include?("."))
        elts = name.split(".")
        group = elts[0]
        if elts.length > 1
          name = elts[1..].join(".")
        else
          raise "No action name provided in string #{name.inspect}"
        end
      else
        group = self.action_group_name
      end
    end

    Kernel.warn("Binding action #{group}.#{name} for #{self}", uplevel: 1)

    act = Gio::SimpleAction.new(name)
    if block_given?
      act.signal_connect("activate") do |action, param|
        ## TBD how is a parameter ever delivered to an action's activate signal?
        handler.yield(action, param)
      end
      self.add_action(act)
    else
      raise "No block provided"
    end

    if accel
      with_accels = (Array === accel) ? accel : [accel]
      self.set_accels_for_action(('%s.%s' % [group, name]), with_accels)
    end
  end

  def register()
    ## may not be reached in the underlying API when this method is
    ## overridden, unless this method is called directly as from this
    ## class or a subclass
    Kernel.warn("Registering #{self.inspect}", uplevel: 0)
    super()
  end

  ## TBD accessor for the 'active-window' property on this Gtk::Application

  def initialize()
    ## the first arg for the Gtk::Application constructor is required,
    ## and requires a specific syntax e.g
    super("space.thinkum.vtytest",
          Gio::ApplicationFlags::SEND_ENVIRONMENT |
            Gio::ApplicationFlags::NON_UNIQUE)
    ## TBD managing multiple app instances in or outside of a single
    ## process, and side effects w/ dbus - alternately, connecting
    ## to some existing app instance, if already initialized

    ## map a handler for the app 'startup' signal,
    ## reached e.g via self.register
    signal_connect "startup" do |app|
      app.handle_startup
    end

    ## map a handler for the app 'activate' signal
    ## might be reached via self.run
    signal_connect "activate" do |app|
      app.handle_activate
    end

    ## TBD for app support - no "open" handling supported in this app
    # signal_connect "open" do |app|
    #   app.handle_open
    # end

  end

  ## handler for the app's 'startup' signal,
  def handle_startup()

    if ((started = self.class.started) && !started.eql?(self))
      Kernel.warn("Starting duplicate instance for #{self.class}: #{self.inspect} - existing: #{started.inspect}",
                  uplevel: 1)
    else
      Kernel.warn("Starting initial instance for #{self.class}: #{self.inspect}",
                  uplevel: 1)
    end

    ## bind C-q to an 'app.quit' action,
    ## also defining a handler for that action
    self.map_simple_action("app.quit", accel: "<Ctrl>Q") do
      self.quit
    end
  end

  ## handler for the app 'activate' signal
  def handle_activate()
      Kernel.warn("Handling activate for #{self.class}: #{self.inspect}",
                  uplevel: 1)
      window = create_app_window
      window.present
  end

  ## the preferences window for this application,
  ## if any preferences window is active
  attr_accessor :prefs_window

  ## create a new application preferences window for this application
  ##
  ## at most one preferences window should be visible for a single
  ## appliction instance
  def ensure_prefs_window(transient_for = self.active_window)
    if ! (wdw = self.prefs_window)
      wdw = VtyPrefsWindow.new(transient_for: transient_for)
      wdw.signal_connect_after("destroy") do
        self.prefs_window = nil
      end
      self.prefs_window = wdw
    end
    return wdw
  end

  ## create a new application window
  def create_app_window()
    VtyAppWindow.new(self)
  end

  ## return the config instance for this application
  def config
    @config || VtyConfig.new(self) do
      ## callback for the Config object's 'name' param
      self.app_cmd_name
    end
  end

  ## run this application
  def run()
    Kernel.warn("Registering #{self}", uplevel: 0)
    self.register
    Kernel.warn("Start for #{self}", uplevel: 0)
    self.start
    super
  end

  ## called from #activate, via inclusion of
  ## PebblApp::GtkSupport::GtkAppPrototype
  def start(args = nil)
    if args && (! args.empty?)
      Kernel.warn("Discarding args: #{args.inspect}", uplevel: 0)
    end

    Kernel.warn("Starting #{self} with default shell #{self.default_shell}",
                uplevel: 0)

    begin
      self.class.started = self
      ## calling this class' own #register directly
      ##
      ## in a superclass method, this may activate the application's
      ## 'startup' signal by side effect
      self.register
    rescue Gio::IOError::Exists => e
      raise e
    end

    ## TBD dispatching for run <...> start here
  end
end

