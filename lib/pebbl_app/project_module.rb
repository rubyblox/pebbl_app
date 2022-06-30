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
## relative to a module's source directory, for a module A including
## this module in the definition of module A.
##
## Example source code, for a file `app_module.rb` under some Ruby
## library path:
##
## ~~~~
## gem 'pebbl_app-project'
## require 'pebbl_app/project/project_module'
##
## module AppModule
##   include PebblApp::Project::ProjectModule
##   self.source_path = __dir__
##   defautoloads({'app_module/app' => %w(App AppClass AppError)})
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
##   include PebblApp::Project::ProjectModule
##   self.source_path = __dir__
##   begin
##     autoloads_defer = true
##     defautoloads({%(app_module/app} => %w(App AppClass AppError)})
##     # ... critical section of code...
##   rescue
##     autoloads_defer = false
##     autoloads_apply
##   end
## end
## ~~~~
##
## **Changing the Module Source Path**
##
## Autoload definitions for the including module can be declared
## with pathanmes relative to some pathname other than the original
## source_path for the including module, by setting the source_path
## on the module before any subsquent defautoloads calls. Example:
## ~~~~
## AppModule.source_path = File.expand_path(other_dir)
## ~~~~
##
## The source path for the including module may be accessed with the
## `source_path` method on that module, e.g
## ~~~~
## AppModule.source_path
## ~~~~
##
## In any call to the methods `defautoload`, `defautoloads`, or
## `defautoloads_file` on the including module, all pathnames provided or
## interpolated in the call will be stored as expanded relative to the
## source_path of the calling module at the time of that method call,
## when the source_path is configured for a value other than nil or
## false.
##
## If the source_path is configured to a value of nil or false at the
## time of calling the respective defautoloads method, then any relative
## pathname provided to the method will be stored for the eventual call
## to autoload.
##
## If the source_path is nil or false at the time when autoload would be
## called, no autoloads will be declared. This would affect any call
## to  `defautoload`, `defautoloads`,  `defautoloads_file`, or
##`autoloads_apply` when autoloads are not deferred.
##
## Modules inlcuding this module should ensure that the source_path for
## each including module is configured before any autoloads are defined.
##
## **Known Limitations**
##
## Due to behaviors of the `Kernel.const_source_location` method for
## constants declared under `autoload` within some containing namespace,
## the `source_path` should be configured directly in any module
## including this module, for example:
##
## ~~~~
## module AppModule
##   include PebblApp::Project::ProjectModule
##   self.source_path = __dir__
##   defautoloads({%(app_module/app} => %w(App AppClass AppError)})
## end
## ~~~~
##
## In this example, the module's `source_path` is set to the filesystem
## directory of the source file where the module is defined.
##
## This would serve to work around a behavior in the method
## `Kernel.const_source_location` in Ruby versions 2.7 and later, such
## that the method would return a non-falsey source location value, yet
## including a pathname value of false, e.g `[0, false]`. This may occur
## for any constant declared originally  with `autoload` in some
## containing namespace. The same value may be returned even after the
## constant has been defined in some Ruby source file. This is known to
## affect Ruby releases up to and including Ruby 3.1.2.
##
## For appliations of `PebblApp::Project::ProjectModule`, there is a
## known workaround as to directly set the `source_path` for any
## including module.
##
## **Compatibility**
##
## This defautoloads implementation uses the Ruby `const_source_location`
## method internally. This requires a Ruby implementation version 2.7 or
## later.
##
## The **ProjectModule** module may be applied for autoload declarations
## within a module definition or within a class definition.
##
## The primary configuration would be in evaluating:
##
## > `include PebblApp::Project::ProjectModule`
##
## ... as within a containing namespace, i.e. within a module or class
## definition. This would ensure that the `defautoloads` methods
## illustrated above would be available as defined within the including
## module.
##
## As denoted in the previous, the `source_path` should be set directly
## for any module or class applying `PebblApp::Project::ProjectModule`
## by way of include.
##
## A module or class definition may override any methods defined by
## including this module.
##
module PebblApp::Project::ProjectModule

  ## Constants for PebblApp::Project::ProjectModule
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

    ## return the source location filename for this module as a string,
    ## or raise a RuntimeError if no source location information is
    ## available
    ##
    ## This method requires Ruby 2.7 or later
    def source_file()
      location = Kernel.const_source_location(self.to_s, true)
      if location
        ## This may return false under a situation of when the including
        ## module requires a file for a containing module, such that
        ## the containing module defines an autoload for the including
        ## module. FIXME this breaks the autoload mechanism, if Ruby
        ## has not yet set the source location file for the including module.
        return location[0]
      else
          Kernel.warn("No source location available for %s %p" % [self.class, self],
                      uplevel: 1) if $DEBUG
          return false
      end
    end

    ## return the configured source path for this module
    ##
    ## FIXME dispatch this method on a source_file call
    ## such that can be used during the autoload automation
    ## to locally defer autoloads mapping to the source_file
    ## for a module in which the defautoloads form is being called
    def source_path()
      if self.instance_variable_defined?(:@source_path)
        @source_path
      else
        file = self.source_file
        if file
          source_dir = File.dirname(file)
          self.instance_variable_set(:@source_path, source_dir.freeze)
        else
          Kernel.warn("No source file available for %s %p" % [self.class, self],
                      uplevel: 1) if $DEBUG
          return false
        end
      end
    end

    ## configure a `source_path` for this module
    ##
    ## example:
    ##
    ##   self.source_path = __dir__
    ##
    def source_path=(dir)
      @source_path = dir
    end


    ## return a non-false value if this module is configured to defer
    ## autoload declarations in subsequent defautoload calls
    ##
    ## see also
    ## - autoloads_defer=
    def autoloads_defer
      @autoloads_defer ||= false
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

    ## If `path` is provdied as a relative pathname, return a string
    ## for that path expanded as relative to this module's source
    ## path, if the module is configured with a non-falsey source path
    ## at time of call.
    ##
    ## If `path` is an absolute pathname or this method is called when a
    ## falsey source_path is configured for the module, no pathname
    ## expansion will be provided other than to ensure that a suffix
    ## ".rb" is used for the provided filename.
    ##
    ## The returned pathname will have the suffix ".rb" appended, if
    ## that suffix is not already present in the provided `path`
    def autoload_source_path(path)
      if (dir = self.source_path)
        ## source path available at time of call - expand the filename
        ## at now
        usepath = File.expand_path(path, dir)
      else
        ## no source_path available
        ##
        ## a warning should be emitted if the including module's
        ## source_path does not have a pathname value when autoload_call
        ## is called, if $DEBUG has a truthy value at then
        usepath = path
        ## and FIXME defer autoload
      end
      sfx = PebblApp::Project::ProjectModule::Const::SOURCE_SUFFIX
      sfxlen = sfx.length
      if (path.length <= sfxlen) || (path[-sfxlen..] != sfx)
        usepath = usepath + sfx
      end
      return usepath
    end

    ## a default s_to_filename method. This method's initial definition
    ## may be overridden by any including module, such as when a
    ## localized syntax should be applied for interpolating a file name
    ## from a symbol name.
    ##
    ## This method will calls PebblApp::Project::ProjectModule.s_to_filename(s, delim)
    ## with the provided argument values.
    ##
    ## This method will be used for filename interpolation in calls to
    ## `defautoloads` that have not provided a direct filename.
    def s_to_filename(s, delim = PebblApp::Project::ProjectModule::Const::DASH)
      PebblApp::Project::ProjectModule.s_to_filename(s, delim)
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

    ## define autoloads for each name in names, to be autoloaded from
    ## the provided file.
    ##
    ## If the file is provided as a relative pathname, the pathname will
    ## be expanded as relative to this module's present `source_path`, if
    ## the `source_path` is available at time of call.
    ##
    ## see also:
    ## - defautoloads, defautoload
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    ## - source_path, source_path=
    def defautoloads_file(file, names)
      case names
      when Array
        ## names provided as an iterable sequence for a single file
        path = self.autoload_source_path(file)
        names.each do |name|
          self.defautoload(path, name)
        end
      else
        ## assuming that the names value is a single symbol or string
        path = self.autoload_source_path(file)
        self.defautoload(path, names)
      end
    end

    ## define autoloads for each name in names, to be autoloaded from
    ## a file whose name determined by the s_to_filename method,
    ## relative to any `source_path` for this module a time of call
    ##
    ## Each element provided in `names` may represent a symbol name as a
    ## string or a symbol, a hash table of file mapping file names to
    ## arrays of symbol names, or as an array of symbol names. The same
    ## syntax should be used  throughout the NAMES value, in each call
    ## to this method.
    ##
    ## If NAMES is provided in a syntax absent of a filename, then the
    ## filename for autoloading each symbol will be interpolated from
    ## each symbol's name using the s_to_filename method. This file name
    ## will be interpreted as relative to the source_path for this
    ## module.
    ##
    ##
    ## Example:
    ## ~~~~
    ## module AppModule
    ##   include PebblApp::Project::ProjectModule
    ##   self.source_path = __dir__
    ##   defautoloads({'app_module/app' => %w(App AppClass AppError)})
    ## end
    ## ~~~~
    ##
    ## see also:
    ## - defautoloads_file, defautoload
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    ## - source_path, source_path=
    def defautoloads(*names)
      case names[0]
      when Hash
        ## assuming every element in names is a hash, here
        ## e.g reached from
        ##  defautoloads({ filename => %w(SymbolName ...), ... })
        names.each do |sub|
          sub.each do |file,names|
            self.defautoloads_file(file, names)
          end
        end
      when Enumerable
        ## applying the names value as a sequence of other enumerable
        ## values. recurse onto each
        names.each do |sub|
          self.defautoloads(sub)
        end
      else
        ## parsing the names value as an array of defautoload symbol names
        ## whose interpolated filename should each match a file in the
        ## source directory for this module
        names.each do |name|
          fname = s_to_filename(name, delim: File::SEPARATOR)
          path = self.autoload_source_path(fname)
          self.defautoload(path, name)
        end
      end
    end

    ## declare that the constant `name` will be defined when the
    ## specified `file` is loaded.
    ##
    ## If the file is provided as a relative pathname, the pathname will
    ## be expanded as relative to this module's present `source_path`,
    ## when available.
    ##
    ## If no `source_path` is available for the module at time of call,
    ## this method will not declare any autoloads.
    ##
    ## For consistency with the defautoloads_file method, this method
    ## provides a method signature with arguments in reverse order, in
    ## contrast to Kernel.autoload.
    ##
    ## see also:
    ## - defautoloads_file, defautoloads
    ## - autoloads_apply
    ## - autoloads_defer, autoloads_defer=
    ## - source_path, source_path=
    def defautoload(file, name)
      s = name.to_sym
      path = self.autoload_source_path(file)
      self.autoloads[s] = path
      ## conditional dispatching per source_path is handled in call_autoload
      self.call_autoload(path, name) if ! self.autoloads_defer
    end

    ## This method provides a method signature generally compatible with
    ## `Module.autoload`, with pathname expansion for the provided file
    ## name when available.
    ##
    ## This method will not store the provided filename in the autoloads
    ## table for this module
    ##
    ## This method will dispatch to self#autoload regardless of the
    ## value of self#autoload_defer
    ##
    ## If self#source_path returns a truthy value when this method is
    ## called, that source path will be used as a directory for
    ## expanding any relative +file+ path. Otherwise, the autoload will
    ## be skipped.
    ##
    ## This method will produce some informative output via
    ## `Kernel.warn` when `$DEBUG` is defined to a truthy falue.
    def call_autoload(file, name)
      if self.const_defined?(name)
        Kernel.warn("#{self}::#{name} already defined, not autoloading",
                    uplevel: 1) if $DEBUG
        return false
      else
        usedir = self.source_path
        if usedir
          usepath = File.expand_path(file, usedir)
          if ! File.exists?(usepath)
            Kernel.warn(
              "Defininig autoload for %s::%s with a nonexistent file %p" % [
                self, name, usepath
              ], uplevel: 1)
          end
          ## FIXME initialize and use a debug logger channel
          ## see alternately: logging in Rails
          Kernel.warn("autoloading #{self}::#{name} path #{usepath.inspect}",
                      uplevel: 1) if $DEBUG
          ## FIXME the simple presence of the autoload call in this
          ## source file may affect the const_source_location for the
          ## autoloaded name.
          self.autoload(name, usepath)
        else
          Kernel.warn(
            "Not autoloading %1$s::%2$s with no source_path for %3$s %1$s" % [
              self, name, self.class
            ], uplevel: 1) if $DEBUG
          return false
        end
      end
    end

    ## ensure that each autoload definition in this module's autoloads
    ## table will be declared as with the method Module.autoload
    ##
    ## see also:
    ## - autoloads_defer, autoloads_defer=
    ## - autoloads
    ## - defautoloads_file, defautoloads, defautoload
    def autoloads_apply
      self.autoloads.each do |name, file|
        self.call_autoload(file, name)
      end
    end

    ## reduce memory usage for this module, removing each element of the
    ## autoloads table and freezing the autoloads table, before calling
    ## the method super
    ##
    ## This method will freeze definitions for classes and modules
    ## defined within the module's namespace. Applications should ensure
    ## that all source files required for this module at runtime will
    ## have been evaluted, moreover that all runtime class amd module
    ## definitions for this module and for any classes or modules
    ## referencing this module will have been completed before calling
    ## this method.
    def freeze()
      self.autoloads.keys.each do |name|
        self.autoloads.delete(name)
      end
      self.autoloads.freeze
      super()
    end

    end ## class << whence
end


end ## ProjectModule
