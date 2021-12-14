# riview.rb

## test:
##  app = RIViewApp.new; app.run_threaded

require 'gtk3'

require('logger')
require('forwardable')

## Extension module for adding *log_*+ delegate methods as instance
## methods within an extending class.
##
## This module will define a class method +def_logger_delegate+. This
## class method may then be called within an extending class +c+,
## as to define a set of instance methods under +c+ that will dispatch
## to all of the local instance methods except +<<+ on +Logger+.
##
## Any of those delegating instance methods may be overridden, after the
## initial call to +def_logger_delegate+ in the extending class.
##
##
## @see LogManager, providing support for initialization of logger
##  storage within a class, and support for shadowing the *Kernel.warn*
##  method with s proc dispatching to an arbitrary *Logger*
##
module LoggerDelegate

  def self.extended(extclass)
    extclass.extend Forwardable

    ## FIXME needs documentation (params)
    ##
    ## TBD YARD rendering for define_method in this context,
    ## beside the methods defined when the method defined here would be
    ## evaluated in an extending class.
    ##
    ## The delegate methods would not appear in any source definition for
    ## the delegating class, outside of the usage of this module.
    ##
    ## NB application must ensure that the instance variable is
    ## initialized with a Logger before any delegate method is
    ## called - see example under GBuilderApp#initialize
    ##
    ##
    ## *Syntax*
    ##
    ## +def_logger_delegate(instvar,prefix=:log_)+
    ##
    ## The +prefix+ parameter for *def_logger_delegate* provides a
    ## prefix name for each of the delegate methods, such that each
    ## delegate method will dispatch to a matching method on the logger
    ## denoted in the instance variable named in +instvar+. +prefix+ may
    ## be provided as a string or a symbol.
    ##
    ## The +instvar+ param should be a symbol, denoting an instance
    ## variable that will be initialized to a logger in instances of the
    ## extending class.
    ##
    ## In applications, the instance logger may be provided in reusing a
    ## logger stored in the extending class, such that may be managed
    ## within a class extending the *LogManager+ module. Within
    ## instances of the extending class, the instance variable denoted
    ## to +def_logger_delegate+ may then be initialized to the value of
    ## the class logger, such as within an +initialize+ method defined
    ## in the extending class.
    ##
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


## Extension module providing internal storage for class-based logging
## and override of the method *Kernel.warn*
##
## This module defines the following class methods, in an extending
## class +c+:
##
## - *+c.logger=+*
## - *+c.logger+*
## - *+c.make_warning_proc+*
## - *+c.manage_warnings+*
##
## The +manage_warnings+ method will define a method overriding the
## default *Kernel.warn* method, such that a top level call to +warn+
## will call the overriding method.
##
## This will not remove the definition of the orignial *Kernel.warn*
## method, such that be called directly as *Kernel.warn*
##
## The method +make_warning_proc+ will provide the *Proc* object to use
## for the overriding +warn+ method, such that will be defined in
## +manage_warnings+. By default, +make_warning_proc+ will return a
## +Lambda+ proc with a parameter signature equivalent to the the
## original +Kernel.warn+ in Ruby 3.0.0.
##
## If +make_warning_proc+ is overriden in the extending class before
## +manage_warnings+ is called, then the overriding method will be used
## in +manage_warnings+
##
##
## For purposes of class-focused log management, the class methods
## +logger=+ and +logger+ may be used in the extending class, as to
## access a logger that would be stored within the class definition. The
## class logger may or may not be equivalent to the logger provided to
## +manage_warnings+
##
## The logger provided to +manage_warnings+ will not be stored
## internally. It's assumed that the logger provided to that method
## would be stored within some value in the extending class.
##
## @see *GBuilderApp*, providing an example of this module's application,
##      under instance-level integration with *LoggerDelegate*
##
## @see *LoggerDelegate*, providing instance methods via method
##      delegation, for logger access within application objects
##
## @see *Logger*, providing an API for arbitrary message logging in Ruby
##
module LogManager
  def self.extended(extclass)

    def extclass.logger=(logger)
      if @logger
        warn("@logger already bound to #{@logger} in #{self} " +
             "- ignoring #{logger}", uplevel: 0) unless @logger.eql?(logger)
        @logger
      else
        @logger = logger
      end
    end

    def extclass.logger
      @logger # || warn("No logger defined in class #{self}", uplevel: 0)
    end

    def extclass.make_warning_proc(logger)
      lambda { |*data, uplevel: 0, category: nil|
        ## NB unlike with the standard Kernel.warn method ...
        ## - this proc will use a default uplevel = 0, as to ensure that some
        ##   caller info will generally be presented in the warning message
        ## - this proc will accept any warning category
        ## - this proc's behaviors will not differ based on the warning category
        ## - this proc will ensure that #to_s will be called directly on
        ##   every provided message datum
        unless ($VERBOSE.nil?)

          nmsgs = data.length
          nomsg = nmsgs.zero?

          if category
            catpfx = '[' + category.to_s + '] '
          else
            catpfx = ''
          end

          if uplevel
            callerinfo = caller[uplevel]
            if nomsg
              firstmsg = catpfx + callerinfo
            else
              firstmsg = catpfx + callerinfo + ': '
            end
          else
            firstmsg = catpfx
          end

          unless nomsg
            firstmsg = firstmsg + data[0].to_s
          end

          logger.warn(firstmsg)

          unless( nomsg || nmsgs == 1 )
            data[1...nmsgs].each { |datum| logger.warn(catpfx + datum.to_s) }
          end
        end
        return nil
      }
    end

    def extclass.manage_warnings(kernlogger)
      if kernlogger.respond_to?(:warn)
        ## NB the logger used here may be inequivalent to self.logger
        ##
        ## This will not store the kernlogger for any later access.
        ##
        ## It's assumed that the logger object provided to this method
        ## would be stored in the extending class.
        ##
        proc = self.make_warning_proc(kernlogger)
        ## NB Kernel.method(:warn) should retrieve the same initial value,
        ## even after the following call to Kernel.define_method
        ##
        ## FIXME for purpose of documentation, that should be tested
        ## under an rspec definition for this module. Theoretically,
        ## that behavior may change under any future release of Ruby,
        ## and a different behavior may be implemented in any other Ruby
        ## implementation.
        ##
        ## For purposes of this module's application, albeit,
        ## that behavior does not denote a function requirement - i.e
        ## whether Kernel.method(:warn) will return the same value
        ## before and after manage_warnings is called, such that it
        ## would in Ruby 3.0.0
        ##
        Kernel.define_method(:warn, &proc)
        return proc
      else
        raise "object does not provide a #warn method: #{kernlogger}"
      end
    end
  end
end


require_relative('storetool.rb')
require_relative('spectool.rb')


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


## Extension module for any class defining a new subtype of
## GLib::Object (GObject)
##
## When used in a class definition +c+ via *+Module.extend+*, this module
## will define the following methods in the extending class +c+:
##
## - *+c.register+* calling +c.type_register+ exactly once for the
##   extending class
##
## - *+c.registered?+* returning a boolean value indicating whether
##   the class' type has already been registered to *GLib*.
##
## The *+type_register+* method is typically a class method provided
## under the class *+GLib::Object+* and its subclasses.
##
## When extending this method in a class definition, the class'
## *+register+* method should be called at some point within the class
## definition - whether in the extending class or in some subclass of
## the extending class.
##
## Example
##
##    class ExtObject < GLib::Object
##      extend GTypeExt
##      self.register
##      # ...
##    end
##
## This method is extended in the following extension modules, in which
## *self.register* will be called automatically when the module is
## extended in any extending class:
##
## - *ResourceTemplateBuilder*
## - *FileTemplateBuilder*
##
## It's assumed that this module will be extended from some direct or
## indirect subclass of *+GLib::Object+*
module GTypeExt
  def self.extended(extclass)
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


class DataProxy < GLib::Object # < GLib::Boxed
  extend GTypeExt
  self.register ## register the type, exactly once

  ## FIXME this does not create or use any data_changed property
  ## but should, or this is only suitable for read-only data access
  ## in a GTK application (FIXME not yet tested, as such)
  ##
  ## - what really is the syntax for GLib::Param::Object.new ??
  ##   - what meaning would any integer values have, in that call?
  ##   - what external method does it call? whether in GLib or in any C
  ##     code under Ruby GNOME?

  # install_property(GLib::Param::Object.new("data_changed","DataChanged","user data changed",???,???))

  attr_accessor :data
  def initialize(data)
    super()
    @data = data
  end
end


module UIBuilder
  def self.extended(extclass)
    def extclass.builder()
      @builder ||= Gtk::Builder.new()
    end

    def extclass.builder=(builder)
      if @builder && (@builder != builder)
        warn "in #{self}: :builder is already bound to #{@builder}. Ignoring builder #{builder}"
      else
        @builder = builder
      end
    end

    def extclass.add_ui_file(file)
      ## TBD usage for testing - presently unused here

      ## NB this assumes that the UI file
      ## does not contain any template decls.
      ##
      ## i.e each object initialized from the file
      ## will be initialized at most once
      ## for this class
      @builder.add_from_file(file)
    end

    def extclass.add_ui_resource(path)
      ## NB this assumes that the UI file
      ## does not contain any template decls.
      ##
      ## i.e each object initialized from the file
      ## will be initialized at most once
      ## for this class
      @builder.add_from_resource(path)
    end

    def extclass.ui_object(id)
      ## NB may return nil
      @builder.get_object(id)
    end
  end
end

## general-purpose mixin module for TemplateBuilder extension modules
##
## @see ResourceTemplateBuilder
## @see FileTemplateBuilder
module TemplateBuilder
  def self.extended(extclass)
    extclass.extend GTypeExt
    extclass.extend UIBuilder

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

    ## @see #ui_internal
    def extclass.bind_ui_internal(id)
      ## FIXME test for usage
      self.bind_template_child_full(id, true, 0)
    end

    ## NB this defines an instance method ui_internal in extclass
    extclass.define_method(:ui_internal) { |id|
        self.get_internal_child(self.class.builder, id)
    }

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

class TreeBuilder
  attr_reader :store, :iterator

  def initialize(store, iterator = store.append(nil))
    @store = store
    @iterator = iterator
  end

  def add_branch(*data, iterator: self.iterator, append_iterator: true)
    iterator.set_values(data)
    ## ??
    if append_iterator
      return store.append(iterator)
    else
      return iterator
    end
  end

  def add_leaf(*data, iterator: self.iterator)
    #iterator.set_values(data)
    store.append(iterator).set_values(data)
    return iterator
  end
end

class RIViewWindow < Gtk::ApplicationWindow

  extend(LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  extend FileTemplateBuilder
  self.use_template("ui/appwindow.glade")

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
      @logger.debug("Signal 'destory' in #{self} (#{Thread.current})")
      closeAct.activate
    }

    name = self.class.name ## NB during development
    self.name=name
    self.set_title(name)

    ## NB ~/.local/share/gem/ruby/3.0.0/gems/gtk3-3.4.9/sample/misc/treestore.rb

    store = ui_internal("RITreeStore")
    #itersys = store.append(nil)

    empty = "".freeze

    ## NB TreeBuilder tests
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

    ## FIXME though it's not the most succinct thing still, this should
    ## be reading for testing with iteration onto the site store -
    ## modules, classes, methods

    itersys = builder.add_branch(true, "System", "Store", nil, sysproxy)
    builder.add_branch(true, "Abbrev", "Module", "Abbrev", sysproxy,
                       iterator: itersys, append_iterator: false)
    builder.add_leaf(true, "abbrev", "Class Method", "Abbrev::abbrev", sysproxy, 
                     iterator: itersys)
    builder.add_leaf(true, "abbrev", "Instance Method", "Abbrev#abbrev", sysproxy, 
                     iterator: itersys)

    iternext = builder.add_leaf(true, "A", "B", "C", sysproxy)
    builder.add_leaf(true, "D", "E", "F", sysproxy, iterator: iternext)

    iternext = store.append(iternext)
    builder.add_branch(true, "G", "H", "I", sysproxy,
                       iterator: iternext, append_iterator: false)
    builder.add_leaf(true, "J", "K", "G::J", sysproxy, iterator: iternext)


    ## FIXME remove the 'exp' column from the tree store/model
    ##
    ## GTK handles the "folded state" internal to the UI,
    ## independent of the data model

    # itersys.set_values([true, "System", "RI Store"])
    # iternext = store.append(itersys)
    # iternext.set_values([true,"Abbrev", "Module", "Abbrev"])
    ## NB RI has Abbrev.abbrev documented as both a class method and an
    ## instance method (defined under a module, in each and both)
    ##
    ## - Ruby does not show it under Abbrev.instance_methods()
    ##   but does show it under Abbrev.singleton_methods()
    ##
    ## TreeTool.add_leaf(iterator, data) => iteratorRet == iterator
    # store.append(iternext).
    #   set_values([true,"abbrev","Class Method","Abbrev::abbrev"]) ## leaf node
    # store.append(iternext). ## TBD Namespace#method syntax here
    #   set_values([true,"abbrev","Instance Method","Abbrev#abbrev"]) ## leaf node

    ## NB this needs lookahead for modules w/ submodules, etc
    iternext = store.append(itersys)
    iternext.set_values([true,"CGI", "Module", "CGI"])
    ## FIXME store the providing StoreTool in the DataProxy instance -
    ## usin one DataProxy for each StoreTool
    store.append(iternext).set_values([true,"Escape","Module", "CGI::Escape",
                                       ## FIXME need to test activation
                                       ## handling + value retrieval here
                                      DataProxy.new("miscdata")])

    itersite = store.append(nil)
    itersite.set_values([true, "Site", "RI Store"]) ## NB typically an empty RI store
    #store.append(itersite).set_values([true,"C","D"])

    iterhome = store.append(nil)
    iterhome.set_values([true, "Home", "RI Store"]) ## NB typically an empty RI store
    #store.append(iterhome).set_values([true,"E","F"])
    #store.append(iterhome).set_values([true,"G","H"])

    itergems = store.append(nil)
    itergems.set_values([true, "Gems", "RI Store"])
    store.append(itergems).set_values([true, "B", "Test"])


    ## FIXME the following do not show up
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
  extend FileTemplateBuilder
  ## FIXME only one template-based class per UI file...?
  self.use_template("ui/docview.ui")

  self.bind_ui_internal("DocTextView")

  attr_reader :buffer

  def initialize(application)
    self.class.builder ||= application.class.builder
    view = ui_internal("DocTextView")
    @buffer = Gtk::TextBuffer.new()
    view.buffer = buffer
  end

=begin e.g
aw = RIViewWindow.new
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



class RIViewPrefsWindow < Gtk::Dialog
  extend(LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  ## TBD GLib::Log usage in e.g
  ## ~/.local/share/gem/ruby/3.0.0/gems/glib2-3.4.9/lib/glib2.rb

  extend FileTemplateBuilder
  self.use_template("ui/prefs.ui")

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
      store.append.set_values(0 => spec.name,
                              1 => spec.version.version,
                              2 => path,
                              3 => spec.full_name)
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


class GBuilderApp < Gtk::Application

  extend(LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  extend UIBuilder

  extend LogManager

  def initialize(name, logger: nil)
    # @state = :initialized

    ## NB @logger will be used for the LoggerDelegate extension,
    ## providing instance-level access to the app/class logger
    @logger = logger ? logger :
      Logger.new(STDERR, level: LOG_LEVEL_DEFAULT, progname: name)

    ## NB ensuring that the logger used to shadow Kernel.warn
    ## will have a progname == "kernel", otherwise with the same
    ## field values as the selected app/class logger
    ##
    ## NB using a shallow copy - reusing any objects provided in the
    ## logdev and formatter fields of the selected app logger
    self.class.logger ||= @logger
    if (@sys_logger.nil?)
      sl = @logger.dup
      sl.progname = "kernel"
      @sys_logger = sl
    end
    self.class.manage_warnings(@sys_logger)


    super(name)
    ## ensure that a local Gtk::Builder is initialized for this
    ## application, via a class attr.
    ##
    ## This buider may be used for some template access or generally for
    ## Glade UI access. The builder - as a class property - would be
    ## used with the following extension modules
    ## - UIBuilder
    ## - ResourceTemplateBuilder
    ## - FileTemplateBuilder
    ##
    ## see also:
    ## ResourceTemplateBuilder.use_resource_bundle
    ##
    ## [FIXME] move this to the documentation for this method
    ## and see how it's formatted in RIView, while using all these
    ## YARD tags around - needs more project tooling. see also pkgsrc
    self.class.builder ||= Gtk::Builder.new
    # self.signal_connect("shutdown") {
    #   # FIXME - ensure any local method will be called for app shutdown procedures
    # }
  end

  def run()
    @logger.debug("#{__method__} in #{Thread.current}")
    begin
      self.register()
    rescue Gio::IOError::Exists
      ## NB
      ## - there is no unregister method for Applications in GTK
      ## - this application has not been defined with a flag
      ##   G_APPLICATION_NON_UNIQUE, however that may be represented
      ##   in the Ruby API. If it was defined as such, TBD side effects
      @logger.fatal("Unable to register #{self}")
    else
      ## super(gtk_cmdline_args) # TBD
      @logger.debug("#{__method__} calling Gtk.main in #{Thread.current}")
      # @state = :run
      Gtk.main()
    end
    @logger.debug("#{__method__} returning in #{Thread.current}")
  end

  def run_threaded()
    @logger.debug("#{__method__} from #{Thread.current}")
    NamedThread.new("#{self.class.name} 0x#{self.__id__.to_s(16)}#run") {
      run()
    }
  end

  def quit()
    @logger.debug("#{__method__} in #{Thread.current}")
    # @state = :quit
    self.windows.each { |w|
      @logger.debug("#{__method__} destroying window #{w} in #{Thread.current}")
      w.unmap
      w.destroy
    }
    super()
    @logger.debug("Gtk.main_quit in #{Thread.current}")
    ## NB this may be redundant here:
    Gtk.main_quit()
  end

  def add_window(window)
    @logger.debug("Adding window #{window} to #{self} (#{Thread.current})")
    super
  end

  def remove_window(window)
    @logger.debug("Removing window #{window} from #{self} (#{Thread.current})")
    super
  end

end

class RIViewApp < GBuilderApp

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
    @system_store=StoreTool.system_storetool
    @site_store=StoreTool.site_storetool
    @home_store=StoreTool.home_storetool
    h = {}
    Gem::Specification::find_all { |s|
      ## FIXME not every gem can be initialized to a storetool
      ##
      ## FIXME this does not filter onto "latest version", but will
      ## instead operate across all installed gems w/ an avaialble RI
      ## documentation store
      begin
        gst = StoreTool.gem_storetool(s)
        h[gst.path]=gst
      rescue QueryError
        ## nop
      end
    }
    @gem_stores = h
    ## FIXME develop an internal database onto the environment's stores
    ## and populate the index treeview(s) for main app windows, from the same
  end

  def map_prefs_window()
    unless @prefs_window ## FIXME unset when destroyed
      w =  RIViewPrefsWindow.new(self)
      @logger.debug("Using new prefs window #{w}")
      @prefs_window = w
    end
    #@prefs_window.activate ## TBD this or "show" (??)
    @logger.debug("Displaying prefs window #{w}")
    @prefs_window.map
    @prefs_window.show
  end

  def map_app_window_new()
    w = RIViewWindow.new(self)
    log_debug("Adding window #{w} in #{Thread.current}")
    self.add_window(w)
    log_debug("Presenting window #{w} in #{Thread.current}")
    w.present
  end
end


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
