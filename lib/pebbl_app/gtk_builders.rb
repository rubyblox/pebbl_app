# gtk_type_ext.rb - Utilities for GTK type extension

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

## require the exact gtk version elsewhere
# require 'gtk3'

## Gtk::Builder proxy
module PebblApp::UIBuilder
  def self.extended(extclass)

    ## FIXME also define onto instance variables in self.included
    class << extclass

      ## return a Gtk::Builder initialized for the class scope
      def builder()
        ## FIXME originally a utility for the template support,
        ## but not actually used for template support
        if class_variable_defined?(:@@builder)
          class_variable_get(:@@builder)
        else
          bld = Gtk::Builder.new()
          class_variable_set(:@@builder, bld)
        end
      end

      ## set the class-scoped UI builder, if not already defined
      ##
      ## @param builder [Gtk::Builder] the initial UI builder
      def builder=(builder)
        if class_variable_defined?(:@@builder)
          Kernel.warn("in #{self}: :builder is already bound to #{@@builder}. Ignoring builder #{builder}", uplevel: 1)
        else
          class_variable_set(:@@builder, builder)
        end
      end

      def add_ui_file(file)
        ## FIXME this is a utility  for initial development
        ## - does not use a gresource bundle

        ## NB this assumes that the UI file
        ## does not contain any template decls.
        ##
        ## i.e each object initialized from the file
        ## will be initialized at most once
        ## for this class
        @@builder.add_from_file(file)
      end

      def add_ui_resource(path)
        ## FIXME this assumes that the UI file
        ## does not contain any template decls.
        ##
        ## i.e each object initialized from the file
        ## will be initialized at most once
        ## for this class
        ##
        ## FIXME add calls to validate this when running under bundler
        @@builder.add_from_resource(path)
      end

      def ui_object(id)
        ## NB may return nil (FIXME/NEEDSTEST)
        @@builder.get_object(id)
      end

    end ## class <<
  end ## extended
end

## general-purpose mixin module for TemplateBuilder extension modules
##
## @see ResourceTemplateBuilder
## @see FileTemplateBuilder
module PebblApp::TemplateBuilder
  def self.included(extclass)
    extclass.extend PebblApp::GUserObject
    extclass.extend PebblApp::UIBuilder

    ## set the template path to be used for this class
    ##
    ## @see ResourceTemplateBuilder::init
    ## @see FileTemplateBuilder::init
    def extclass.use_template(path)
      ## FIXME err if the variable is already defined/non-null
      ## and bound to some Gtk/glib object
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
      self.bind_template_child_full(id, true, 0)
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
      raise("Unable to locate internal template child #{id.inspect} in #{self}")
  end
end


module PebblApp::ResourceTemplateBuilder
  def self.extended(extclass)
    extclass.include PebblApp::TemplateBuilder

    ## ensure that a resource bundle at the provided +path+ is
    ## registered at most once, for this class
    ##
    ## @see ::init
    ## @see ::resource_bundle_path
    ## @see ::resource_bundle
    ## @see Gio::resource.load
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

    ## set this class' template, using a configured resource path
    ##
    ## The @template path for this class must provide a
    ## valid resource path onto the resource bundle initialized to this
    ## class [FIXME this needs clarification and testing during development]
    ##
    ## This method extends on Gtk support in Ruby-GNOME
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
      ##
      ## usage testing: riview

      ## NB here, @template must represent a GResource path, not a filename
      set_template(resource: @template)
    end
    extclass.register_type
  end
end

module PebblApp::FileTemplateBuilder
  def self.extended(extclass)
    extclass.include PebblApp::TemplateBuilder

    ## load this class' template as a file
    ##
    ## This method extends on Gtk support in Ruby-GNOME
    ##
    ## @see ::use_template
    def extclass.init
      ## FIXME this pathname expansion needs cleanup
      use_path = File.expand_path(@template)
      if File.exists?(use_path)
        ## NB Gio::File @ gem gio2 lib/gio2/file.rb
        ## File, GFileInputStream topics under GNOME devhelp
        gfile = Gio::File.open(path: use_path)
        fio = false
        begin
          fio = gfile.read
          nbytes = File.size(use_path)
          bytes = fio.read_bytes(nbytes)
          self.set_template(data: bytes)
        ensure
          ## TBD no #unref available for GLib::Bytes here
          fio.unref() if fio
          gfile.unref() if gfile
        end
      else
        raise "Template file does not exist: #{use_path}"
      end
    end
    extclass.register_type
  end
end

# Local Variables:
# fill-column: 65
# End:
