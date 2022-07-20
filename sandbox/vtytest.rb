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

require 'gtksourceview3'

## A Glade-compatible GtkSource::View class
class SourceView < GtkSource::View
  type_register
end

module Vty

  module Const

    ## Label for an unknown process state in the PTY of a Vty terminal
    UNKNOWN = "unknown".freeze

    ## Label for a running process state in the PTY of a Vty terminal
    RUNNING = "running".freeze

    ## Label for an error process state in the PTY of a Vty terminal
    FAILED = "failed".freeze

    ## Label for an exited process state in the PTY of a Vty terminal
    EXITED = "exited".freeze

    ## Default for a Vte option - charcters to parse as a part of a word,
    ## during word-focused text selection in the Vte Pty
    ##
    ## Devehlp specifies "ASCII" here but that may not have been updated
    ## since the further adoption of UTF-8 in Vte
    WORD_CHARS="-.:/$%@~&"
  end
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
               %w(vty vty_send sourcewin_send
                  vty_context_pop vty_context_menu
                  vty_entry vty_entry_buffer vty_entry_completion
                  editpop_popover editpop_textbuffer
                  editpop_tags
                  editpop_textview
                  vtwin_header
                  editpop_sourcewin editpop_sourceview sourcewin_header
                  editpop_close sourcewin_close
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
    elsif self.application
      self.shell = self.application.shell
    else
      ## app window was initialized with a null application field
      self.shell = [Vte.user_shell.dup.freeze].freeze
    end
  end

  ## utility for map_accel_path
  include PebblApp::AccelMixin

  ## PID of the subprocess, or nil
  attr_accessor :subprocess_pid
  ## convenience accessor
  attr_accessor :subprocess_pty
  ## IO on the pty or nil
  attr_accessor :pty_io

  ## convenience method
  attr_accessor :newline

  def initialize(app = Gio::Application.default)
    super(application: app)
    ## debug after the super call, to ensure the Gtk object is initialized
    PebblApp::AppLog.debug("Initializing #{self}")

    self.vtwin_header.subtitle = Vty::Const::UNKNOWN

    ##
    ## local conf
    ##

    ## FIXME make this a profile property
    vty.word_char_exceptions=Vty::Const::WORD_CHARS

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
      vtwin_save_text(action)
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
    ##
    ## coordination for input text entry, intermediate popopver,
    ## and the source view input dialog
    ##

    self.vty_entry.signal_connect("icon-press") do |obj|
      popover = self.editpop_popover
      if popover.visible?
        popover.hide
      else
        popover.show
      end
    end
    popover = self.editpop_popover
    @editpop_swap_text = true
    popover.signal_connect("hide") do |obj|
      if @editpop_swap_text
        self.vty_entry_buffer.text = self.editpop_textbuffer.text
      end
    end

    popover.signal_connect("show") do |obj|
      ## prevent GTK from focusing any menu buttons in the popover
      self.focus = editpop_textview
      if editpop_sourcewin.visible?
        ## conditionally set text from sourcewin if visible
        ## && hide the sourcewin
        editpop_textbuffer.text =
          editpop_sourceview.buffer.text if @editpop_swap_text
        editpop_sourcewin.hide
      else
        ## conditionally set text from the vty entry buffer
        editpop_textbuffer.text =
          vty_entry_buffer.text if @editpop_swap_text
      end
    end

    ##
    ## common features
    ##
    [editpop_popover, editpop_sourcewin].each do |obj|
      ## hide reusable elements instead of destroy
      ##
      ## In one effect, this prevents that all signals, actions, and key
      ## bindings for these dialog windows would have to be re-mapped on
      ## every 'show' event
      obj.signal_connect("delete-event") do |popover|
        popover.hide_on_delete
      end

      obj.signal_connect_after("focus") do |popover|
        @last_focused_input = popover
        false ## continue event propagation
      end

    end

    vty_entry.signal_connect_after("focus") do |entry|
      @last_focused_input = entry
      false ## continue event propagation
    end

    ##
    ## Common key mappings
    ##
    send_path_str = "<Vty>/Secondary Input/Send".freeze
    send_keys =%i(Return mod1)
    hide_path_str = "<Vty>/Secondary Input/Hide".freeze
    close_keys = PebblApp::Keysym::Key_Escape

    ## initialize and add each AccelGroup to the corresponding Window
    @vty_map_group = Gtk::AccelGroup.new
    add_accel_group(@vty_map_group)
    @editpop_map_group = Gtk::AccelGroup.new
    editpop_sourcewin.add_accel_group(@editpop_map_group)

    map_accel_path(:Return, "<Vty>/Input Buffer/Send",
                   group: @vty_map_group,
                   scope: self, receiver: vty_send)


    ## bind common accel paths, using each corresponding group,
    ## scope (window), and receiver (widget)
    [[self, @vty_map_group, vty_send, nil],
     [editpop_popover, @vty_map_group, nil, editpop_close],
     [editpop_sourcewin, @editpop_map_group, sourcewin_send, sourcewin_close]
    ].each do |scope, group, send_recv, close_recv|
      map_accel_path(send_keys, send_path_str,
                     scope: scope,
                     receiver: send_recv,
                     group: group) if send_recv
      map_accel_path(close_keys, hide_path_str,
                     scope: scope,
                     receiver: close_recv,
                     group: group,
                     locked: true) if close_recv
    end


    ## common action prefixes
    vtwin_prefix = "vtwin"
    sourcewin_prefix = "sourcewin"
    editpop_prefix = "editpop"
    ## common action names
    act_send = "send"
    act_detach = "detach"
    act_hide = "hide"
    act_cancel = "cancel"
    act_clear = "clear"
    ## local action and Gtk signal name :
    common_show = "show"


    ##
    ## Common send action
    ##
    if vty.respond_to?(:feed_child_raw)
      ## earlier versions of Ruby-GNOME vte
      feed_cb = proc {|text| vty.feed_child_raw(text) }
    else
      feed_cb = proc {|text| vty.feed_child(text) }
    end

    send_cb = proc { |_|
      popover = self.editpop_popover
      if popover.visible?
        popover.hide
      end
      text = vty_entry_buffer.text + self.newline
      PebblApp::AppLog.debug("Sending text: #{text.inspect}") if $DEBUG
      feed_cb.yield(text)
    }

    map_simple_action(act_send, prefix: vtwin_prefix,
                      receiver: self, &send_cb)

    ## stage input from the editpop_sourcewin buffer before send
    map_simple_action(act_send, prefix: sourcewin_prefix,
                      receiver: editpop_sourcewin) do |_|
      vty_entry_buffer.text = editpop_sourceview.buffer.text
      send_cb.yield
    end

    ##
    ## Common detach => show action binding
    ##
    sourcewin_cb = proc {
      editpop_sourcewin.show
    }
    map_simple_action(act_detach, prefix: editpop_prefix,
                      receiver: self, &sourcewin_cb)
    map_simple_action(act_detach, prefix: editpop_prefix,
                      receiver: editpop_popover, &sourcewin_cb)

    ##
    ## Scope-specific actions & signal bindings
    ##

    map_simple_action("eof", prefix: vtwin_prefix, receiver: self) do
      ## reusing the feed_cb from the vtwin.send/sourcewin.send actions
      feed_cb.yield(PebblApp::Shell::Const::EOF)
    end

    map_simple_action("reset", prefix: vtwin_prefix, receiver: self) do
      vty.reset(false, false)
    end

    map_simple_action(act_hide, prefix: editpop_prefix,
                      receiver: editpop_popover) do
      ## ^ FIXME rename the "to" arg => "scope" here
      editpop_popover.hide
    end

    map_simple_action(common_show, prefix: editpop_prefix,
                      receiver: self) do
       editpop_popover.show
    end

    editpop_sourcewin.signal_connect(common_show) do
      if editpop_popover.visible?
        ## this widget will not transfer text from the ibuf entry box
        editpop_sourceview.buffer.text =
          editpop_textbuffer.text if @editpop_swap_text
        editpop_popover.hide
      end
    end

    map_simple_action(act_cancel, prefix: sourcewin_prefix,
                      receiver: editpop_sourcewin) do
      editpop_sourcewin.hide
    end

    map_simple_action(act_clear, prefix: sourcewin_prefix,
                      receiver: editpop_sourcewin) do
      editpop_sourceview.buffer.text = ""
    end

    vtwin_header.signal_connect_after("notify::title") do |header|
      sourcewin_header.subtitle = header.title
    end


    ##
    ## context menu actions on vtwin_prefix
    ##

    ## ensure that the vtwin prefix is defined for the context menu
    ##
    ## Actions bound for this prefix group, in the previous code:
    ## - vtwin.reset
    ##
    grp = self.get_action_group(vtwin_prefix)
    vty_context_menu.insert_action_group(vtwin_prefix, grp)

    map_simple_action("select-all", prefix: vtwin_prefix,
                      receiver: vty_context_menu) do
      vty.select_all
    end

    map_simple_action("selection-clear", prefix: vtwin_prefix,
                      receiver: vty_context_menu) do
      vty.unselect_all
    end

    map_simple_action("copy-text", prefix: vtwin_prefix,
                      receiver: vty_context_menu) do
      vty.copy_clipboard_format(Vte::Format::TEXT)
    end

    map_simple_action("copy-html", prefix: vtwin_prefix,
                      receiver: vty_context_menu) do
      vty.copy_clipboard_format(Vte::Format::HTML)
    end

    map_simple_action("prefs", prefix: vtwin_prefix,
                      receiver: vty_context_menu) do
      vtwin_show_prefs(nil)
    end

    ## activation for the context menu
    vty.signal_connect_after("button-press-event") do |_, evt|
      if evt.button == 3
        vty_context_menu.popup_at_pointer(evt)
      end
    end


    ###
    ### shell launch / PTY init
    ###

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
      self.vtwin_header.subtitle = Vty::Const::RUNNING
    else
      self.vtwin_header.subtitle = Vty::Const::FAILED
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

  ## @private obsolete
  def vtwin_send(_)
    ##
    ## [see action definitions]
    raise RuntimeError.new("Obsolete method reached")
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
        self.subprocess_pid, Vty::Const::EXITED, status
      ]
    end
  end

end


##
## VtyApp
##
class VtyApp < PebblApp::GtkApp # is-a Gtk::Application

  include PebblApp::ActionableMixin

  extend PebblApp::GUserObject
  self.register_type

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
