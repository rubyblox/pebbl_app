# riview_ui.rb

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually,
  ## such that the module will define autoloads used in this file
  require(__dir__ + ".rb")

  ## TBD
  if (defined?(IRB.conf) && ! IRB.conf.empty?)
    ## Development Environment
    # require 'ProjectKit' ## FIXME not yet installed as a gem
    ## ^ NB maint under rbdevtools:/projectkit
    ## defining ProjectKit::SpecTool
    ## ... which presently defines fork_in (FIXME)
    ##
    ## NB see also
    ## rbproject:/iokit, defining IOKit::OutProc
  end
}

## test:
##  app = RIViewApp.new; app.run_threaded


module RIView

class TreeBuilder
  attr_reader :store, :iterator

  def initialize(store, iterator = store.append(nil))
    @store = store
    @iterator = iterator
  end

  def add_branch(*data, iterator: self.iterator)
    iterator.set_values(data)
    return iterator
  end

  def add_leaf(*data, iterator: self.iterator)
    #iterator.set_values(data)
    store.append(iterator).set_values(data)
    return iterator
  end
end

class AppWindow < Gtk::ApplicationWindow

  extend(GAppKit::LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  extend(GAppKit::FileTemplateBuilder)
  self.use_template(File.join(RESOURCE_ROOT, "ui/appwindow.glade"))

  def set_window_action(name, &block)
    application.log_debug("Adding action '#{name}' in #{self} (#{Thread.current})")
    act = Gio::SimpleAction.new(name)
    act.signal_connect("activate", &block)
    if @win_actions
      @win_actions[name] = act
    else
      @win_actions = { name => act }
    end
    self.add_action(act)
    return act
  end

  def self.finalizer_proc(unrefs)
    proc {
      unrefs.each { |obj|
        obj.unref if obj.respond_to?(:unref)
      }
    }
  end

  self.bind_ui_internal("RIPageView") ## NB x RIDocView
  self.bind_ui_internal("RITreeStore") ## TBD

  ## @param application [GBuilderApp]
  def initialize(application)
    super(application: application)

    @logger = application.logger

    ## NB init_template will be called under Gtk::Widget#initialize_post

    set_window_action("new") {
      @logger.debug("Action 'new' in #{self} (#{Thread.current})")
      application.map_app_window_new
    }
    set_window_action("prefs") {
      @logger.debug("Action 'prefs' in #{self} (#{Thread.current})")
      application.map_prefs_window
    }
    closeAct = set_window_action("close") {
      @logger.debug("Action 'close' in #{self} (#{Thread.current})")
      application.remove_window(self)
      self.unmap
      self.destroy
      application.quit if application.windows.length.zero?
    }
    set_window_action("quit") {
      @logger.debug("Action 'quit' in #{self} (#{Thread.current})")
      closeAct.activate
      application.quit
    }

    self.signal_connect("destroy") {
      @logger.debug("Signal 'destroy' in #{self} (#{Thread.current})")
      closeAct.activate
    }

    name = self.class.name ## NB during development
    self.name=name
    self.set_title(name)

    ## NB ~/.local/share/gem/ruby/3.0.0/gems/gtk3-3.4.9/sample/misc/treestore.rb

    store = ui_internal("RITreeStore")
    #itertop = store.append(nil)

    builder = TreeBuilder.new(store)

    systore = application.system_store
    sysproxy = DataProxy.new(systore)
    sitestore = application.site_store
    siteproxy = DataProxy.new(sitestore)
    homestore = application.home_store
    homeproxy = DataProxy.new(homestore)
    gemstores = application.gem_stores
    ## FIXME one data proxy per each gem store, indexed under a local
    ## hash table with same keys as in gem_stores

    ## NB using the initial store.append(nil) iterator for the first
    ## root tree model entry, as a branch
    builder.add_branch(true, "System", "Store", nil, sysproxy)
    itersys = store.append(builder.iterator)
    ## NB RI has Abbrev.abbrev documented as both a class method and an
    ## instance method (defined under a module, in each and both)
    ##
    ## - Ruby does not show it under Abbrev.instance_methods()
    ##   but does show it under Abbrev.singleton_methods()
    ##
    builder.add_branch(true, "Abbrev", "Module", "Abbrev", sysproxy,
                       iterator: itersys)
    builder.add_leaf(true, "abbrev", "Class Method", "Abbrev::abbrev", sysproxy,
                     iterator: itersys)
    builder.add_leaf(true, "abbrev", "Instance Method", "Abbrev#abbrev", sysproxy,
                     iterator: itersys)

    builder.add_leaf(true, "A", "B", "A", sysproxy)
    builder.add_leaf(true, "C", "B", "C", sysproxy)

    iternext = store.append(builder.iterator)
    builder.add_branch(true,"CGI", "Module", "CGI", iterator: iternext)
    builder.add_leaf(true,"Escape","Module", "CGI::Escape",
                     ## FIXME need to test activation handling
                     ## + value retrieval here
                     DataProxy.new("miscdata"),
                    iterator: iternext)

    iternext = store.append(builder.iterator)
    builder.add_branch(true, "D", "C", "D", sysproxy,
                       iterator: iternext)
    builder.add_leaf(true, "E", "C", "D::E", sysproxy,
                     iterator: iternext)

    # itersite = store.append(nil)
    ## NB typically an empty RI store
    builder.add_leaf(true, "Site", "RI Store", iterator: nil)

    # iterhome = store.append(nil)
    ## NB typically an empty RI store
    builder.add_leaf(true, "Home", "RI Store", iterator: nil)

    itergems = store.append(nil)
    builder.add_branch(true, "Gems", "RI Store", iterator: itergems)
    builder.add_leaf(true, "B", "Test", iterator: itergems)



    @topic_store = store

    @pageview = ui_internal("RIPageView")

    ObjectSpace.define_finalizer(self, self.class.finalizer_proc(
      @win_actions.values
    ))

    ## NB @ ActionMap, SimpleActionMap API in Ruby GTK support
    ## ~/.local/share/gem/ruby/3.0.0/gems/gio2-3.4.9/test/test-action-map.rb
    ##
    ## NB defined as modules:
    ## ~/.local/share/gem/ruby/3.0.0/gems/gio2-3.4.9/lib/gio2/action.rb
    ## ~/.local/share/gem/ruby/3.0.0/gems/gio2-3.4.9/lib/gio2/action-map.rb
    ##
    ## FIXME no Ruby impl for GIO's GPropertyAction - needs impl or similar
  end

  def unmap()
    @logger.debug("#{__method__} #{self} (#{Thread.current})")
    super
  end

  def destroy()
    @logger.debug("#{__method__} #{self} (#{Thread.current})")
    super
  end
end



class RIDocView < Gtk::TextView
  extend(GAppKit::FileTemplateBuilder)
  ## FIXME only one template-based class per UI file...?
  self.use_template(File.join(RESOURCE_ROOT,"ui/docview.ui"))

  self.bind_ui_internal("DocTextView")

  attr_reader :buffer

  def initialize(application)
    self.class.builder ||= application.class.builder
    view = ui_internal("DocTextView")
    @buffer = Gtk::TextBuffer.new()
    view.buffer = buffer
  end

=begin e.g
aw = AppWindow.new
notebook = aw.ui_internal("RIPageView")
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


class PrefsWindow < Gtk::Dialog
  extend(GAppKit::LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  ## TBD GLib::Log usage in e.g
  ## ~/.local/share/gem/ruby/3.0.0/gems/glib2-3.4.9/lib/glib2.rb

  extend(GAppKit::FileTemplateBuilder)
  self.use_template(File.join(RESOURCE_ROOT, "ui/prefs.ui"))

  ## ensure that some objects from the template will be accessible
  ## within each instance
  self.bind_ui_internal("SystemStorePath")
  self.bind_ui_internal("SiteStorePath")
  self.bind_ui_internal("HomeStorePath")
  self.bind_ui_internal("GemPathsListStore")

  # def self.string_gvalue(str)
  ## utility method, presently unused
  #   GLib::Value.new(GLib::Type["gchararray"],str)
  # end

  def initialize(application)
    self.class.builder ||= application.class.builder
    @application = application
    @logger = application.logger
    super()

    entry = ui_internal("SystemStorePath")
    entry.set_text(application.system_store.path)
    entry = ui_internal("SiteStorePath")
    entry.set_text(application.site_store.path)
    entry = ui_internal("HomeStorePath")
    entry.set_text(application.home_store.path)

    store = ui_internal("GemPathsListStore") ## is a Gtk::ListStore
    application.gem_stores.each { |path, st|
      spec = st.gem_spec
      store.append.set_values([spec.name, spec.version.version, path,
                               spec.full_name])
    }

    ## FIXME initialize entries for the font prefs page,
    ## onto the Ruby API for GNOME Pango support
  end

  def destroy()
    ## NB GTK may be calling a destroy method internally
    @logger.debug("#{__method__} @ #{self} (#{Thread.current})")
    super
  end

  def close()
    @logger.debug("#{__method__} @ #{self} (#{Thread.current})")
    super
  end
end


class RIViewApp < GAppKit::GBuilderApp

  attr_reader :system_store, :site_store, :home_store, :gem_stores

  def initialize()
    super("space.thinkum.riview")
    ## FIXME set a filesystem base directory in the class
    self.signal_connect("startup") {
      ## forms to run subsq. of successful register()
      ##
      ## NB this will be activated by register() only once per process.
      self.map_app_window_new
    }
    @system_store=RIKit::StoreTool.system_storetool
    @site_store=RIKit::StoreTool.site_storetool
    @home_store=RIKit::StoreTool.home_storetool
    h = {}
    Gem::Specification::find_all { |s|
      ## FIXME not every gem can be initialized to a storetool
      ##
      ## FIXME this does not filter onto "latest version", but will
      ## instead operate across all installed gems w/ an avaialble RI
      ## documentation store
      begin
        gst = RIKit::StoreTool.gem_storetool(s)
        h[gst.path]=gst
      rescue RIKit::QueryError
        ## nop
      end
    }
    @gem_stores = h
    ## FIXME develop an internal database onto the environment's stores
    ## and populate the index treeview(s) for main app windows, from the same
  end

  def map_prefs_window()
    unless @prefs_window ## FIXME unset when destroyed
      w = PrefsWindow.new(self)
      @logger.debug("Using new prefs window #{w}")
      @prefs_window = w
    end
    #@prefs_window.activate ## TBD this or "show" (??)
    @logger.debug("Displaying prefs window #{w}")
    @prefs_window.map
    @prefs_window.show
  end

  def map_app_window_new()
    w = AppWindow.new(self)
    log_debug("Adding window #{w} in #{Thread.current}")
    self.add_window(w)
    log_debug("Presenting window #{w} in #{Thread.current}")
    w.present
  end
end


end ## RIView module

=begin debug

NB
~/.local/share/gem/ruby/3.0.0/gems/gobject-introspection-3.4.9/test/test-arg-info.rb

gir = GObjectIntrospection::Repository.default

#gir.require("GObject")

gir.require("Gtk")
#info = gir.find("GtkWidget","destroyed") ## FIXME fails. null typelib?

gir.select { |obj| if ( obj.class == GObjectIntrospection::FunctionInfo )
    obj.get_arg(0)
  end
}.length
=> 1672


# FIXME really problematic here - persistent segfault, needs full Q/A
gir.select { |obj| if ( obj.class == GObjectIntrospection::FunctionInfo )
    obj.get_arg(0).name
  end
}

... but what are the args that would be required by the Ruby API onto
gtk_widget_destroyed ??
- can it even be called from this API??
- or does it have simply an opaque interface here?

=end

## Local Variables:
## fill-column: 65
## End:
