## basedir.rb - API for application base directory handling

## This source file provides the following methods, such that may
## be applied for purpose of setting and accessing an application
## base directory within any one or more Ruby classes.
##
## * Rationale *
##
## This API was designed originally for use in loading Glade UI
## XML files during class initialization. It was assumed that the
## API would be applied for two primary usage cases;
##
## - Class initialization within a development environment
## - Class initialization with a Ruby Gems environment.
##
## In the second usage case, the application base directory may
## be set from within a Gem script file (bin file)
##
## In the first usage case, the application base directory should
## be set automatically from some known pathname, such as with a
## pathname relative to the source path of a file for some known
## class definition.
##
## With either usage case, this API may be used in either of the
## following two methodologies, within any single application
##
## - Setting a base directory that should not be modified after set.
##
##   Under this methodology, any reader for the value should
##   return the same value in any thread and at any time within
##   the application's lifetime, within any single host process.
##
## - Setting a base directory that can be modified after set,
##
##   Under this methodology, it should be understood that any
##   reader method for the value may return a unique value, as
##   set at the time of the reader method's call. For any method
##   defining a behavior that would be derived from (directly or
##   by side efect) from the value of the application base
##   directory, it should be understood that the behavior of the
##   method may differ in that quality, in each call to the
##   method.
##
##  In either methodlogy, the pathname returned from the reader
##  method may represent a frozen object.
##
##  In the second methodology, the class storing the pathname
##  should not be frozen while the application may produce any
##  further modifications onto the value storage for the
##  pathname.
##
## * Known Side Effects *
##
## For the most part, this API is defined for a purpose of
## providing some convenience in defining an application that
## must make use of any filesystem resources at a time of class
## initialization.
##
## Beyond the initial utility of this API, the possible
## side-effects may bear consideration for application design, if
## any application class may be defined such that the
## application's base directory may be changed after an initial
## storage of a value for that class property.
##
##
## * Additional Remarks *
##
## In the interest of maintaining consistency for calls to any
## 'require_relative' method, this API will not in itself change
## the host process' current working directory.
##
## An application may modify the host process' current working
## directory, using some user-oriented value other than the
## application's recourse base directory - e.g user home
## directory - independent of this API.

module GAppKit

module FileResourceManager
  def self.extended(extclass)

    ## * Remarks *
    ##
    ## @path will be expanded relative to Dir.pwd at the time
    ## of the call.
    ##
    ## This will not provide any checking for the provided
    ## pathname. The application may create the directory or
    ## provide any pathname checking for the provided resource
    ## path, in the application's own binding environment.
    def extclass.set_resource_root(path, nolock = false)
      if (defined?(@@resource_root_locked) &&
          @@resource_root_locked  && (path != @@resource_root))
        warn ("Cannot set a locked resource root path in %s: " +
              "(ignored) %s") % [self, path.inspect]
        return false
      else
        @@resource_root_locked = !nolock
        @@resource_root = File.expand_path(path)
      end
    end

    def extclass.resource_root()
      ## NB In order to ensure that a pathname is returned for
      ## this class method, this will dispatch to use any
      ## provided block or else PWD if no resource root has been
      ## set.
      ##
      ## Albeit, the pathname returned for a call to this
      ## method may then differ after an initial call to
      ## ::set_resource_root(...). This should nonetheless
      ## serve to prevent an error during class load,
      ## as may occur if the method was to return nil.
      ##
      ## NB anything based on __FILE__ here would be evaluated
      ## as using the source filename of this module, thus
      ## there is this odd semantics for the default value.
      if defined?(@@resource_root)
        return @@resource_root
      elsif block_given?
        yield
      else
        return Dir.pwd
      end
    end

    def extclass.expand_resource_path(name)
      File.expand_path(name, self.resource_root)
    end

  end ## extended
end

end ## GAppKit module

## Local Variables:
## fill-column: 65
## End:
