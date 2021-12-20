## glib_type_ext.rb - type extensions for GLib

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

require 'glib2'

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
module GAppKit::GTypeExt
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


## Local Variables:
## fill-column: 65
## End:
