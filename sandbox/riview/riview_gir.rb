# riview_gir.rb - obsolete prototype for riview using gir_ffi

require 'gir_ffi'

=begin PORTING NOTES

~~~~
irb main 004 > app = RIViewApp.new; app.run_threaded
~~~~
... no errors ... and nothing displayed


=end


class GirFFI::UserDefinedObjectInfo
  def interfaces
      (@klass.included_modules - @klass.superclass.included_modules).
        select { |m| m.respond_to?(:gir_info) }.map(&:gir_info)
  end
end


## test with GLib::GIR_FFI_BUILDER.send(:gir).inspect
## - submitted to upstream, in pull request
##   https://github.com/mvz/gir_ffi/pull/280 @ 0.15.9
##   (GirFFI::VERSION)
## - initial version
## - NB this now shadows the @names_cache field from output
##   such that would not be nearly as verbose with the IBaseInfo#inspect method
## - FIXME after some point, this test form results in an error
##   >> in `find_namespaced_class_info': Class GIR_FFI_Builder not found in namespace GLib (NameError)
class GObjectIntrospection::IRepository
  def inspect
    names = @name_cache ? @name_cache.collect {
                            |k,v| v && v.namespace
                          }.filter { |ns| ! ns.nil? }.uniq : nil
    namespaces = names ? "[" + names.join(" ") + "] " : ""
    n_types = @gtype_cache ? @gtype_cache.length : 0
    "#<%s 0x%x %s(%d gtypes)>" % [
      self.class, self.object_id, namespaces, n_types
    ]
  end
end

## test with Gtk::ApplicationWindow.gir_info.inspect
##
class GObjectIntrospection::IBaseInfo
  def inspect
    "#<%s 0x%x (%p %s::%s)>" % [
      self.class, self.object_id, self.info_type, self.namespace, self.name
    ]
  end
end

## TBD
## GLib::GIR_FFI_BUILDER.send(:gir).instance_variable_get(:@name_cache).select { |k,v| v == nil}
## => {["GLib", "GObject"]=>nil, ["GLib", "gObject"]=>nil}
## ^ and hence there is an error below?

## test:
##  app = RIViewApp.new; app.run_threaded

## FIXME before porting to gir_ffi-gtk3, the latter would need
## to be extended for at least ...
##
## - define GtkWidgetClass
##   - define GtkWidget/GtkWidgetClass bind_template_child_full ...
##     ... as a class method, locally, via some "interface module"
## - see TemplateBuilder, ...
##
## - define GtkBuildable (already defined)
##   - define gtk_buildable_get_internal_child - see TemplateBuilder
##   - define initially via a Gtk::Buildable as a module, and extend
##
## - define Gio::Resource - see ResourceTemplateBuilder
##
## - TBD interfaces (in C) via GIR ??? & how git_ffi works
##   NB @ basedir ~/.local/share/gem/ruby/3.0.0/gems/gir_ffi-0.15.9/lib/gir_ffi/
##   - builders/type_builder.rb
##     NB GirFFI::Builders::TypeBuilder::TYPE_MAP.keys
##   - builders/interface_builder.rb#
##   - builders/registered_type_builder.rb

require 'gir_ffi-gtk3'

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
## This module defines the following methods, in an extending
## module or class +c+:
##
## - *+c.logger=+*
## - *+c.logger+*
##
## For purposes of generally class-focused log management, the methods
## +logger=+ and +logger+ will be defined in the extending class or
## extending method, as to access a logger that would be stored within
## the class definition. The class logger may or may not be equivalent
## to the logger provided to +manage_warnings+
##
## In an extending module +c+ the following methods are defined
## additionally:
## - *+c.make_warning_proc+*
## - *+c.manage_warnings+*
## - *+c.with_system_warn+*_warnings+*
## - *+c.use_logger+*, *+use_logger=+*
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
## The method +with_system_warn+ accepts a block, such that the
## dispatching logger will not be called within that block. This method
## is provided as a utility towards ensuring that the dispatching logger
## will not be called within any ection of code that would not permit
## logging to an external logger, such as within a signal trap handler
## defined after a call to +manage_warnings+
##
## The methods +use_logger+ and +use_logger=+ may be used as to
## determine or to set the value of a state variable in the extending
## module, such that the proc form returned by +make_warning_proc+ will
## not use the provided logger when +use_logger+ returns a false
## value. This +proc+ would provide the implementation of the +warn+
## method implemented under +manage_warnings+
##
## * Known Limitations *
##
## In the behaviors of the call to +Warning.extend+, the method
## +manage_warnings+ may in effect override the initial +Kernel.warn+
## method, such that the initial +Kernel.warn+ method will not be called
## from within +with_system_warn+. Some system +warn+ method will be
## used for any +warn+ call within the block provided to
## +with_system_warn+, but the +warn+ method in use within that block
## may differ in its method signature and implementation, compared to
## the initial +Kernel.warn+ method.
##
## While it is known that an external logger should not be used within
## the block provided to a signal trap handler - thus towards a
## rationale for the definition of +with_system_warn+ - this may not be
## the only instance in which a block of code should be evaluated as to
## not use an external logger.
##
## The logger provided to +manage_warnings+ will not be stored
## internally, beyond how the logger is referenced within the proc
## returned by +make_warning_proc+_. It's assumed that the logger
## provided to +manage_warnings+ would be stored within some value
## in the extending class.
##
## @see *GBuilderApp*, providing an example of this module's application,
##  under instance-level integration with *LoggerDelegate* in a
##  class
##
## @see *LoggerDelegate*, providing instance methods via method
##  delegation, for logger access within application objects
##
## @see *Logger*, providing an API for arbitrary message logging in Ruby
##
## @see *LogModule*, which provides an extension of this module via
##  a module, such that may be suitable for extension onto the Ruby
##  *Warning* module
module LogManager
  def self.extended(extender)

    def extender.logger=(logger)
      if @logger
        warn("@logger already bound to #{@logger} in #{self} " +
             "- ignoring #{logger.inspect}", uplevel: 0) unless @logger.eql?(logger)
        @logger
      else
        @logger = logger
      end
    end

    def extender.logger
      @logger # || warn("No logger defined in #{self.class} #{self}", uplevel: 0)
    end

    if extender.is_a?(Module)

      def extender.with_system_warn(&block)
        initial_state = self.use_logger
        begin
          self.use_logger = false
          block.call
        ensure
          self.use_logger = initial_state
        end
      end

      def use_logger()
        @use_logger
      end

      def use_logger=(p)
        @use_logger = !!p
      end

      def extender.make_warning_proc(logger)
        whence = self
        lambda { |*data, uplevel: 0, category: nil, **restargs|
          ## NB unlike with the standard Kernel.warn method ...
          ## - this proc will use a default uplevel = 0, as to ensure that some
          ##   caller info will generally be presented in the warning message
          ## - this proc will accept any warning category
          ## - this proc's behaviors will not differ based on the warning category
          ## - this proc will ensure that #to_s will be called directly on
          ##   every provided message datum
          if whence.use_logger
            ## NB during 'warn' this proc will be called in a scope where
            ## self == the Warning module, not the module to which the
            ## make_warning_proc method is applied in extension. Thus,
            ## the providing module may be referenced here as 'whence'
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

            whence.logger.warn(firstmsg)

            unless( nomsg || nmsgs == 1 )
              data[1...nmsgs].each { |datum|
                whence.logger.warn(catpfx + datum.to_s)
              }
            end
          else
            ## NB The 'super' method accessed from here may not have the
            ## same signature as the original Kernel.warn method, such
            ## that would accept an 'uplevel' arg not vailable to the
            ## 'super' method accessed from here
            super(*data, category: category, **restargs)
          end
          return nil
        }
      end

      def extender.manage_warnings(logger = self.logger)
        proc = make_warning_proc(logger)
        self.define_method(:warn, &proc)
        self.use_logger = true
        Warning.extend(self)
      end
    end # extender.is_a?(Module)
  end # self.extended
end # LogManager module


module LogModule
  ## for Warning.extend(..) which will not accept a class as an arg
  ##
  ## e.g
  ## LogModule.logger = Logger.new(STDERR, level: Logger::DEBUG, progname: "some_app")
  ## LogModule.manage_warnings
  ## warn "PING"
  ##
  ## ... albeit it seems that something in either the Logger or Warning
  ## modules may be adding additional data to the message text, e.g
  ## "<internal:warning>:51:in `warn': "
  ##
  ## NB however: In some contexts when 'warn' may be called, it would
  ## not be valid to try to warn to a logger - e.g within signal trap blocks,
  ## in which context any warning may then loop in trying to emit a warning
  ## about the warning

  extend(LogManager)

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
## GObject::Object (GObject)
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
## under the class *+GObject::Object+* and its subclasses.
##
## When extending this method in a class definition, the class'
## *+register+* method should be called at some point within the class
## definition - whether in the extending class or in some subclass of
## the extending class.
##
## Example
##
##    class ExtObject < GObject::Object
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
## indirect subclass of *+GObject::Object+*
module GTypeExt
  def self.extended(extclass)
    ## return a boolean value indicating whether this class hass been
    ## registered
    ##
    ## @see ::register
    def extclass.registered?()
      @registered
    end

    ## ensure that the +type_register+ class method is called exactly
    ## once, for this class
    ##
    ## @see Gtk::Container::type_register
    ## @see Gtk::Widget::type_register
    ## @see GObject::Object::type_register
    def extclass.register_type() ## FIXME rename this method
      warn "in register_type for #{self}"
      if ! registered?
        # if(self.superclass.instance_methods.member?(:register))
        #    super() ## there is a superclass register method ... for some classes
        # end
        ## nb gir_ffi:lib/gir_ffi/core.rb
        ## NB @registered will now store a pointer address - TBD later usage
        @registered = GirFFI.define_type(self)
        ## ^ NB the define_type method should call g_type_register_static
        ## albeit there may be some later disparity between internal instances
        ## and instances received to signal handlers, e.g app "startup"
        warn "Registered #{self} => 0x#{@registered.to_s(16)}"
      end
    end
  end
end


class DataProxy < GObject::Object # < GLib::Boxed
  extend GTypeExt
  self.register_type ## register the type, exactly once

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
    ## NB the 'data' may not be externally accessible (in GTK)
    ## as here
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

  ## NB any class using this module should call self.init_template()
  ## during the class constructor

  def self.included(extclass)
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
      ## NB this self.object_class part !

      ## FIME null widget template when this is called (??)
      ##
      ## NB call ...type_register... first
      ##
      ## TBD updating self.object_class when the class provides an
      ## extension onto some class in GTK (??)
      #warn("in bind_ui_internal for #{self}")
      self.object_class.bind_template_child_full(id, true, 0)
      ## TBD
      ## $DBG_WINDOW.instance_variable_get(:@struct)[:parent]
    end
  end

  def ui_internal(id)
    ## NB this definition provides an instance method ui_internal
    ## in the including class
    ##
    ## Notes - type inheritance with mixin modules used via include
    ## or extend, in Ruby
    ##
    ## - 'include' affects the type of instances of the including class
    ## - 'extend' affects the type of the including class
    ##
    ## Given:
    ##
    ##   app = RIViewApp.new; app.run_threaded
    ##   rw = RIViewWindow.new(app)
    ##
    ##   rw.is_a?(TemplateBuilder) => true
    ##
    ##   rw.class.is_a?(FileTemplateBuilder) => true
    ##
    ##   rw.is_a?(UIBuilder) => false
    ##   rw.class.is_a?(UIBuilder) => true
    ##
    ## Usage notes:
    ## - 'extend' modules can define instance methods in the including
    ##    class, using define_method with a locally defined proc,
    ##    generally outside of the 'self.extended' section of the module
    ##
    ##    - that proc can be provided as a lambda proc if initialized
    ##      for storage in a variable e.g block = lambda {...}, then
    ##      provided to define_method as e.g &block
    ##    - or it can be defined as a block that does not check
    ##      arguments and does not have the return semantics of a lambda
    ##      proc
    ##
    ## - 'include' modules can define instance methods in the including
    ##    class, using 'def'
    ##
    ## - 'extend' may generally be useful for mixin modules to add class
    ##   methods to a class. It can be used to add instance modules to a
    ##   class, using such as the define_method approach denoted above
    ##
    ## - 'include' may generally be useful for mixin modules to add
    ##   instance  methods to a class. It may also be used to add class
    ##   methods, in the 'self.included' section of the include module
    ##
    ## - Considering that 'include' supports both class method and
    ##   instance method definition with 'def' in the defining module --
    ##   as whether in the mixin module's self.included section e.g 'def
    ##   extclass.method_name' or respectively, not in the self.included
    ##   section - 'include' may appear to be more generally useful for
    ##   applications. Regardless, considering how 'extend' affects the
    ##   type of a class - notwithstanding the type of the instances of
    ##   the class - this feature in itself may bear some consideration,
    ##   towards applications of 'extend' with modules
    ##
    self.get_internal_child(self.class.builder, id) ||
      raise("#{__method__} failed to get internal child in #{self} with id #{id}")
    ## FIXME be more type specific in the error
  end
end


module ResourceTemplateBuilder
  def self.extended(extclass)
    extclass.include TemplateBuilder

    ## ensure that a resource bundle at the provided +path+ is
    ## registered at most once, for this class
    ##
    ## @see ::init
    ## @see ::resource_bundle_path
    ## @see ::resource_bundle
    def extclass.use_resource_bundle(path)
      ## NB storing the bundle in extclass, such that  _unregister and
      ## unref (??) can be called for the Resource bundle, during some
      ## pre-exit/pre-gc cleanup method, in any implementing class (FIXME)
      if @bundle
        warn "Bundle for #{@bundle_path} already registered for #{self}. Ignoring #{path}"
      else
        ## FIXME this pathname expansion needs cleanup
        gem_dir=File.expand_path("..", File.dirname(__FILE__))
        use_path = File.expand_path(path,gem_dir)

        @bundle_path = use_path
        @bundle = Gio::Resource.load(use_path)
        ## NB not reached / not used (FIXME?)
        warn("Registering bundle #{@bundle} @ #{use_path}", uplevel: 0)
        @bundle._register
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
    ## @see ::use_resource_bundle
    ## @see ::use_template
    #def extclass.init ## ... porting to ...
    def extclass.with_template(whence) ## FIXME needs another impl under gir_ffi-gtk3
      warn("[DEBUG] Using template #{whence} in #{self}", uplevel: 1)
      @template = whence
    ## TBD may be unused in gir_ffi-gtk3
    ## ! FIXME needs check, that, and portability docs
    #   ## fixme this could but presently does not validate the @template
    #   ## resource path onto any registered @bundle for the class

    #   ## FIXME this needs more project tooling
    #   ##
    #   ## see also glib-compile-resources(1) && Rake
    #   ##  ... --generate riview.gresource.xml ...
    #   ##
    #   ## NB glib-compile-schemas(1) && GApplication (&& Rake)

    #   ## NB here, @template must represent a GResource path, not a filename

      ## FIXME this sets it as a 'private' template. NB on subsequent
      ## calls to template_from_resource
      ##  gtk_widget_class_set_template_from_resource: assertion 'widget_class->priv->template == NULL' failed
      ## whereas during instance.init_template ??
      ##  gtk_widget_init_template: assertion 'template != NULL' failed
      self.object_class.set_template_from_resource(@template)
    end

    extclass.register_type
  end
end

module FileTemplateBuilder
  def self.extended(extclass)
    extclass.include TemplateBuilder

    ## load this class' template as a file
    ##
    ## @see ::use_template
    #def extclass.init ## FIXME needs another impl under gir_ffi-gtk3
    def extclass.with_template(whence) ## FIXME needs another impl under gir_ffi-gtk3
      ## FIXME this pathname expansion needs cleanup
      warn("[DEBUG] Using template #{whence}", uplevel: 1)
      @template = whence
      gem_dir=File.expand_path("..", File.dirname(__FILE__))
      use_path = File.expand_path(@template,gem_dir)
      if File.exists?(use_path)
        ## NB can create a GLib::Bytes directly here
        begin
          bytes = GLib::Bytes.new(File.read(use_path))
          self.object_class.set_template(bytes)
        ensure
          bytes.unref()
        end
      else
        raise "Template file does not exist: #{use_path}"
      end
    end
    extclass.register_type
  end
end

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

class RIViewWindow < Gtk::ApplicationWindow

  extend(LoggerDelegate)
  def_logger_delegate(:@logger)
  attr_reader :logger
  LOG_LEVEL_DEFAULT = Logger::DEBUG

  #extend FileTemplateBuilder
  ##self.use_template("ui/appwindow.glade")
  #self.with_template("ui/appwindow.glade")
  ## ^ next, now ...

  extend ResourceTemplateBuilder
  self.use_resource_bundle("riview.gresource")
  #self.with_template("ui/appwindow.ui") ## "does not exist"
  ## ^ FIXME setting resource root path in the application/builder
  self.with_template("/space/thinkum/riview/ui/appwindow.ui")

  def set_window_action(name, &block)
    ## FIXME at some point, the window's application is set to the wrong instance?
    @logger.debug("Adding action '#{name}' in #{self} (#{Thread.current})")
    act = Gio::SimpleAction.new(name)
    act.signal_connect("activate", &block) ## FIXME review
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

  ## FIXME these fail later in <inst>#ui_internal
  self.bind_ui_internal("RIPageView") ## NB x RIDocView
  self.bind_ui_internal("RITreeStore")

  ## @param application [GBuilderApp]
  def initialize(application)
    self.class.builder = application.class.builder
    $DBG_WINDOW = self

    ## FIXME app.class.builder.get_objects => nil ?

    super(application)

    if self.application.nil?
      ## NB the window's application field may be null after destroyed
      warn "Null application after super(...) in #{__method__} for #{self}"
    end

    ## FIXME it's receiving the wrong application
    ## under the RIViewApp startup signal handler

    @logger = application.logger

    @logger.debug("in #{__method__}(#{application.inspect}) @ #{self} ")


    ## !! FIXME !! null template - how now?
    ##
    ## null template in its gtk widget object/class data in gtk space????
    ##
    self.init_template() ## per behaviors of TemplateBuilder submodules
    ## ^^ TBD running this here, or during the 'realize' signal handler
    ## % NB original method is defined onto Gtk::Widget

    ## NB RIViewWindow.gir_info
    ## NB RIViewWindow.registered_ancestors
    ## NB RIViewWindow.gtype == RIViewWindow.registered?

    ## TBD $DBG_WINDOW.instance_variable_get(:@struct)
    ## => #<RIViewWindow::Struct:0x00007fdf702ada80>
    ## such that the instance class' superclass => GirFFI::Struct => FFI::Struct
    ## RIViewWindow::Struct.members => [:parent]
    ##
    ## $DBG_WINDOW.instance_variable_get(:@struct)[:parent]
    ## => #<Gtk::ApplicationWindow::Struct:0x000055b539cbd8f8>
    ##
    ## $DBG_WINDOW.instance_variable_get(:@struct)[:parent].members
    ##  => [:parent_instance, :priv]
    ##
    ## $DBG_WINDOW.instance_variable_get(:@struct)[:parent][:parent_instance]
    ## => #<FFI::Pointer address=0x000055b5393b27f0>

    ## NB resource path walker for the bundle
    ##
    # self.class.
    #   resource_bundle.enumerate_children("/space/thinkum/riview/ui",0).
    #   each { |resource|
    #     ## TBD ... FIXME no output
    #     @logger.debug("Template child #{resource}")
    #   }


    self.signal_connect("show") {
      @logger.debug("Signal 'show' in #{self} (#{Thread.current})")
      ## TBD ... dispatch to a handle_signal_show method
    }
    self.signal_connect("map") {
      @logger.debug("Signal 'map' in #{self} (#{Thread.current})")
      ## TBD ... dispatch to a handle_signal_map method
    }

    self.signal_connect("realize") {
      @logger.debug("Signal 'realize' in #{self} (#{Thread.current})")
      self.handle_signal_realize
    }

    @logger.debug("Added some signals for #{self}")

    name = self.class.name ## NB during development
    self.name=name
    self.set_title(name)
    ## TBD handle rest during 'realize'
  end

  def handle_signal_realize(*args)
    ## NB *args might be discarded - received by the signal handler
    @logger.debug("in #{__method__} w/ #{args} @ #{self}")

    #self.init_template() ## per behaviors of TemplateBuilder submodules
    ## ^ null template here ?

    ## TBD does the template access work out any more effectively
    ## if delayed until a 'realize' signal handler?
    ## --> It does not!

    if self.application.nil?
      ## NB reference it as self.application not just 'application' here ...
      warn "Null application after in #{__method__} for #{self}"
    end

    set_window_action("new") {
      #@logger.debug("Action 'new' in #{self} (#{Thread.current})")
      ## how on earth is this resulting in an error from an object != self ?
      self.logger.debug("Action 'new' in #{self} (#{Thread.current})")
      self.application.map_app_window_new
    }
    set_window_action("prefs") {
      @logger.debug("Action 'prefs' in #{self} (#{Thread.current})")
      self.application.map_prefs_window
    }
    closeAct = set_window_action("close") { |*args|
      if self.application.nil?
        warn "Null application in 'close' handler for #{__method__} for #{self}"
      end

      ## FIXME why is this being called during 'realize' ?
      ## => what is calling "destroy" ?? during 'realize' ??

      @logger.debug("Action 'close' in #{self} #{args} (#{Thread.current})")
      self.application.remove_window(self)
      self.unmap
      self.destroy
      ## FIXME it receives a GApplication not a GtkApplication - how now?
      self.application.quit if self.application.windows.length.zero?
    }
    set_window_action("quit") {
      @logger.debug("Action 'quit' in #{self} (#{Thread.current})")
      closeAct.activate
      self.application.quit
    }

    @logger.debug("Added actions for #{self}")


    self.signal_connect("destroy") {
      ## undefined method `gir_info' for TemplateBuilder:Module ????
      ## during self.signal_connect here ?
      ## from - at some point
      ## - GirFFI::Buildedrs::ObjectBuilder.seek_in_ancerstor_infos
      ##   which does not appear to check the type of each
      @logger.debug("Signal 'destroy' in #{self} (#{Thread.current})")
      closeAct.activate ## needs access to closeAct here
    }
    @logger.debug("Added 'destroy' signal handler for #{self}")

    ## NB ~/.local/share/gem/ruby/3.0.0/gems/gtk3-3.4.9/sample/misc/treestore.rb

    if (tbdx = get_template_child(Gtk::Notebook.gtype, 'RIPageView'))
      @logger.debug("Got template child #{tbdx}")
    else
      ## FIXME also fails ...
      @logger.warn("Failed to get template child RIPageView")
    end

    if (tbd = ui_internal("RIPageView") )## FIXME failing, and is a template child
      ## ^ NB errs internally before => nil
      ## FIXME the error does not show up, here
      @logger.debug("Got internal child RIPageView")
    end

    store = ui_internal("RITreeStore")
    ## ^ FIXME failing. NB is not a template child, per se, though
    ## declared in the same UI file a the template class' widget layout

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

    ## FIXME though it's not the most succinct thing still, this should
    ## be ready for testing with iteration onto the site store -
    ## modules, classes, methods

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


    ## FIXME remove the 'exp' column from the tree store/model
    ##
    ## GTK handles the "folded state" internal to the UI,
    ## independent of the data model

    @topic_store = store

    @pageview = ui_internal("RIPageView")

    ObjectSpace.define_finalizer(self, self.class.finalizer_proc(
      @win_actions.values
    ))

    @logger.debug("returning from #{__method__} @ #{self} ")


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

  ## FIXME ensure that this uses the same builder as the RIViewApp class

  ## FIXME only one template-based class per UI file...?
  #self.use_template("ui/docview.ui")
  self.with_template("ui/docview.ui")


  self.bind_ui_internal("DocTextView")

  attr_reader :buffer

  def initialize(application)
    super()
    self.init_template ## fails without error ...
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
  #self.use_template("ui/prefs.ui")
  self.with_template("ui/prefs.ui")

  ## ensure that some objects from the template will be accessible
  ## within each instance
  self.bind_ui_internal("SystemStorePath") ## FIXME failing (returns nil)
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


class GBuilderApp < Gtk::Application

  ## TBD mapping this onto GtkApplicationClass w/i gir_ffi-gtk3
  ## NB <this_class>.object_class => #<Gtk::ApplicationClass ...>

  extend(LoggerDelegate)  ## FIXME move to GApp
  def_logger_delegate(:@logger)  ## FIXME move to GApp
  attr_reader :logger  ## FIXME move to GApp
  LOG_LEVEL_DEFAULT = Logger::DEBUG  ## FIXME move to GApp

  extend UIBuilder

  extend LogManager ## FIXME move to GApp

  attr_reader :name

  # attr_reader :gtk_loop # see ...

  ## utility method for procesing the +flags+ option under
  ## *+GBuilderApp#initialize+*
  ##
  ## When applied to that +flags+ value, this method must return an
  ## integer value, such that will be used in a call to
  ## *+Gio::Application#set_flags+*, before the *GBuilderApp* is
  ## registered to GTK. Provided with an appropriate +flags+ value, this
  ## will be managed internally during *GBuilderApp* initialization
  ##
  ## *Examples*
  ##
  ##    GBuilderApp.get_app_flag_value('is_service') ==
  ##       Gio::ApplicationFlags::IS_SERVICE.to_i => true
  ##
  ##   GBuilderApp.get_app_flag_value(:handles_open) ==
  ##       Gio::ApplicationFlags::HANDLES_OPEN.to_i => true
  ##
  ##   GBuilderApp.get_app_flag_value([:is_service, :handles_open])
  ##       => <Integer>

  def self.get_app_flag_value(datum)  ## FIXME move to GApp
    name, value = nil
    case datum
    when Array
      value = 0
      datum.each { |elt| value = (value | self.get_app_flag_value(elt)) }
    when Integer
      value = datum
    #when Gio::ApplicationFlags
    # ## N/A under gir_ffi-gtk3
    #  value = datum.to_i
    when String
      ## NB except for FLAGS_NONE, the constants defined under this Gio
      ## Ruby module do not use any special prefix
      ## e.g
      ##  "is_service" => Gio::ApplicationFlags::IS_SERVICE,
      ##  :handles_open => Gio::ApplicationFlags::HANDLES_OPEN,
      name = datum.upcase.to_sym
    when Symbol
      name = datum.upcase
    when NilClass
      value = Gio::ApplicationFlags::FLAGS_NONE.to_i
    else
      raise ArgumentError.new("Unkown Gio::ApplicationFlags specifier: #{datum.inspect}")
    end
    if !value
      fl = Gio::ApplicationFlags.const_get(name)
      if fl
        value = fl.to_i
      else
        raise ArgumentError.new("Unknown Gio::ApplicationFlags specifier: #{datum.inspect}")
      end
    end
    return value
  end

  ## @param name [String] The application name (FIXME syntax check)
  ##
  ## @param logger [Logger | nil] *Logger* to use for Ruby logging in
  ##   this application instance. If +nil+, a *Logger* will be initialized
  ##   on +STDERR+, with a log level of +::LOG_LEVEL_DEFAULT+ and a
  ##   program name equal to +name+
  ##
  ## @param flags [Integer | String | Symbol | Array<Integer | String | Symbol>]
  ##  see ::get_app_flag_value for a description of the syntax and usage
  ##  of this parameter
  def initialize(name, logger: nil,
                 flags: Gio::ApplicationFlags::FLAGS_NONE.to_i)
    # @state = :initialized

    @name = name

    ## NB @logger will be used for the LoggerDelegate extension,
    ## providing instance-level access to the logger with an API
    ## similar to Logger, as wrapper functions onto the @logger itself
    ##
    @logger = logger ? logger :
      self.class.logger ||= Logger.new(STDERR, level: LOG_LEVEL_DEFAULT,
                                       progname: name)

    LogModule.logger ||= @logger
    LogModule.manage_warnings

        ## NB this will display information about exeptions raised
        ## within Ruby, including exceptions that are trapped
        ## within some rescue form
        ##
        ## This is also reached from 'exit'
        ##
        ## This TracePoint is not reached for the peculiar
        ## NoMethodError denoted below - that might be emitted from C
        trace = TracePoint.new(:raise) do |pt|
          pt_exc = pt.raised_exception
          pt_path = pt.path
          ## exceptions to ignore
          ign_exc = [RDoc::Store::MissingFileError,
                     RubyLex::TerminateLineInput,
                     SyntaxError, QueryError]
          unless (ign_exc.member?(pt_exc.class))
            puts("[debug] %s %s [%s] @ %s:%s" %
                 [pt.event, pt_exc.class,
                  pt_exc.message,
                  pt_path, pt.lineno])
          end
        end
        trace.enable


    fl_value = self.class.get_app_flag_value(flags)
    ## NB initializing Gio::ApplicationFlags under gir_ffi-gtk3 ~~ N/A
    ## where it's a module providing enum constants
    #fl_obj = Gio::ApplicationFlags.new(fl_value)
    ## NB fl_obj would be a proxy object for an enum value,
    ## and should not need to be unref'd
    #self.set_flags(fl_obj) ## provide directly to the superclass
    #constructor here

    ## NB Gio::Application is the superclass of the superclass here
    ## under gir_ffi-gtk3
    #super(name, fl_obj)
    super(name, fl_value)

    ## FIXME 'get_application' does not then return this object, on the builder
    self.class.builder.set_application(self)

    activate_block = lambda { |*args|
      ## FIXME not reached
      @logger.debug("In activate (#{self}) : args #{args}")
    }
    ## TBD move to GApp, if the signal handler is ever reached
    self.signal_connect("activate", &activate_block)

    startup_block = lambda { |*args|
      @logger.debug("In GBuilderApp startup (#{self}) : args #{args.inspect}")
      ## NB REACHED
      $DBG_APP = args[0]
    }
    self.signal_connect("startup", &startup_block)


    ## FIXME now attach signal handlers for 'startup' and 'activate'
    ## => handle_startup, handle_activate methods

    ## NB GtkApplication startup should handle Gtk.init(...) here,
    ## but how is the "startup" handler activated?
    ##
    ## See also: devhelp @ gtk_init
    ## FIXME/TBD passing cmdline args to the application

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

  def run()  ## FIXME move to GApp
    @logger.debug("#{__method__} in #{Thread.current}")

    begin
      self.register(nil)
    ## FIXME gir_ffi-gtk3 Gtk::Application provides a register instance method
    ## via Gio::Application
    ## which will emit the "startup" signal
      ## which is where the following "run" logic could be handled .. (FIXME)

    rescue => exc # Gio::IOError::Exists ## N/A.
      # TBD self.register always returns true, at least under the RIView app
      ## NB
      ## - there is no unregister method for Applications in GTK
      ## - this application has not been defined with a flag
      ##   G_APPLICATION_NON_UNIQUE, however that may be represented
      ##   in the Ruby API. If it was defined as such, TBD side effects
      @logger.fatal("Unable to register #{self}: #{exc.class} : #{exc}")
      if exc.backtrace
        ## ":pointer argument is not a valid pointer" during gtk_application_window_new
        ##
        ## FIXME what in GTK is trying to call gtk_application_window_new?
        ## presumably during the "startup" handler
        ##
        ## ... did something need to create a window and call add_window ?
        exc.backtrace.each { |data| @logger.debug("[debug] #{data}") }
      end
    ## NB DNW: calling Gtk.main after A) the app is closed, B) Gtk.main_quit
    ##
    ## FIXME define a service implementation of this app,
    ## such that can be used from IRB
    else
      ## TBD storing main_thread - see also the GMain loop API via Ruby ...
      @main_thread = Thread.current
      ## FIXME bind to an 'initialized' signal, with a proc
      ## that will @syncMtx.synchronize { @syncCv.signal }

      ## super(gtk_cmdline_args) # TBD
      @logger.debug("#{__method__} calling Gtk.main in #{Thread.current}")
      # @state = :run
      begin
        ## FIXME these Signal.trap calls DNW under #run_threaded
        ## 1) an odd error is produced (see below)
        ## 2) the thread exits an under "aborting" state
        Signal.trap("TRAP") do
          ## cf. devehlp @ GLib g_log_structured, G_BREAKPOINT documentation
          ## => SIGTRAP (some architectures)
          LogModule.with_system_warn {
            ## NB ensuring that the logger won't be called during a
            ## signal trap - the system would emit a warning then ...
            ##   >> "log writing failed. can't be called from trap context"
            ## ... such that would fail recursively, if the only warning
            ## handler would be trying to dispatch to a logger
            warn "Received SIGTRAP. Exiting in #{Thread.current.inspect}"
            #Gtk.main_quit
            exit(false)
          }
        end
        Signal.trap("INT") do
          LogModule.with_system_warn {
            warn "Received SIGINT. Exiting in #{Thread.current.inspect}"
            #Gtk.main_quit
            exit(false)
          }
        end
        Signal.trap("ABRT") do
          LogModule.with_system_warn {
            warn "Received SIGABRT. Exiting in #{Thread.current.inspect}"
            #Gtk.main_quit
            exit(false)
          }
        end

        @logger.debug("In process #{Process.pid}")


        ## TBD ...
        #GObject::signal_emit(self,"startup")


        ## FIXME in review of the previous, it may be more effective
        ## to define a tracepoint on 'warn' than to shadow the 'warn' method
        ## to direct any warning output to a logger - assuming that this
        ## will not in itself result in a warning in Ruby (e.g when
        ## logging during a signal trap handler)
        ##
        ## as such, an extension could be defined on TracePoint that
        ## would provide a mutex for locking the instance's "enabled'
        ## field. That mutex could be held and the instance disabled,
        ## e.g within any signal trap handler - such that the mutex-
        ## sync'd form would return the 'enabled' state of the
        ## TracePoint to its original value, via a final 'ensure' form
        ##
        ## FIXME this app needs a log viewer

        ## FIXME this app needs a trace support module
        ## => popup for tracepoint inspection (bindings, etc)
        ## ... may be tricky to implement e.g for any tracepoint on 'raise'
        ##
        ## see ./tracetest.rb, ./tracetool.rb

        Gtk.main()  ## FIXME move to GtkApp < GApp :: #main(args = nil)
        ## vis a vis args, note e.g '--gapplication-app-id' in GLib's GApplication
        ## and other args avl with GtkApplication
        ## >> documentation (DocBook | YARD)
        ## >> g.thinkum.space
        ##
        ## NB GRubyService < GConsoleService < GApp
        ## TBD GShellService < GConsoleService

        ## NB example of Glib::MainLoop application
        ## ~/.local/share/gem/ruby/3.0.0/gems/vte3-3.4.9/test/test-terminal.rb
        ## see also: "The Main Event Loop" in the GLib devhelp manual

        #@main = GLib::MainLoop.new


        ## FIXME in this source file, store every return value from
        ## signal_connect within an array of signal callback IDs.
        ## On each element of that array, call signal_handler_disconnect(elt).
        ## Call this array-walking method as a part of
        ## unref/free/pre-finalization routines, during exit.
      rescue => exc
        ## FIXME does not trap Ruby errors raised under Gtk.main,
        ## such that cause the application to exit without further
        ## action

        warn "Exception #{exc.class}: #{exc}"
        ## ?? Exception NoMethodError: undefined method `message' for 8:Integer
        ## ... and no backtrace. Where is that error arriving from?
        ## ... when:
        ##  1) app is ran via run_threaded
        ##  2) SIGTRAP is sent to the Ruby process, externally, via kill(1)
        ##  3) prefs window is created in the app (TRAP trap not reached during run_threaded)
        ## ! Same happens when SIGINT is sent, when app is run via run_threaded
        ##
        ## Is the NoMethodError being produced by something in the C code for Ruby-GNOME?
        ## (no backtrace, and what a generic error message)

       exc.backtrace.each { |info| warn "[backtrace] " + info.to_s } if exc.backtrace
        # @logger.error("%s caught %s under %s 0x%x : %s" %
        #               [__method__, exc.class, Thread.current.class,
        #                Thread.current.object_id, exc.message])
        # if (bt = exc.backtrace)
        #   n = 0
        #   bt.each { |info|
        #     @logger.error("[backtrace 0x%02x] %s" % [n, info])
        #     n = n+1
        #   }
        # end
      end
    end
    @logger.debug("#{__method__} returning in #{Thread.current}")
    if Thread.current.status == "aborting"
      ## NB This may be reached - on a Linux system - when
      ## 1) the app is run via run_threaded
      ## 2) SIGINT is sent to the ruby process, externally
      ## 3) a dialogue window is created
      ##
      ## - note that the SIGINT handler was not reached under
      ##   run_threaded, not until the dialogue window was created
      ## - that may be due to some peculiarities about where the trap
      ##   handler is defined, and how Gtk.main is run
      ##
      ## TBD whether this or the handler is ever reached under
      ## run_threaded, on a BSD system
      warn "Uncaught thread abort. Exiting"
      Thread.current.backtrace_locations.each { |info|
        warn "[backtrace] " + info.to_s
      } if Thread.current.backtrace_locations
      exit(false)
    end
  end

  def run_threaded()  ## FIXME move to GApp
    ## FIXME this thread appears to no longer run asynchronously,
    ## when launched under IRB
    ##
    ## The thread is returned to IRB and displayed as such,
    ## but the next IRB propmpt/input line does not appear until after
    ## the app has exited
    @logger.debug("#{__method__} from #{Thread.current}")
    NamedThread.new("%s#run @%x" % [self.class.name, self.object_id]) {
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

  def inspect()
    "#<%s 0x%0x [%s]>" % [self.class, self.object_id, self.name]
  end

end

class RIViewApp < GBuilderApp

  attr_reader :system_store, :site_store, :home_store, :gem_stores

  TBD = GirFFI.define_type(self)
  ## ^ no affect on the application received under the 'startup' signal handler
  ## ^ TBD that pointer address (??) stored in 'TBD' can be used how?

  def initialize()
    super("space.thinkum.riview")
    ## FIXME set a filesystem base directory in the class
    # self.signal_connect("startup") {
    #   ## forms to run subsq. of successful register()
    #   ##
    #   ## NB this will be activated by register() only once per process.
    #   self.map_app_window_new
    ## TBD - see below
    # }
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


    startup_block = lambda { |*args|
      @logger.debug("In RIViewApp startup (#{self}) : args #{args}")
      ## FIXME the args it receives - it's a GtkApplication and
      ## not equal to the actual RIViewApp
      ##
      ## Even what the RIViewWindow constructor receives - wrong app
      ##
      w = RIViewWindow.new(self)

      ## FIXME not reached
      $DBG = w.object_class
      @logger.debug("Using window with object class #{w.object_class}")
      ## NB may be required for a GtkApplication - add_windoww during a
      ## "startup" handler ??
      self.add_window(w)
      ## ?? FIXME move into an "activate" handler & revise the startup call chain
      w.show
    }
    self.signal_connect("startup", &startup_block)

  end

  def map_prefs_window()
    #raise "Error test"
    ## ^ uncaught from within Gtk.main, despite every effort otherwise
    ##   => app exits (FIXME)
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

=begin TBD

also problematic

irb(main):075:0> GLib::Log.log("Frob",GLib::Log::LEVEL_ERROR,"frob")

(irb:33315): Frob-ERROR **: 13:17:37.431: frob

Trace/breakpoint trap (core dumped)

-----

similarly problematic

irb(main):001:0> require 'gtk3'
=> true
irb(main):002:0> GLib::Log.always_fatal=0
=> 0
irb(main):003:0> GLib::Log.log("Frob",GLib::Log::LEVEL_ERROR,"Frob")

(process:36589): Frob-ERROR **: 13:21:32.340: Frob
Trace/breakpoint trap (core dumped)

----
similarly

irb(main):001:0> require 'gtk3'; DM="Frob"
=> true
irb(main):002:0> GLib::Log::set_fatal_mask(DM,0)
=> 5G
irb(main):003:0> GLib::Log.log(DM,GLib::Log::LEVEL_ERROR,"Frob")

(process:36765): Frob-ERROR **: 14:08:01.120: Frob
Trace/breakpoint trap (core dumped)

-----
albeit, from the devehlp for g_log calls: "G_LOG_LEVEL_ERROR is always fatal"

So, ...

irb(main):003:0> GLib::Log::set_fatal_mask(DM,GLib::Log::LEVEL_CRITICAL)
=> 5
irb(main):004:0> GLib::Log.log(DM,GLib::Log::LEVEL_CRITICAL,"Frob")

(process:36797): Frob-CRITICAL **: 14:12:03.362: Frob
Trace/breakpoint trap (core dumped)

... is that really how it's supposed to exit now?

TBD: Produce a list of log domains used through the Ruby GTK code, at
some known release - and how to reference those as constants

----

TBD: Patching the src to provide support for log handling w/ GTK in Ruby

... it doesn't provide any way to map a function into the log
handling. This only sets a log level mask:

      GLib::Log.set_handler(domain, mask)

... looking at
~/.local/share/gem/ruby/3.0.0/gems/glib2-3.4.9/lib/glib2.rb

and at g_log_set_writer_func() in devhelp => call exactly once in each GTK app process

=end

## Local Variables:
## fill-column: 65
# End: