## glib_type_ext.rb - type extensions for GLib

require 'pebbl_app/gtk_framework'

require 'glib2'

## Extension module for classes defining a new subtype of
## GLib::Object (GObject)
##
## When used in a class definition +c+ via *+Module.extend+*, this module
## will define the following methods in the extending class +c+:
##
## - *+c.register_type+* will call +c.type_register+ exactly once for the
##   extending class
##
## - *+c.type_registered?+* if class' type has already been
## registered to *GLib*, returns the class as registered, else
## returns false
##
## When extending this module in a class definition, the
## extending class' *+register_type+* method should be called
## when the class is defined.
##
## Example
##
##    class ExtObject < GLib::Object
##      extend GObjType
##      self.register_type
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
module PebblApp::GObjType
  def self.extended(extclass)

    class << extclass
      ## return a value indicating whether this class has been
      ## registered
      ##
      ## If this class has been registered, returns the
      ## class as registered, else returns false.
      ##
      ## @see register_type
      def type_registered?()
        if class_variable_defined?(:@@registered)
          ## class variables & instance variables DNW (??)
          class_variable_get(:@@registered)
        else
          false
        end
      end

      ## ensure that the type_register class method is called
      ## exactly once, for this class
      ##
      ## @see type_registered?
      ## @see GLib::Object::type_register
      def register_type()
        if (rrecord = type_registered?)
          Kernel.warn("#{self} already registered with type_register",
                      uplevel: 1) if $DEBUG
          return rrecord
        else
          type_register
          class_variable_set(:@@registered, self)
        end
      end
    end ## << extclass
  end ## extended
end


## Local Variables:
## fill-column: 65
## End:
