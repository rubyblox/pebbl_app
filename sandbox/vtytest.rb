## vtytest.rb

require 'pebbl_app/gtk_support/gtk_app_prototype'

require 'gtk3'
require 'vte3'
require 'shellwords'


module GBoxedProto
  def self.extended(whence)
    if ! class_variable_defined?(:@@registered)
      ## FIXME does not detect duplcate registrations
      ## of differing implmentation classes
      whence.type_register
      @@registered = true
    end
  end
end

module GtkCompositeProto
  def self.extended(whence)
    whence.extend GBoxedProto

    ## common method for file-based or resource-path-based composite classes
    def initialize_template_children
      self.template_children.each do |id|
        Kernel.warn("Binding template child #{id} for #{self}", uplevel: 0) ## DEBUG
        bind_template_child(id)
      end

      set_connect_func do |name|
        Kernel.warn("Binding method #{name} for #{self}", uplevel: 0) ## DEBUG
        method name
      end
    end
  end
end

module GtkCompositeFileProto
  def self.extended(whence)
    whence.extend GtkCompositeProto

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
          Kernel.warn("Setting template for #{self} from #{self::TEMPLATE}",
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


class VtyConfig < PebblApp::GtkSupport::GtkConfig

  ## configuration support for VtyApp - command line options paring
  def configure_option_parser(parser)
    super(parser)
    parser.on("-c", "--command COMMAND", "Command to use for shell") do |cmd|
      self.options.shell = cmd
    end
  end

end


class VtyAppWindow < Gtk::ApplicationWindow
  TEMPLATE ||=
    File.expand_path("../ui/appwindow.vtytest.ui", __dir__)

  extend GBoxedProto
  extend GtkCompositeFileProto

  class << self
    ## configuration for initialize_template_children in init
    def template_children
      %w(vty vty_send vtwin_vty_menu vty_app_menu vty_menu)
    end
  end ## class << self

  def initialize(app)
    Kernel.warn("Initializing #{self}", uplevel: 0)
    super(application: app)
    ## bind actions, signals ...
  end

  ###########################################3
  ## signal handler methods
  ## - configured e.g via the 'signals' tab in the Glade UI editor
  ## - the "handler" there may represents a method name,
  ##   while the "user data" widget selected there may represent
  ##   the recipient of the method

  def vty_eof
    ## self.vte ...
  end

  def vty_reset
    ## self.vte ...
  end

end

class VtyApp < Gtk::Application
  include PebblApp::GtkSupport::GtkAppPrototype

  class << self
    def default_shell()
      if class_variable_defined?(:@@default_shell)
        @@default_shell
      else
        Vte.user_shell
      end
    end

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

  def guess_active_window()
    windows = self.windows
    if windows.empty?
      raise "No active window"
    else
      ## FIXME trivial parse - the first window may not have been the
      ## active window e.g for which a prefernces menu item was selected
      ##
      ## thus, the signal handlers approach would be preferred here,
      ## notwithstanding particulars of rhetoric about GAction usage,
      ## menus, and proposals for UI designs in the ostensible wiki docs
      ##
      ## - signal handlers can be mapped to actual objects. This is -
      ##   for now - fairly easy to configure with the Glade UI editor
      ##
      ## if one must try out an approach with GAction ...
      windows.first
    end
  end


  def register()
    ## not reached unless called directly here
    ## though a superclass #register method is reached via some other call
    Kernel.warn("Registering #{self.inspect}", uplevel: 0)
    ## fails from #start - duplicate registration (when? by what call?)
    super()
  end

  def initialize()
    ## the first arg for the Gtk::Application constructor is required,
    ## and requires a specific syntax e.g
    super("space.thinkum.vtytest")
    ## ^ TBD does this call 'register' in some way ?

    ## map a handler for the the 'startup' signal,
    ## reached after self.register
    signal_connect "startup" do |app|
      app.handle_startup
    end

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

    @running = self

    ## map a GAction for 'app.quit' on this GtkApplication
    #
    # quit = Gio::SimpleAction.new("quit")
    # quit.signal_connect("activate") do
    #   application.quit
    # end
    # app.add_action(quit)
    # app.set_accels_for_action("app.quit", quit)
    ## or:
    self.map_simple_action("app.quit", accel: "<Ctrl>Q") do
      self.quit
    end

    self.map_simple_action('app.prefs') do # |action, param|
      ## it would be great if the action initializer could pass an
      ## activating window as the param, e.g via the 'activate' signal
      ## on each menu item - whether or not this would be compatible
      ## with the novelty of GVariant (it would not be)
      ##
      # prefs = VtyPrefs.new(:transient_for => self.guess_active_window), use_header_bar: true)i
      ## alernately, there are singal handlers - such that will probably not
      ## ever be removed from the GTK API
    end

    self.map_simple_action('app.activate') do
    end
  end

  def handle_activate()
    window = VtyAppWindow.new(self)
    window.present
  end

  def config
    @config || VtyConfig.new(self) do
      ## callback for the Config object's 'name' param
      self.app_cmd_name
    end
  end

  def run()
    self.start
    super
  end

  def start(args = nil)
    ## args would not be handled here, should typically be empty
    if args && (! args.empty?)
      Kernel.warn("Discarding args: #{args.inspect}", uplevel: 0)
    end


    if @running
      Kernel.warn("already running: #{@running.inspect}", uplevel: 1)
    else
      ## FIXME first map a handler for the "startup" signal
      ## in this application, before self.register
      begin

        self.class.started = self

        # self.register ## glib. may activate the 'startup' signal
        ## ^ TBD where is GApplication#register being called when it's not called here?

      rescue Gio::IOError::Exists => e
        ## TBD - determining what other application instance is already registerd
        ## while this duplicate application instance cannot be registered
        raise e
      end
    end
    ## TBD dispatching for run <...> start here
  end
end

$APP = VtyApp.new
$APP.activate

