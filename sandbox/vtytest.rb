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

require 'pebbl_app/gtk_app'
require 'pebbl_app/shell'

require 'vte3'
require 'shellwords'

module Const
  UNKNOWN = "(unknown)".freeze
  ## subtitle strings for pty state (TBD gettext)
  RUNNING = "running".freeze
  FAILED = "failed".freeze
  EXITED = "exited".freeze

  ## Default for a Vte option - charcters to parse as a part of a word,
  ## during word-focused text selection in the Vte Pty
  ##
  ## Devehlp specifies "ASCII" here but that may not have been updated
  ## since the further adoption of UTF-8 in Vte
  WORD_CHARS="-.:/$%@~&"
end


## configuration support for VtyApp
##
## an instance of this class is returned from VtyApp#conf
class VtyConf < PebblApp::GtkConf

  def initialize()
    super(self.command_name)
  end

  ## command line options parsing for VtyApp
  def configure_option_parser(parser)
    PebblApp::AppLog.debug("Configuring opts parser #{parser}")
    super(parser)
    self.map_default(:shell) do
      VtyApp.app.shell
    end
    parser.on("-c", "--command COMMAND", "Shell command") do |cmd|
      PebblApp::AppLog.debug("Configuring for shell #{cmd.inspect}") ## reached
      self.options.shell = ( Array === cmd ? cmd : Shellwords.split(cmd) )
    end
  end

end

##
## preferences window for VtyApp
##
class VtyPrefsWindow < Gtk::Dialog
  extend PebblApp::FileCompositeWidget
  ## FIXME set the template file path relative to some external base directory
  ## - project directory, if this is "running in its own original source tree"
  ## - app data directory, if this is "running under a gem installation:"
  ## - in the first case, the app data directory could be set within the
  ##   project Gemfile (FIXME Gemfile helpers for YSpec)
  use_template(File.expand_path("../ui/prefs.vtytest.ui", __dir__),
               %w(sh_command_entry prefs_stack prefs_sb
                 ))

  include PebblApp::DialogMixin

  ## FIXME test completion support @ sh_command_entry
  ##
  ## FIXME add prefs panels to the stack & handle here:
  ## - vty console profile - selection, definition
  ## - font prefs panel (reusable)
  ## - see xfce4-terminal as a terminal reference implementation

  ##
  ## additional signal receivers for widgets under the prefs window
  ##

  def vty_shell_changed(obj)
    ## method mapped to the 'icon-pressed' signal in the sh_command_entry widget
  end
end


##
## Main application window class, VtyApp
##
class VtyAppWindow < Gtk::ApplicationWindow

  extend PebblApp::FileCompositeWidget
  ## FIXME set the template file path relative to some external base directory
  ## or use a resource-path-based template path && glib-compile-resources
  ## && something to load the resource bundle at a pathnmame relative to
  ## some external base directory
  use_template(File.expand_path("../ui/appwindow.vtytest.ui", __dir__),
               %w(vty vty_send vtwin_vty_menu vty_app_menu vty_menu
                  vty_entry vty_entry_buffer vty_entry_completion
                  editpop_popover editpop_textbuffer
                  editpop_tags
                  editpop_textview
                  vtwin_header
                 ))

  include PebblApp::ActionableMixin

  ## FIXME add this to_s definition to an AppWindowMixin
  def to_s()
    ## FIXME operations on GTK properties of the window may be problematic,
    ## while the window is still being initialized
    begin
      app_id = false
      window_id = false
      if (app = self.application)
        ## FIXME still retrieving an uninitialized object here
        app_id = app.application_id
      else
        app_id = "(no application)".freeze
      end
      window_id = self.id
    rescue TypeError
      app_id ||= "(_)".freeze
      window_id = "(_)".freeze
    end

    "#<%s %s %s 0x%06x>" % [
      self.class, app_id, window_id, __id__
    ]
  end


  ## FIXME args parsing, app conf, app packaging, ...

  def shell=(sh)
    @shell = (String === sh) ? Shellwords.split(sh) : sh
  end

  def shell
    ## TBD @ setting shell here
    if instance_variable_defined?(:@shell)
       instance_variable_get(:@shell)
    else
      self.shell = self.application.shell
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

  def initialize(app)
    super(application: app)
    ## debug after the super call, to ensure the Gtk object is initialized
    PebblApp::AppLog.debug("Initializing #{self}")

    ##
    ## local conf
    ##

    vty.word_char_exceptions=Const::WORD_CHARS

    ## trying implementation w/i a scrolled window
    vty.enable_fallback_scrolling=nil
    vty.scroll_unit_is_pixels=true

    # prefixes = self.action_prefixes
    # PebblApp::AppLog.debug("Action prefixes (#{prefixes.length})")
    # prefixes.each do |pfx|
    #   ## >> win, app
    #   debug pfx
    # end

    ## hack a default newline
    @newline = PebblApp::Shell::Const::PLATFORM_NL

    ## bind actions, signals ...

    map_simple_action("win.new") do |action|
      wdw = self.class.new(self.application)
      self.application.add_window(wdw)
      wdw.present
    end

    map_simple_action("win.save-text") do |action|
      ## FIXME needs impl
      vwin_save_text(action)
    end

    map_simple_action("win.save-data") do |action|
      ## FIXME needs impl
      vtwin_save_data(action)
    end

    map_simple_action("win.prefs") do |action|
      vtwin_show_prefs(action)
    end

    map_simple_action("win.close") do |action|
      vtwin_close(action)
    end
    ## coordination for the input text entry
    ## and popover text view
    popover = self.editpop_popover
    self.vty_entry.signal_connect("icon-press") do |obj|
      if popover.visible?
        popover.hide
      else
        popover.show
      end
    end
    popover.signal_connect("hide") do |obj|
      ## TBD not every "hide"  for the popover should result in swapping
      ## the text into the entry buffer
      self.vty_entry_buffer.text = self.editpop_textbuffer.text
    end
    popover.signal_connect("show") do |obj|
      self.editpop_textbuffer.text = self.vty_entry_buffer.text
    end

    self.vty.enable_sixel = true if VtyApp::FEATURE_FLAGS.include?(:FLAG_SIXEL)

    ## TBD configuring PWD, ENV, shell ...
    ## for a pty I/O mode, though the Vte::Pty is not accessible here (FIXME)
    sh = self.shell
    vty_env = ENV.map { |elt| "%s=%s" % elt }
    PebblApp::AppLog.info("Using shell #{sh.inspect}")
    # it = self.vty.spawn_async(Vte::PtyFlags::DEFAULT, Dir.pwd,
    #                           sh, vty_env, GLib::Spawn::SEARCH_PATH, -1)
    ## ^ can add an additional arg of type Gio::Cancellable
    ## ^ returns a Vte::Terminal, the same value as self.vty here
    ## ^ should accept a block, translated to a setup function for the
    ##   subprocess pre-exec environment
    ## ^ should return the PID, returning in the parent process

    # PebblApp::AppLog.debug("Using vty: #{self.vty.inspect}")

    ## before starting any shell ... binding a signal on pty activation
    self.vty.signal_connect_after("notify::pty") do |obj, prop|
      ## OBJ should be the Vte::Terminal for this app window
      ## FIXME move to a pty adapter

      ## update the subprocess_pty for this app window
      was_pty = self.subprocess_pty
      self.subprocess_pty = obj.pty
      PebblApp::AppLog.debug(
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
      PebblApp::AppLog.debug("Commit: #{text.inspect}")
    end if $DEBUG

    ## TBD move this to a ManagedPty adapter
    success, pid  = self.vty.spawn_sync(Vte::PtyFlags::DEFAULT, Dir.pwd,
                                        sh, vty_env, GLib::Spawn::SEARCH_PATH)

    if success
      PebblApp::AppLog.debug("Initializing process #{pid} for #{self}")
      sh_shortname = File.basename(self.shell.first)
      self.title = sh_shortname
      self.vtwin_header.title = sh_shortname
      self.subprocess_pid = pid
      self.vtwin_header.subtitle = Const::RUNNING
    else
      self.vtwin_header.subtitle = Const::FAILED
      ## FIXME needs a more graceful handler
      PebblApp::AppLog.debug("Failed. closing window")
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

  def vtwin_close(obj)
    ## signal handler on vtwin_close_entry, a menu entry
    self.close
  end

  def vtwin_quit(obj)
    vtwin_close(obj)
    self.application.quit
  end

  def vty_eof(obj)
    ## TBD UI (submenu) for sending invidual signals to the subprocess,
    ## using portable signal names onto some standard naming scheme
    self.vty.feed_child(PebblApp::Shell::Const::EOF)
  end

  def vty_reset(obj)
    self.vty.reset(false, false)
  end

  ## present an application preferences window, creating a new
  ## preferences window if not already initialized for the VtyApp
  def vtwin_show_prefs(obj)
    app = self.application
    app.ensure_prefs_window(app.active_window || self).present
  end

  def vtwin_show_about(obj)
    ## needs another UI definition, and a project concept
  end

  def vtwin_new(obj)
    win = self.class.new(self.application)
    win.show
  end

  def vtwin_save_data(obj)
    ## TBD conf options - output recording (for pty/pipe out, needs threads)
    ## self.class.save_vte_data(...)
  end

  def vtwin_save_text(obj)
    ## TBD filtering escape sequences out of the the output history text
    ## such that vtwin_save_data would use - see also, Pastel (??)
    ##
    ## TBD PTY output buffering with Vte
    ## - would Vte::Terminal#text access only the visible region of text?
    ##
    ## TBD using other forms of I/O in lieu of a shell pty
    ## - interaction buffers as a widget concept, not in many ways like Emacs
    ## - Gtk Stack switching & the UI
  end

  def vtwin_send
    ## FIXME further requirements for this method
    ## - input history recording, on activation with the #vty_send button
    ## - input history browsing, to be available in the #vty_entry widget
    ## - ensure this is extensible for an AltVtyAppWindow in which all
    ##   input to the subprocess would be mapped through a pipe
    ##   coordinated via a pre-spawn setup function for a process
    ##   wrapper for the actual command.
    ##   - the actual command would be initialized on a pty
    ##   - the process wrapper would use at least three pipes
    ##     for bridged communication beween the AltPty GUI
    ##     and the main process
    ##   - I/O could still be mapped directly to the PTY spawned by the
    ##     process wrapper
    ##   - this could be ported easily enough for any application
    ##     that would need only the pipe i/o under a piped process
    ##     wrapper, no pty (TBD as to how to update the Vte::Terminal
    ##     GUI with such a hack)
    ##

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
    PebblApp::AppLog.debug("Sending text: #{text.inspect}")
    if vty.respond_to?(:feed_child_raw)
      # PebblApp::AppLog.debug("using feed_child_raw")
      vty.feed_child_raw(text)
    else
      ## patch
      # PebblApp::AppLog.debug("using feed_child")
      vty.feed_child(text)
    end
  end

  def vtwin_received_eof(vty)
    ## prepare before subprocess exit (??)
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


##
## VtyApp
##
class VtyApp < PebblApp::GtkApp # is-a Gtk::Application

  include PebblApp::ActionableMixin


  FEATURE_FLAGS = Vte::FeatureFlags.constants.dup.tap { |flags|
    flags.delete(:FLAGS_MASK) }.select { |name|
    (Vte::FeatureFlags.const_get(name) & Vte::feature_flags).eql?(0) }

  class << self
    ## singleton accessor
    def app
     if class_variable_defined?(:@app)
       @@app
     else
       false
     end
    end
  end ## class << VtyApp

  def to_s()
    "#<%s %s (%s) 0x%06x>" % [
      self.class, application_id,
      (registered? ? "registered".freeze : "not registered".freeze),
      __id__
    ]
  end

  ## ad hoc place holders for app conf @ shell
  def shell=(cmd)
    ## TBD this may not return the actual tokenized cmd ?
    @shell = (String === cmd) ? Shellwords.split(cmd) : cmd
  end
  def shell
    ## TBD - should be implemented as a configurable property
    ## of the app and/or window
    ## TBD @ setting shell here
    if instance_variable_defined?(:@shell)
      return @shell
    elsif (option = self.config.option(:shell))
      self.shell = option
      self.shell ## return the tokenized value
    else
      self.shell = Vte.user_shell
      self.shell ## return the tokenized value
    end
  end

  def register()
    ## may not be reached in the underlying API when this method is
    ## overridden, unless this method is called directly from this
    ## class or a subclass
    PebblApp::AppLog.debug("Registering #{self}")
    super()
  end

  ## TBD accessor for the 'active-window' property on Gtk::Application
  ## : does it return a Gdk X11 Window?

  def initialize()
    ## the first arg for the Gtk::Application constructor is required,
    ## and requires a specific syntax e.g
    super("space.thinkum.vtytest",
          Gio::ApplicationFlags::SEND_ENVIRONMENT |
            Gio::ApplicationFlags::NON_UNIQUE,
          ## additional args passed to the local superclass
          app_name: "vty".freeze,
          app_env_name: "VTY".freeze)

    ## TBD managing multiple app instances in or outside of a single
    ## process, and side effects w/ dbus - alternately, connecting
    ## to some existing app instance, if already initialized

    if ! self.class.class_variable_defined?(:@@app)
      self.class.class_variable_set(:@@app, self)
    end

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

    self.signal_connect_after("window-removed") do |obj|
      if self.windows.empty?
        self.quit
      end
    end
  end

  ## handler for the app's 'startup' signal,
  def handle_startup()
    map_simple_action("app.quit") do |obj|
      self.quit
    end
  end

  ## handler for the app 'activate' signal
  def handle_activate()
      PebblApp::AppLog.debug("Handling activate for #{self.class}: #{self}")
      window = create_app_window
      add_window(window)
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
    ## FIXME generalize this beyond the single application,
    ## FIXME implement similar for an 'about' window,
    ## - using information from the containing gemspec
    ##   formatted for presentation in fields of the 'about' dialogue
    ##   - spec.description => about comments
    ##   - spec.licenses => about license
    ##   - ... copyright
    ##   - ... authors
    ## - this much would not require an application-specific UI design
    if ! (wdw = self.prefs_window)
      wdw = VtyPrefsWindow.new(transient_for: transient_for)
      wdw.signal_connect_after("destroy") do |obj|
        self.prefs_window = nil
      end
      self.prefs_window = wdw
      add_window(wdw) if !transient_for
    end
    return wdw
  end

  ## create a new application window
  def create_app_window()
    ## initialize and configure a main window for this application
    wdw = VtyAppWindow.new(self)
    wdw.shell = self.shell ## TBD @ profiles, config, modular design ...

    return wdw
  end


  def quit()
    super()
    self.windows.each do |wdw|
      PebblApp::AppLog.debug("Closing #{wdw}")
      wdw.close
    end
    if @gmain.running
      @gmain.running = false
    end
    ## super() would not necessarily be needed here.
    ## this is not using a Gtk Main loop
    # super()
  end

  ## return the VtyConf instance for this application
  ##
  ## this object provides some general support for defining and parsing
  ## command line options
  def config
    @config ||= VtyConf.new()
  end

  ## see GtkApp#main, GtkMain#map_sources

end
