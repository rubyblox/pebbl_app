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

#require 'pebbl_app/gtk_app_mixin'
require 'pebbl_app/gtk_app'

## FIXME integrate with GtkApp
# framework = PebblApp::GtkFramework.new(timeout: 10)
# begin
#   framework.init
# rescue PebblApp::FrameworkErrror => e
#   this = File.basename($0)
#   STDERR.puts "[DEBUG] #{this}: Failed in Gtk.init"
#   STDERR.puts e.full_message
#   ## FIXME could initialize either pry or irb here, if found
#   begin
#     irb = Gem::Specification.find_by_name("irb")
#   rescue
#     STDERR.puts "irb not found"
#     exit(-1)
#   end
#   ## drop into irb and disable $DEBUG
#   ## - Some $DEBUG output may interfere with tty i/o under IRB
#   irb.activate
#   $DEBUG = false
#   $INIT_ERROR = e
#   require %q(bundler/setup)
#   require %q(irb)
#   require %q(irb/completion)
#   STDERR.puts "[DEBUG] #{this}: Gtk::InitError stored as $INIT_ERROR"
#   IRB.start(__FILE__)
# end

require 'vte3'
require 'shellwords'

## prototyping a popover + sourceview for extended input editing
#require 'gtksourceview3'
## ^ DNW with glade, API needs refactoring @ Gtk::Source::View

## StringIO used for portably computing a default newline
require 'stringio'

module Const
  UNKNOWN = "(unknown)".freeze
  EOF = "\u0004".freeze
  ## subtitle strings for pty state (TBD gettext)
  RUNNING = "running"
  FAILED = "failed"
  EXITED = "exited"
end

module Util
  ## FIXME marge the Service/ServiceContext/... definition to here
  class << self
    ## utility for e.g cancellable process spawn methods on Vte::Terminal, Vte::Pty
    ## (prototype - no way to retrieve a PID with the async spawn methods here)
    ##
    ## FIXME test with Service/ServiceContext dispatch @ app level
    def init_cancellable(&block)
      cbl = Gio::Cancellable.new
      cbl.signal_connect("cancelled") do |cancellable|
        block.yield(cancellable)
      end
      return cbl
    end
  end
end


## Prototype for GLib type extension support in PebblApp
##
## @fixme redundant to PebblApp::GtkFramework::GObjType
module GObjectExtension

  def self.extended(whence)
    whence.include PebblApp::AppLoggerMixin ## instance methods for logging

    class << whence

      ## return true if a composite_builder has been initialized for
      ## this class, else return false
      ##
      ## @return [boolean]
      def composite_builder?
        class_variable_defined?(:@@builder)
      end

      ## return a Gtk::Builder for UI definition in a class scope.
      ##
      ## It may not be recommended to reuse this Gtk::Builder
      ## for UI definitions local to an instance scope.
      ##
      ## If no composite_builder has been bound, this method will
      ## initialize a new composite_builder as `Gtk::Builder.new`,
      ## then storing the new instance before return.
      ##
      ## @return [Gtk::Builder] the composite_builder
      ## @see composite_builder=
      ## @see composite_builder?
      def composite_builder
        if composite_builder?
          @@builder
        else
          @@builder = Gtk::Builder.new
        end
      end ## composite_builder

      ## set a composite_builder for this class, if not already bound
      ##
      ## If already bound, a warning will be emitted with Kernel.warn.
      ## The original builder will be returned, unmodified.
      ##
      ## @param builder [Gtk::Builder] the builder to bind for this
      ##  composite widget class, if not already bound
      ##
      ## @return [Gtk::Builder] the bound builder
      def composite_builder=(builder)
        if composite_builder? && (@@builder != builder)
          Kernel.warn("Ignoring duplicate builder for #{self}: #{builder}",
                      uplevel: 1)
          @@builder
        else
          @@builder = Gtk::Builder.new
        end
      end ## composite_builder

      ## register the class, at most once
      def register_type
        if class_variable_defined?(:@@registered)
          @@registered
        else
          ## FIXME does not detect duplcate registrations
          ## of differing implmentation classes
          ##
          ## TBD detecting errors in the Gtk framework layer,
          ## during type_register -> should be handled as error here
          type_register
          @@registered = self
        end
      end ## register_type
    end ## class << whence
  end ## self.extended
end

class UIError < RuntimeError
end

## Base module for template support in this prototype
module CompositeWidget
  def self.extended(whence)
    whence.extend GObjectExtension
    class << whence

      ## bind signal handlers to instance methods in this class
      ##
      ## The connect func defined internal to this method will bind
      ## instance methods as signal handlers.
      ##
      ## If a signal name is provided to the connect func, such that the
      ## signal name does not match any instance method in the composite
      ## class, the connect func will raise a UIError, avoiding any
      ## further processing.
      ##
      ## When applied together with a UI widget template in a composite
      ## class definition, this method should be able to capture any
      ## mismatch between signal handler names defined in the template UI
      ## file and methods defined in the implementation of the template's
      ## composite class.
      ##
      ## On success, this method will ensure that each signal handler is
      ## bound to an instance method defined in the composite class.
      ##
      ## @see Gtk::Widget.set_connect_func
      ## @see the Glade User Interface Designer
      def set_composite_connect_func()
        ## This generally emulates a call to the
        ## Gtk::Widget.set_connect_func method as to bind a method to
        ## each signal handler.
        ##
        ## The following definition provides a preliminary check, to test
        ## for an instance method in the composite class, as corresponding
        ## to each signal handler name.
        ##
        ## This generally corresponds to the API usage after example 7
        ## and subsequent in the sample tutorial: Getting started with
        ## GTK+ with the ruby-gnome2 Gtk3 module
        ## https://github.com/ruby-gnome/ruby-gnome/tree/master/gtk3/sample/tutorial
        ##
        ## Not directly documented, this corresponds to a convention of
        ## configuring a signal handler as a method name, typically
        ## with a UI template child object selected as the user data
        ## object, using a composite widget's UI definition in Glade.
        ##
        ## In Glade, the signal handlers for a widget may be configured
        ## under the "Signals" tab in the widget's configuration data.
        ##
        ## The actual syntax for each named method may vary by the
        ## nature of the signal to which the method is mapped as a
        ## signal handler. Documentation about each signal handler is
        ## available in GNOME Devhelp, and may be accessed via the Glade
        ## UI designer.
        ##
        ## FIXME this needs normal documentation, external to the source
        ## comments here.
        ##
        set_connect_func_raw do |builder, object, signal_name,
                                 handler_name, connect_object, flags|
          hdlr_sym = handler_name.to_sym
          if self.instance_methods.include?(hdlr_sym)
            Gtk::Builder.connect_signal(builder, object, signal_name,
                                        handler_name, connect_object,
                                        flags) do |name|
              method name
            end
          else
            raise UIError.new(
              "No method %s found for signal %p in %p" % [
                handler_name, signal_name, cls
              ])
          end
        end
        return self
      end

      ## a common method for template initialization in composite widget
      ## classes
      ##
      ## @param children [Array<String>] template children in this
      ##  composite class' template definition.
      ##
      ##  Each string in this array should match the id of a widget in
      ##  the class' template definition. For each id provided, an
      ##  instance method of the same name will be defined in the
      ##  composite class, as returning the widget for that ID in the
      ##  corresponding instance of the composite class.
      ##
      ## @param path [String] for debugging  purposes, the filename or
      ##  resource path of the template
      ##
      ## @see FileCompositeWidget, which provides a use_template method
      ##  that will be defined in any extending class. That use_template
      ##  method will dispatch to initialize_template_children after
      ##  setting the template definition for the extending class.
      ##
      def initialize_template_children(children, path: Const::UNKNOWN,
                                       builder: self.composite_builder)
        children.each do |id|
          PebblApp::AppLog.debug("Binding template child #{id} for #{self}")

          ## an alternate approach after bind_template_child(id)
          ## 1) bind the template child as an internal template child
          ## 2) define a method here that will check to ensure that
          ##    a template child object is found for each id, when
          ##    called, rather than quietly returning nil.

          ## about the second arg in the following call:
          ## >> if 'true' => internal, no method is defined for each
          ## >> if 'false' => a method is defined for each, albeit
          ##    such that the method may quietly return nil
          bind_template_child_full(id, true, 0)

          ## define the accessor method here, with added checks
          lmb = lambda {
            if (obj = get_internal_child(builder, id))
              return obj
            else
              raise UIError.new("No template child found for id #{id} \
in template for #{self.class} at #{path}")
            end
          }
          define_method(id, &lmb)
        end

        ## bind signal handlers for this class, conditinally
        ##
        ## This will err within the class' connect func e.g if a signal
        ## handler is defined in the UI file without a corresponding
        ## method in this class.
        ##
        ## The block defined in set_composite_connect_func may be
        ## evaluated during UI initialization
        set_composite_connect_func()

        return true

      end
    end ## class <<
  end ## self.extended
end

## prototype module for classes using a template definition with
## GTK Builder, when the template is initialized directly from a
## UI file source
##
## FIXME should be accompanied with a module for classes deriving a Gtk
## Builder template definition from a UI resource path onto an
## initiailzed GResource bundle
##
module FileCompositeWidget
  def self.extended(whence)
    whence.extend CompositeWidget

    ## initialize a file-based template for this class, using the class
    ## constant TEMPLATE to determine the template file's pathname
    def use_template(filename, children = false)
      register_type
      if File.exists?(filename)
        ## NB Gio::File @ gem gio2 lib/gio2/file.rb
        ## File, GFileInputStream topics under GNOME devhelp
        gfile = false
        fio = false
        path = File.expand_path(filename)
        begin
          gfile = Gio::File.open(path: path)
          fio = gfile.read
          nbytes = File.size(filename)
          bytes = fio.read_bytes(nbytes)
          PebblApp::AppLog.debug("Setting template data for #{self} @ #{filename}")
          self.set_template(data: bytes)
        ensure
          fio.unref() if fio
          gfile.unref() if gfile
        end
      else
        raise "Template file does not exist: #{filename}"
      end
      if children
        bld = (self.composite_builder ||= Gtk::Builder.new)
        self.initialize_template_children(children, path: path, builder: bld)
      end
      return path
    end ## whence.use_template
  end
end


## configuration support for VtyApp
##
## an instance of this class is returned from VtyApp#conf
class VtyConf < PebblApp::GtkConf

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
  ## FIXME set the template file path relative to some external base directory
  use_template(File.expand_path("../ui/prefs.vtytest.ui", __dir__),
                 %w(shell_cmd_entry io_model_combo prefs_stack prefs_sb
                   ))

  ## FIXME integrate with the Conf API

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
    debug("cancel @ #{obj} => #{self}")
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

  ## FIXME args parsing, app conf, app packaging, ...

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
    PebblApp::AppLog.debug("Initializing #{self}")
    super(application: app)
    ##
    ## local conf
    ##

    # prefixes = self.action_prefixes
    # debug("Action prefixes (#{prefixes.length})")
    # prefixes.each do |pfx|
    #   ## >> win, app
    #   debug pfx
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
    debug("Using shell #{sh.inspect}")
    # it = self.vty.spawn_async(Vte::PtyFlags::DEFAULT, Dir.pwd,
    #                           sh, vty_env, GLib::Spawn::SEARCH_PATH, -1)
    ## ^ can add an additional arg of type Gio::Cancellable
    ##   - FIXME no other callbacks here
    ## ^ returns a Vte::Terminal, the same value as self.vty here
    ## ^ should accept a block, translated to a setup function for the
    ##   subprocess pre-exec environment
    ## ^ should return the PID, returning in the parent process

    #debug("Using vty: #{self.vty.inspect}")

    ## before starting any shell ... binding a signal on pty activation
    self.vty.signal_connect_after("notify::pty") do |obj, prop|
      ## OBJ should be the Vte::Terminal for this app window
      ## FIXME move to a pty adapter

      ## update the subprocess_pty for this app window
      was_pty = self.subprocess_pty
      self.subprocess_pty = obj.pty
      debug(
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
      debug("Commit: #{text.inspect}")
    end

    ## TBD move this to a ManagedPty adapter
    success, pid  = self.vty.spawn_sync(Vte::PtyFlags::DEFAULT, Dir.pwd,
                                        sh, vty_env, GLib::Spawn::SEARCH_PATH)

    if success
      debug("Initializing #{pid} for #{self}")
      sh_shortname = File.basename(self.shell.first)
      self.title = sh_shortname
      self.vtwin_header.title = sh_shortname
      self.subprocess_pid = pid
      self.vtwin_header.subtitle = Const::RUNNING
    else
      self.vtwin_header.subtitle = Const::FAILED
      ## FIXME needs a more graceful handler
      debug("Failed. closing window")
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
    ## TBD UI (submenu) for sending invidual signals to the subprocess,
    ## using portable signal names onto some standard naming scheme
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
    ## TBD conf options - output recording (for pty/pipe out, needs threads)
    ## self.class.save_vte_data(...)
  end

  def vtwin_save_text
    ## TBD filtering escape sequences out of the the output history text
    ## such that vtwin_save_data would use
    ##
    ## Vte::Terminal#text would access only the visible region of text?
    ##
    ## self.class.save_vte_text(...)
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
    debug("Sending text: #{text.inspect}")
    if vty.respond_to?(:feed_child_raw)
      # debug("using feed_child_raw")
      vty.feed_child_raw(text)
    else
      ## patch
      # debug("using feed_child")
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
class VtyApp < Gtk::Application
  include PebblApp::AppMixin

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

    debug("Binding action #{prefix}.#{name} for #{self}")

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
    debug("Registering #{self.inspect}")
    super()
  end

  ## TBD accessor for the 'active-window' property on Gtk::Application
  ## : does it return a Gdk X11 Window?

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
    ## bind C-q to an 'app.quit' action,
    ## also defining a handler for that action
    self.map_simple_action("app.quit", accel: "<Ctrl>Q") do
      self.quit
    end
  end

  ## handler for the app 'activate' signal
  def handle_activate()
      debug("Handling activate for #{self.class}: #{self.inspect}")
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
    self.windows.each do |wdw|
      wdw.close
    end
    debug("Calling Gtk.main_quit in Thread 0x%06x" % [Thread.current.__id__])
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

  def main(argv: ARGV)
    PebblApp::AppLog.app_log ||= PebblApp::AppLog.new
    configure(argv: argv)

    timeout = self.conf.gtk_init_timeout
    framework = PebblApp::GtkFramework.new(timeout: timeout)

    app_args = self.conf.gtk_args.dup
    open_args = framework.init(argv: app_args)

    info("Activate")
    register() ## at most once (FIXME)
    if open_args.empty?
      activate()
    else
      open(open_args, "".freeze)
    end
    Gtk.main
  end

end
