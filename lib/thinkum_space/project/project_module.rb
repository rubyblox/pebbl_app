## project_module.rb - extended source autoloads support for Ruby

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the containing module is defined when loaded from a
  ## project directory. The module may define autoloads that would be
  ## used in this file.
  require(__dir__ + ".rb")
}

require 'rubygems'


## a support module for inclusion within other project source modules
##
## This module provides support for defining autoloads with filenames
## relative to a module's source directory.
##
## This module may typically be applied as after include from some other
## module.
##
## Example source code, for a file `app_module.rb` under some Ruby
## library path:
##
## ~~~~
## gem 'thinkum_space-project'
## require 'thinkum_space/project/project_module'
##
## module AppModule
##   include ThinkumSpace::Project::ProjectModule
##   defautoloads({%(app_module/app} => %w(App AppClass AppError)})
## end
## ~~~~
##
## Subsequent of calling `require 'app_module'` in another source
## file, then the definitions for  `AppModule::App`, `AppModule::AppClass`, and
## `AppModule::AppError` may then be accessed via Ruby autoloads. In
## this example, those definitions would be assumed to be initialized
## in the file `app_module/app.rb` relative to the filesystem directory
## for the file defining the AppModule module.
##
## **Showing Defautoload Definitions**
##
## The set of autoloads definitions to be applied for an including
## module may be accessed via the `autoloads` method on the including
## module, e.g  `AppModule.autoloads` as in this example.
##
## **Deferred Autoload**
##
## By default, `autoload` will be called immediately within the call to
## any of the methods `defautoloads`, `defautoloads_file`, or
##`defautoload` in the including module. This behavior may be deferred,
## such that `autoload` would be called on the including module's autoload
## map not until after a set of autoload definitions have been
## configured for the including module.
##
## Example:
## ~~~~
## module AppModule
##   include ThinkumSpace::Project::ProjectModule
##   autoloads_defer = true
##   defautoloads({%(app_module/app} => %w(App AppClass AppError)})
##   # ... critical section of code...
##   autoloads_apply
## end
## ~~~~
##
## **Changing the Module Source Path**
##
## If subsequent autoload definitions for the including module should
## be dereferenced as relative to some pathname other than that in which
## the including module was defined, example:
## ~~~~
## AppModule.source_path = File.expand_path(other_dir)
## ~~~~
##
## The source path for the including module may be accessed with the
## `source_path` method on that module, e.g
## ~~~~
##  path =  AppModule.source_path
## ~~~~
##
## The module's source path will be applied at the time of the call to
## e.g `defautoloads`. By default, the source path is configured as
## the directory for the source file of the including module.
##
## **Compatibility**
##
## This defautoloads implementation uses the Ruby `const_source_location`
## method internally. This requires a Ruby implementation version 2.7 or
## later.
##
## The **ProjectModule** module may be applied similarly, for autoload
## declarations within a module definition or within a class definition.
##
## The primary configuration would be in evaluating:
##
## > `include ThinkumSpace::Project::ProjectModule`
##
## ... as within a containing namespace, i.e. within a module or class
## definition. This would ensure that the`defautoloads` methods
## illustrated above would be available as defined within the including
## module.
##
## A module or class definition may override any methods defined by
## including this module.
##
module ThinkumSpace::Project::ProjectModule

  ## Constants used in methods on this module
  module Const
    UPCASE_RE ||= /[[:upper:]]/.freeze
    ALNUM_RE ||= /[[:alnum:]]/.freeze
    UNDERSCORE ||= "_".freeze
    COLON ||= ":".freeze
    DASH ||= "-".freeze
    SOURCE_SUFFIX ||= ".rb".freeze
  end

  class << self

    ## return a string filename for a symbol or string S
    ##
    ## For any uppercase character after the first index in the string
    ## representation of S, the character will be prefixed with an
    ## underscore character, "_", in the return value.
    ##
    ## For any one or more colon characters, ":" that character and any
    ## immediately subsequent colon characters will be interpoloated as
    ## a single instance of the delim argument value, by default "-"
    ##
    ## Other characters in the string representation of S will be added
    ## to the return value using each character's lower-case form.
    ##
    ## The syntax used here for translation of a symbol name to a
    ## filename should be generally congruous the syntax for filename to
    ## symbol name translation as applied under the bundle-gem(1) shell
    ## command e.g with the shell command 'bundle gem a_b_name'
    ## producing a module named "ABName".
    ##
    ## The return value will not be suffixed with any file type.
    ##
    ## Examples:
    ##
    ##   s_to_filename(:ABCName) => "a_b_c_name"
    ##
    ##   s_to_filename("simpleName") => "simple_name"
    ##
    ##   to_filname(:C) => "c"
    ##
    ##   s_to_filename(::String) => "string"
    ##
    ##   s_to_filename("::Module::AppClass", "/")
    ##   => "module/app_class"
    ##
    ## @param s [Symbol, String] the name to translate to a filename
    ## @param delim [String] delimiter string to interpolate for any
    ##        sequence of one or more colon ":" characters in s
    def s_to_filename(s, delim = Const::DASH)
      require 'stringio'
      ## convert s as a string to an array of unicode codepoints
      uu_name = s.to_s.unpack("U*")
      ## buffer for the return value
      io = StringIO.new
      ## booleans for parser state
      inter = nil
      in_delim = nil
      ## parser
      uu_name.each do |cp|
        c  = cp.chr
        if c.match?(Const::UPCASE_RE) && inter
          ## add an underscore character
          ## before any intermediate upcase character
          io.putc(Const::UNDERSCORE)
          in_delim = false
        elsif (c == Const::COLON)
          if inter
            io.write(delim) if !in_delim
          end
          in_delim = true
        else
          in_delim = false
        end
        io.putc(c.downcase) if !in_delim
        inter = c.match?(Const::ALNUM_RE)
      end
      return io.string
    end

  end ## class << self

  ##
  ## methods for use in modules or classes including this module
  ##
  def self.included(whence)

    class << whence

    ## return the configured source path for this module
    ##
    ## This method requires Ruby 2.7 or later
    def source_path()
      if ! self.instance_variable_defined?(:@source_path)
        source_dir = File.dirname(Kernel.const_source_location(self.to_s)[0])
        self.instance_variable_set(:@source_path, source_dir.freeze)
      end
      @source_path
    end

    ## override the source path for this module
    ##
    ## example:
    ##
    ##   self.source_path == __dir__
    ##
    def source_path=(dir)
      @source_path = dir
    end


    ## return a non-false value if this module is presently configured
    ## to defer autoload in defautoload calls
    ##
    ## see also
    ## - autoloads_defer=
    def autoloads_defer
      @autoloads_defer ||= nil
    end


    ## configure this module to defer autoload in subsequent
    ## defautoload calls
    ##
    ## see also
    ## - autoloads_apply, autoloads_defer
    ## - defautoloads_file, defautoloads, defautoload
    def autoloads_defer=(value)
      @autoloads_defer = value
    end

    ## If path is provdied as a relative pathname, return a string
    ## for that path expanded as relative to this  module's source
    ## path. If an absolute pathname, return that pathname as a string.
    ##
    ## The returned pathname will have the suffix ".rb" appended, if
    ## that suffix is not already present in the provided path
    def autoload_source_path(path)
      retpath = File.expand_path(path, source_path)
      ext = File.extname(retpath)
      sfx = ThinkumSpace::Project::ProjectModule::Const::SOURCE_SUFFIX
      if (ext != sfx)
        retpath = retpath + sfx
      end
      return retpath
    end

    ## a default s_to_filename method. This method's initial definition
    ## may be overridden by any including module, such as when a
    ## localized syntax should be applied for interpolating a file name
    ## from a symbol name.
    ##
    ## This method calls ThinkumSpace::Project::ProjectModule.s_to_filename(s, delim)
    ## with the provided argument values.
    ##
    ## This method will be used for filename interpolation in a call to
    ## defautoloads, such as when that the call would not have provided
    ## a literal filename for autoload bindings.
    def s_to_filename(s, delim = ThinkumSpace::Project::ProjectModule::Const::DASH)
      ThinkumSpace::Project::ProjectModule.s_to_filename(s, delim)
    end


    ## return the autoloads table for this module
    ##
    ## see also
    ## - defautoloads_file, defautoloads, defautoload
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    def autoloads()
      @autoloads ||= {}
    end

    def configure_gem(spec)
      autoloads.values.each do |file|
        spec.files << file
      end
    end

    ## define autoloads for each name in names, to be autoloaded from
    ## the provided file.
    ##
    ## If the file is provided as a relative pathname, the pathname will
    ## be expanded as relative to this module's present source_path
    ##
    ## see also:
    ## - defautoloads, defautoload
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    def defautoloads_file(file, names)
      case names
      when Array
        ## names provided as an iterable value for a single file
        path = autoload_source_path(file)
        names.each do |name|
          defautoload(path, name)
        end
      else
        ## assuming that the names value is a single symbol or string
        path = autoload_source_path(file)
        defautoload(path, names)
      end
    end

    ## define autoloads for each name in names, to be autoloaded from
    ## a file whose name is determined by the s_to_filename method.
    ##
    ## Each element provided in NAMES may represent a symbol name as a
    ## string or symbol, a hash table of file to symbol name mappings,
    ## or an array of symbol names. The same syntax should be used
    ## throughout the NAMES value, in each call to this method.
    ##
    ## If NAMES is provided in a syntax absent of a filename, then the
    ## filename for autoloading each symbol will be interpolated from
    ## the symbol name using the s_to_filename method. This file name
    ## will be interpreted as relative to the source_path for this
    ## module.
    ##
    ## see also:
    ## - defautoloads_file, defautoload
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    def defautoloads(*names)
      case names[0]
      when Hash
        ## assuming that every element in names is a hash, here
        ## e.g reached from
        ##  defautoloads({ filename => %w(SymbolName ...), ... })
        names.each do |sub|
          sub.each do |file,names|
            defautoloads_file(file, names)
          end
        end
      when Enumerable
        ## the names value is a sequence of other enumerable values.
        ## recurse onto each
        names.each do |sub|
          defautoloads(sub)
        end
      else
        ## the names value is an array of defautoload symbol names
        ## whose interpolated filename will each match a file in the
        ## source directory for this module
        names.each do |name|
          fname = s_to_filename(name)
          path = autoload_source_path(fname)
          defautoload(path, name)
        end
      end
    end

    ## declare that the constant identified as name will be defined
    ## when the file is loaded.
    ##
    ## If the file is provided as a relative pathname, the pathname will
    ## be expanded as relative to this module's present source_path.
    ##
    ## For consistency with the defautoloads_file method, this method
    ## provides a method signature with arguments in reverse order, in
    ## contrast to Kernel.autoload.
    ##
    ## see also:
    ## - defautoloads_file, defautoloads
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    def defautoload(file, name)
      s = name.to_sym
      path = autoload_source_path(file)
      if !File.exists?(path)
        Kernel.warn(
          "Defininig autoload for %p from a nonexistent file %p" % [
            name, path
          ], uplevel: 0)
      end
      autoloads[s] = path
      autoload(s, path) if !autoloads_defer
    end


    ## ensure that each autoload definition in this module's autoloads
    ## table will be declared as to the method Module.autoload
    ##
    ## see also:
    ## - autoloads_defer, autoloads_defer=
    ## - autoloads
    ## - defautoloads_file, defautoloads, defautoload
    def autoloads_apply
      autoloads.each do |name, file|
        autoload(name, file)
      end
    end

    end ## class << whence
end


end ## ProjectModule
