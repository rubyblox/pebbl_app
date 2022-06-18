## vtytest.rb

require 'pebbl_app/gtk_support/gtk_app_prototype'

require 'gtk3'
require 'vte3'
require 'shellwords'


module BoxedProto
  def self.extended(whence)
    if ! whence.class_variable_defined?(:@@registered)
      ## FIXME does not detect duplcate registrations
      ## of differing implmentation classes
      whence.type_register
      whence.class_variable_set(:@@registered, true)
    end
  end
end

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

## prototype module for classes deriving a Gtk Builder template
## definition directly from a UI file source
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
## an instance of this class is returned from VtyApp#config. The
## instance will have been initialized for the application command name
## of the calling VtyApp
##
class VtyConfig < PebblApp::GtkSupport::GtkConfig

  ## command line options parsing vor VtyApp
  def configure_option_parser(parser)
    super(parser)
    parser.on("-c", "--command COMMAND", "Command to use for shell") do |cmd|
      self.options.shell = cmd
    end
  end

end



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
  ## - if receiver method is defined as name(obj) then the obj may represent
  ##   the "active widget" of the signal's activation, e.g a menu item

  def vtwin_close
    self.close
  end

  def vty_eof
    ## self.class.send_vte_eof(self.vte) ...
  end

  def vty_reset
    self.vty.reset(false, false)
  end

  def vtwin_show_prefs(obj)
    ## ... map a prefs window, attached to the active window for this
    ## window's application, if no prefs window already exists,
    ## else raise the prefs window

    Kernel.warn("Prefs method received data: #{obj.inspect}",
                uplevel: 0)
    app = self.application
    app.prefs_window ||= app.create_prefs_window(app.active_window || self)
    # if (! apps.prefs_window.visible?)
    #   app.prefs_window.show
    # end
    # app.prefs_window.raise
    ## or (??)
    app.prefs_window.present
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

    def started
      ## TBD state recording for instances of this app class
      ## onto Gtk dbus conventions
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
    ## TBD - should be a configurable property of the app and/or window
    if instance_variable_defined?(:@default_shell)
      return @default_shell
    elsif self.config.option?(:shell)
      return self.config.options[:shell]
    else
      return Vte.user_shell
    end
  end


  def action_group_name()
    ## TBD - this is a hack for map_simple_action
    ##
    ## Absent of any apparent way to retrieve the name for any action
    ## group for an action group implementor in GTK, hard-coding a
    ## single action group name in each action group proxy instance,
    ## here e.g onto Gtk::Application
    return "app".freeze
  end

  ## utility method for GAction initialization
  ##
  ## FIXME move to a new GActionReceiver module after tests
  ## - include module in GAppPrototype
  ## - include module in GAppWindowPrototype (new)
  ##
  ## FIXME alternate approach: Use signal handlers configured via the
  ## Glade UI editor, not menu actions per se
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
    ## ^ TBD does this call 'register' in some way, e.g in Gtk ?
    ## ^ TBD calling with flags for multiple instance of the app

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

    ## TBD for app support prototypes - no "open" handling supported here
    # signal_connect "open" do |app|
    #   app.handle_open
    # end

  end

  ## handler for the app's 'startup' signal,
  ## typically reached via #register on some class
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
  ##
  ## at most one preferences window should be visible for a single
  ## appliction instance
  def create_prefs_window(transient_for = self.active_window)
    wdw = VtyPrefsWindow.new(transient_for: transient_for)
    wdw.signal_connect_after("destroy") do
        self.prefs_window = nil
    end
    return wdw
  end

  def create_app_window()
    VtyAppWindow.new(self)
  end

  def config
    @config || VtyConfig.new(self) do
      ## callback for the Config object's 'name' param
      self.app_cmd_name
    end
  end

  def run()
    ## reached before #start
    Kernel.warn("Registering #{self}", uplevel: 0)
    self.register
    Kernel.warn("Start for #{self}", uplevel: 0)
    self.start
    # Kernel.warn("Activating #{self}", uplevel: 0)
    # self.activate
    # Kernel.warn("Calling superclass run mtd for #{self}", uplevel: 0)
    super
  end

  ## called from #activate as defined via inclusion of GtkAppPrototype
  ##
  def start(args = nil)
    ## args would not be handled here, should typically be empty
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

