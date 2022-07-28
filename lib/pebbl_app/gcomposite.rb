## Mixin definitions for composite widget support w/ Glade UI templates

require 'pebbl_app/gtk_framework'

module PebblApp

  class UIError < RuntimeError
  end

  ## This module provides a baseline mixin type for template support
  ## with Gtk Widget classes. This is in providing a general emulation of
  ## composite template support developed in the Ruby-GNOME framework.
  ##
  ## This mixin module, in effect, extends the mixin module
  ## PebblApp::GUserObject (see register_type) and is extended in the
  ## mixin module FileCompositeWidget (see use_template)
  ##
  ## The following methods will be defined at the class scope of each
  ## extending class:
  ##
  ## - `set_composite_connect_func` providing a limited form of runtime
  ##    code coverage analysis for signals bound within the template UI
  ##    file of the extending class.
  ##
  ##    If any signal receiver is defined in the template UI file, such
  ##    that the signal receiver denotes a method not accessible in the
  ##    application environment, a UIError will be emitted from within
  ##    the signal connection function defined in this method. The
  ##    UIError will provide some information about the origin widget
  ##    class, expected signal receiver method, and receiving widget
  ##    class of the signal receiver method.
  ##
  ##    Each entity denoted in the UIError will be presented as
  ##    dereferenced in the Ruby application environment.
  ##
  ##    This class method is presently called by `initialize_template_children`
  ##
  ## - `initialize_template_children`. This method may be generally
  ##    analogous to the Gtk::Widget.bind_template_child class provided in
  ##    Ruby-GNOME. However, this method receives an array of template
  ##    children, then providing some limited runtime code analysis
  ##    for the array of template children.
  ##
  ##    For each template child ID provided in the array of template
  ##    children to this method, a reader method will be defined as an
  ##    instance method of the same name as that ID. Each reader method
  ##    will be defined within an instance scope in the extending class.
  ##
  ##    After initialing the reader methods for template children, this
  ##    method will then dispatch to call `set_composite_connect_func`
  ##    for the extending class.
  ##
  ##    For each template-child reader method and each
  ##    Gtk::Builder.connect_signal call initialized from this class
  ##    method, some additional instance checking will be provided.
  ##    This should serve to ensure that each template child ID provided
  ##    to this method matches some available template child, secondly
  ##    that each signal receiver method defined in the UI file matches
  ##    a corresponding method in the Ruby application environment.
  ##
  ##    For each template child reader method, the reader methods
  ##    defined with this class method will never return nil.
  ##
  ##    In each reader method: If no GTK object can be found for the
  ##    template child ID corresponding to the reader method's
  ##    definition, the method will raise a PebblApp::UIError.
  ##
  ##    As a known limitation: Generally this UIError may not in
  ##    itself identify the first missing template child in some array
  ##    of template children. When this error has been raised, generally
  ##    the GTK framework will have emitted a critical log message
  ##    indicating the ID of the initial, missing template child.
  ##
  ##    This method will use the `set_composite_connect_func` method
  ##    to bind signal handlers defined in the composite class' UI
  ##    template file. For any signal handler defined in the UI file
  ##    but inaccessible in the application environment, a UIError will
  ##    be emitted.
  ##
  ##    Similar to `bind_template_child` in Ruby-GNOME, this method will
  ##    ensure that each template child is added to the
  ##    `template_children` array for the extending class.
  ##
  ##    For any template child named to this method, if that template
  ##    child is already listed in the `template_children` array for the
  ##    extending class, then this method  will not define any reader
  ##    method for the same template child. If the global variable
  ##    $DEBUG has a truthy value at the time, a warning will be emitted
  ##    via PebblApp::AppLog, indicating the skipped template child ID.
  ##
  ## - `template_children` returning an array of strings for template
  ##    child ID values, for all template children initailized with
  ##    initialize_template_chidren. This array will be stored within
  ##    the instance variable, `@template_children` for the singleton
  ##    class of the the extending class
  ##
  ## - `template_child?` receiving a template child ID (string or
  ##    symbol) then returning true if the ID denotes a template child
  ##    listed in the `template_children` array for the extending class
  ##
  ## - `composite_builder` returning a Gtk::Builder object. This object
  ##   will be used within the initialize_template_children method
  ##   defined with this mixin and may be applied for other operations
  ##   on a Gtk::Builder at the class scope
  ##
  module CompositeWidget
    def self.extended(whence)
      whence.extend PebblApp::GUserObject

      if ! whence.singleton_class.instance_variable_defined?(:@template_children)
        whence.singleton_class.instance_variable_set(:@template_children, Array.new)
      end

      ## Return the set of template child ID strings for template
      ## children provided to initialize_template_children
      ##
      ## This will override the Ruby-GNOME template_children method in
      ## the extending class
      whence.singleton_class.define_method(
        :template_children,
        lambda {
          whence.singleton_class.instance_variable_get(:@template_children)
        })


      ## return a Gtk::Builder for UI definitions in this class
      ##
      ## If no composite_builder has been initialized to the class, this
      ## method will initialize a new composite_builder as
      ## `Gtk::Builder.new`, then storing the object as `@builder` in
      ## the class' singleton class and returning the new object.
      ##
      ## @return [Gtk::Builder] the composite builder
      ## @see initialize_template_children where this builder will be
      ##      applied for binding each template child to an instance
      ##      variable
      whence.singleton_class.define_method(
        :composite_builder,
        lambda {
          ## deferring initialization of the builder, mainly to ensure
          ## that it can be initialized after type_register in the class
          if ! whence.singleton_class.instance_variable_defined?(:@builder)
            whence.singleton_class.instance_variable_set(:@builder, Gtk::Builder.new)
          end
          whence.singleton_class.instance_variable_get(:@builder)
        })

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
          ## This generally emulates a call to Gtk::Widget.set_connect_func
          ## to bind a method for each signal handler.
          ##
          ## The following definition provides a preliminary check, to test
          ## for an instance method in the composite class, as corresponding
          ## to each signal handler name.
          ##
          ## For purpose of documentation, this may be referenced to
          ## examples 7 and subsequent in the sample tutorial: Getting
          ## started with GTK+ with the ruby-gnome2 Gtk3 module, available
          ## at the GitHub repository for the Ruby-GNOME project
          ## https://github.com/ruby-gnome/ruby-gnome/tree/master/gtk3/sample/tutorial
          ##
          ## Generally, this may correspond to a convention of configuring
          ## a signal handler as a method name, optionally with a UI
          ## object selected as the user data object for a signal's
          ## activation, using a widget's UI definition in Glade. This may
          ## be applicable at least for composite widgets defined in
          ## Glade.
          ##
          ## As an approximate overview:
          ##
          ## In the Glade UI designer, the signal handlers for a widget
          ## may be configured under the "Signals" sidebar for each
          ## widget. With the Ruby-GNOME bindings for GTK, a Ruby method
          ## name may be entered as the handler for any signal in that
          ## "Signals" sidebar. If a widget object in the UI design is
          ## selected as the "User Data" object in the "Signals" sidebar,
          ## that object will become the recipient of a call to the
          ## named method, when the corresponding signal is activated on
          ## the widget configured for that signal, in the UI.
          ##
          ## For args that will be received by each named method, the args
          ## syntax  may vary by the nature of the signal to which the
          ## method is mapped as a signal handler. Documentation about
          ## each signal handler is available in GNOME Devhelp, and may be
          ## accessed via the Glade UI designer.
          ##
          ## FIXME this needs normal framework documentation, external to
          ## the source comments here. Contrast the signal handling in GTK
          ## to GIO actions in GTK
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
                "No instance method %s found in class %s for signal %p (%s in %s)" % [
                  handler_name, self, signal_name, object.class, object.parent.class
                ])
            end
          end
          return self
        end

        ## return true if the id represents a bound template child for
        ## this class, else return false
        ##
        ## @param id [String, Symbol] the id for the template child. If
        ##  provided as a string, then this method will use a  symbol
        ##  representation of the string, internally.
        ##
        ## @see template_children
        ## @see initailize_template_children
        def template_child?(id)
          template_children.include?(id.to_s)
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
        ##  composite class, as returning the widget for that ID
        ##
        ## @param path [String] for debugging  purposes, the filename or
        ##  resource path of the template
        ##
        ## @see FileCompositeWidget, which provides a use_template method
        ##  that will be defined in any extending class. That use_template
        ##  method will dispatch to initialize_template_children after
        ##  setting the template definition for the extending class.
        ##
        ## @raise UIError If an internal template child cannot be located
        ##  for any template child id provided to this method, a UIError
        ##  will be raised when that accesor method is called
        def initialize_template_children(children, path: Const::UNKNOWN,
                                           builder: self.composite_builder)
          children.each do |id|
            id.freeze
            if template_child?(id)
              PebblApp::AppLog.warn(
                "Template child already bound for #{id} in #{self}"
              ) if $DEBUG
            else
              PebblApp::AppLog.debug(
                "Binding template child #{id} for #{self}"
              ) if $DEBUG
              ## about the second arg for bind_template_child_full
              ## >> true => internal, Template child is available with a
              ##            builder object, via get_internal_child
              ## >> false => not internal; Template child is available with
              ##             type via get_template_child
              ##
              ## This is an alterantive to using bind_template_child(id)
              ## in Ruby-GNOME, such that resuilts in an attr_reader method
              ## being defined with the same name as the template child
              ## ID. That method may silently return nil, when
              ## bind_template_child(id) is called for an id that does not
              ## exist in the template.
              ##
              ## Similar to Ruby-GNOME Gtk::Widget.bind_template_child,
              ## this method will cache the child in an instance varaible
              ## once the template child object is initialized in the Ruby
              ## environment
              ##
              ## FIXME while this provides some tests, but any error
              ## reported from a template child method from here may not
              ## be actually accurate to any errors in the
              ## instance/template binding.
              ##
              ## TBD when Debug, cache an XML stream for the template and
              ## a table of id to some-object mappings derived from that
              ## XML stream. err if no matching id is found in the XML
              bind_template_child_full(id, true, 0)

              var = (Const::INSTANCE_PREFIX + id).to_sym

              ## define the accessor method here, with added checks
              lmb = lambda {
                if instance_variable_defined?(var)
                  instance_variable_get(var)
                elsif (obj = get_internal_child(builder, id))
                  instance_variable_set(var, obj)
                else
                  raise UIError.new("No template child found for id #{id} \
in template for #{self.class} at #{path}")
                end
              }
              define_method(id, &lmb)
              template_children.push(id)
            end ## template_child?
          end ## each
          ## bind signal handlers for this class, conditionally
          ##
          ## This will err within the class' connect func e.g if a signal
          ## handler is defined in the UI file without a corresponding
          ## method in this class. Albeit, the error message will
          ## generally not represent the actual missing template child -
          ## it would typically follow a critical message from the GTK
          ## framework, with the actual missing template child
          ## identified there.
          ##
          ## The block defined in set_composite_connect_func may be
          ## evaluated during UI initialization
          set_composite_connect_func()
          return true
        end ## initialize_template_children
      end ## class <<
    end ## self.extended
  end

  ## mixin module for classes using a template definition for
  ## GTK Widget classes, when the template is initialized directly from a
  ## UI file source
  ##
  ##
  ## This module, in effect, extends the CompositeWidget mixin module
  ##
  ## In addition to class methods defined with CompositeWidget, the
  ## following methods will be defined within a class scope in the
  ## extending class:
  ##
  ## - use_template(filename, children)
  ##
  ##   Provided with a template filename and an optional array of string
  ##   ID values for template children, this method will ensure that the
  ##   UI file is bound as the UI template for the extending class, with
  ##   an instance reader method defined as corresponding to each
  ##   template child ID.
  ##
  ##
  module FileCompositeWidget
    def self.extended(whence)
      whence.extend CompositeWidget

      ## initialize a file-based template for this class, using the class
      ## constant TEMPLATE to determine the template file's pathname
      def use_template(filename, children = false)
        register_type
        if File.exists?(filename)
          ## See also
          ## - Gio::File @ gem gio2 lib/gio2/file.rb
          ## - File, GInputStream, GFileInputStream topics under GNOME devhelp
          gfile = false
          fio = false
          path = File.expand_path(filename)
          begin
            gfile = Gio::File.new_for_path(path)
            fio = gfile.read
            nbytes = File.size(filename)
            bytes = fio.read_bytes(nbytes)
            PebblApp::AppLog.debug(
              "Setting template data for #{self} @ #{filename}"
            ) if $DEBUG
            self.set_template(data: bytes)
          ensure
            fio.unref() if fio
            gfile.unref() if gfile
          end
        else
          raise "Template file does not exist: #{filename}"
        end
        if children
          bld = composite_builder
          self.initialize_template_children(children, path: path, builder: bld)
        end
        return path
      end ## whence.use_template
    end
  end
end
