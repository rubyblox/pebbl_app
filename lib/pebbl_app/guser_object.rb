## GUserObject

require 'pebbl_app/gtk_framework'

module PebblApp

  ## Prototype for GLib type extension support
  module GUserObject

    def self.extended(whence)
      ## TBD see also https://developer-old.gnome.org/SubclassGObject/
      class << whence

        ## register the class, at most once
        ##
        ## The implementing class should ensure that this method is
        ## called before any instance of the class is initialized
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
    end ## extended
  end

end
