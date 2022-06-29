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
module FileCompositeWidget
  def self.extended(whence)
    whence.extend CompositeWidget

    ## initialize a file-based template for this class, using the class
    ## constant TEMPLATE to determine the template file's pathname
    def use_template(filename, children = false)

      if File.exists?(filename)
        ## NB Gio::File @ gem gio2 lib/gio2/file.rb
        ## File, GFileInputStream topics under GNOME devhelp
        gfile = false
        fio = false
        abs = File.expand_path(filename)
        begin
          gfile = Gio::File.open(path: abs)
          fio = gfile.read
          nbytes = File.size(filename)
          bytes = fio.read_bytes(nbytes)
          Kernel.warn("Setting template data for #{self} @ #{filename}",
                      uplevel: 0) ## DEBUG
          self.set_template(data: bytes)
        ensure
          fio.unref() if fio
          gfile.unref() if gfile
        end
      else
        raise "Template file does not exist: #{filename}"
      end
      self.initialize_template_children(children, abs) if children
      return abs
    end ## whence.use_template
  end
end


## configuration support for VtyApp
##
## an instance of this class is returned from VtyApp#conf
class VtyConf < PebblApp::GtkSupport::GtkConfig

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

  extend FileCompositeWidget


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

  def vty_io_model_changed
    ## method mapped to the 'changed' signal in the io_model_combo widget
  end

  def vty_default_shell_changed
    ## method mapped to the 'changed' signal in the shell_cmd_entry widget
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

  extend FileCompositeWidget
  use_template(File.expand_path("../ui/appwindow.vtytest.ui", __dir__),
               %w(vty vty_send vtwin_vty_menu vty_app_menu vty_menu
                  vty_entry vty_entry_buffer vty_entry_completion
                  editpop_popover editpop_textbuffer
                  editpop_tags
                  editpop_textview
                  vtwin_header
                 ))


  def shell=(sh)
    @shell = (String === sh) ? Shellwords.split(sh) : sh
  end

  def shell
    if instance_variable_defined?(:@shell)
       instance_variable_get(:@shell)
    elsif self.application
      self.shell = self.application.default_shell
    elsif (sh = ENV['SHELL'])
      self.shell = sh
    else
      Vte.user_shell
    end
  end

  ## PID of the subprocess, or nil
  attr_accessor :subprocess_pid
  ## convenience accessor
  attr_accessor :subprocess_pty
  ## IO on the pty or nil
  attr_accessor :pty_io

  ## convenience method
  attr_accessor :newline


  def popover_entry_swap_text
    popover = self.vty_entry_popover
    popover_inactive =
      (popover.state_flags & Gtk::StateFlags::ACTIVE).to_i.eql?(0)
    if popover_inactive
      self.vty_entry.text =
        self.vty_entry_ext_textbuffer.text
    else
      self.vty_entry_ext_textbuffer.text =
        self.vty_entry.text
    end
    return popover
  end


  def initialize(app)
    Kernel.warn("Initializing #{self}", uplevel: 0)

    super(application: app)
    ##
    ## local conf
    ##

    # prefixes = self.action_prefixes
    # Kernel.warn("Action prefixes (#{prefixes.length})")
    # prefixes.each do |pfx|
    #   ## >> win, app
    #   Kernel.warn pfx
    # end

    ## hack in a default newline for the Vte::Pty in the Vte::Terminal
    ## in this app window
    nlio = StringIO.new
    nlio.puts
    @newline = nlio.string

    ## bind actions, signals ...


    ## coordination for the input text entry
    ## and popover text view
    popover = self.editpop_popover
    self.vty_entry.signal_connect("icon-press") do
      if popover.visible?
        popover.hide
      else
        popover.show
      end
    end
    popover.signal_connect("hide") do
      self.vty_entry_buffer.text =
        self.editpop_textbuffer.text
    end
    popover.signal_connect("show") do
      self.editpop_textbuffer.text =
        self.vty_entry_buffer.text
    end

    ## TBD conf options (framework, app conf and framework, app, window conf)
    self.vty.enable_sixel = true if self.vty.respond_to?(:enable_sixel=)

    ## TBD configuring PWD, ENV, shell ...
    ## for a pty I/O mode, though the Vte::Pty is not accessible here (FIXME)
    sh = self.shell
    vty_env = ENV.map { |elt| "%s=%s" % elt }
    Kernel.warn("Using shell #{sh.inspect}", uplevel: 0)
    ## before starting any shell ... binding a signal on pty activation
    self.vty.signal_connect_after("notify::pty") do |obj, prop|
      ## OBJ should be the Vte::Terminal for this app window
      ## FIXME move to a pty adapter

      ## update the subprocess_pty for this app window
      was_pty = self.subprocess_pty
      self.subprocess_pty = obj.pty
      Kernel.warn(
        "PTY updated for %s : %p => %p" % [
          self, was_pty, obj.pty
        ])
      ## open / close the pty_io for this app window
      if obj.pty
        ## FIXME use any encoding stored in conf for the window
        self.pty_io = File.open(obj.pty.fd, "wb")
      elsif (io = self.pty_io)
        io.close if (IO === io)
        self.pty_io = nil
      end
    end


    self.vty.signal_connect_after("commit") do |vt, text, len|
      ## this signal is activated for individual charact entries to the
      ## PTY, as well as for any full-string send
      ##
      ## of course, this is not activated on direct send to the PTY FD
      Kernel.warn("Commit: #{text.inspect}")
    end

    ## TBD move this to a ManagedPty adapter
    success, pid  = self.vty.spawn_sync(Vte::PtyFlags::DEFAULT, Dir.pwd,
                                        sh, vty_env, GLib::Spawn::SEARCH_PATH)

    if success
      Kernel.warn("Initializing #{pid} for #{self}")
      sh_shortname = File.basename(self.shell.first)
      self.title = sh_shortname
      self.vtwin_header.title = sh_shortname
      self.subprocess_pid = pid
      self.vtwin_header.subtitle = Const::RUNNING
    else
      self.vtwin_header.subtitle = Const::FAILED
      Kernel.warn("Failed. closing window")
      self.close
    end

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
    ## signal handler on vtwin_close_entry, a menu entry
    self.close
  end

  def vty_eof
    self.vty.feed_child(Const::EOF)
  end

  def vty_reset
    self.vty.reset(false, false)
  end

  ## present an application preferences window, creating a new
  ## preferences window if not already initialized for the VtyApp
  def vtwin_show_prefs
    app = self.application
    app.ensure_prefs_window(app.active_window || self).present
  end

  def vtwin_show_about
    ## needs another UI definition, and a project concept
  end

  def vtwin_new
    win = self.class.new(self.application)
    win.show
  end

  def vtwin_save_data
  end

  def vtwin_save_text
    ## self.class.save_vte_text(...)
  end


  def vtwin_send

    popover = self.editpop_popover
    if popover.visible?
      ## a side effect of the hide action:
      ## any text in the popover text view will be set to the text
      ## buffer in the main text entry field
      popover.hide
    end

    ## mapped to the 'clicked' signal on the window 'send' button
    ##
    ## send any text in vty_entry_buffer to the pty,
    ## using feed_child_raw (if defined)
    ## or feed_child (if local sources / updated)
    text = vty_entry_buffer.text + self.newline
    Kernel.warn("Sending text: #{text.inspect}")
    if vty.respond_to?(:feed_child_raw)
      Kernel.warn("DEBUG using feed_child_raw")
      vty.feed_child_raw(text)
    else
      ## patch
      Kernel.warn("DEBUG using feed_child")
      vty.feed_child(text)
    end
  end

  def vtwin_received_eof(vty)
  end

  def vtwin_subprocess_exit(vty, status)
    ## signal handler for the child-exited signal
    ##
    ## assigned to the vty object (a Vte::Teriminal) on the app window
    if ! self.in_destruction?
      self.vtwin_header.subtitle = "pid %s %s %s" % [
        self.subprocess_pid, Const::EXITED, status
      ]
    end
  end

end


class VtyApp < Gtk::Application
  include PebblApp::GtkSupport::GtkAppPrototype

  class << self
    ## internal instance tracking for VtyApp
    ## - not yet integrated with dbus
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

  ## ad hoc place holders for app conf @ shell
  def default_shell=(cmd)
    @default_shell = cmd
  end
  def default_shell
    ## TBD - should be implemented as a configurable property
    ## of the app and/or window
    if instance_variable_defined?(:@default_shell)
      return @default_shell
    elsif self.conf.option?(:shell)
      return self.conf.options[:shell]
    else
      return Vte.user_shell
    end
  end


  def action_prefix(widget)
    ## a hack for map_simple_action
    ##
    ## this hard-codes the name of an action prefix for the application,
    ## assuming this matches an action group created somewhere in GTK
    ## for the application
    ##
    case widget
    when Gtk::Application
      ## no action_prefixes method for this class of object
      "app".freeze
    else
      all = widget.action_prefixes
      if all.empty
        raise "No action prefixes found for #{widget}"
      else
        ## Assumption: the first action prefix may represent a default
        ## e.g "win" in %w(win app) for a Gtk::ApplicationWindow
        all[0]
      end
    end
  end

  ## utility method for GAction initialization
  ##
  ## used for binding a callback to app.quit
  def map_simple_action(name, prefix: nil,
                        accel: nil, widget: self,
                        &handler)
    if (! prefix)
      if (name.include?("."))
        elts = name.split(".")
        prefix = elts[0]
        if elts.length > 1
          name = elts[1..].join(".")
        else
          raise "Unable to parse action name #{name.inspect}"
        end
      else
        prefix = action_prefix(widget)
      end
    end

    Kernel.warn("Binding action #{prefix}.#{name} for #{self}", uplevel: 1)

    act = Gio::SimpleAction.new(name)
    if block_given?
      act.signal_connect("activate") do |action, param|
        handler.yield(action, param)
      end
      self.add_action(act)
    else
      raise "No block provided"
    end

    if accel
      with_accels = (Array === accel) ? accel : [accel]
      self.set_accels_for_action(('%s.%s' % [prefix, name]), with_accels)
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

    self.signal_connect_after("window-removed") do
      if self.windows.empty?
        self.quit
      end
    end
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
    ## initialize and configure a main window for this application
    appwdw = VtyAppWindow.new(self)
    appwdw.shell = self.default_shell
    return appwdw
  end


  def quit()
    super()
    Kernel.warn("Calling Gtk.main_quit in Thread 0x%06x" % [Thread.current.__id__],
                uplevel: 0)
    self.windows.each do |wdw|
      wdw.close
    end
    Gtk.main_quit
  end

  ## return the VtyConf instance for this application
  def conf
    #self.default_shell = %w(bash -i)
    self.default_shell = %w(ruby -r irb -r irb/completion -e IRB.start)
    @conf || VtyConf.new(self) do
      ## callback for the conf object's 'name' param
      self.app_cmd_name
    end
  end

  ## run this application
  def run()
    if self.registered?
      Kernel.warn("Already registered: #{self}", uplevel: 0)
      ## if self.remote?
      ##  ... self is not the primary application instance ...
      ## end
    else
      Kernel.warn("Registering #{self}", uplevel: 0)
      ## may err - see devhelp
      ## the register call will result in the 'startup' signal
      ## activating for the application
      self.register
    end
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

