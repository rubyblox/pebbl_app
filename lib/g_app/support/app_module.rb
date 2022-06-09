## app_module.rb --- Definition of GApp::Support::AppModule

## modules, autoloads
require 'g_app/support'

## earlier protototype:
## ./apploader_gtk.rb

require 'open3'

## Goals
## - provide support for pathname handling for applications
## - provide support for runtime configuration for applications,
##   under some YAML syntax for application configuration
## - provide support for creating XDG desktop files
##   as typically during application installation
##
## Far-term goals
## - provide support for application packaging
## - provide support for issue tracking for applications
module GApp::Support::AppModule

  ## 1. compute a timeout for Gtk.init
  ## 2. compute a default display for Gtk.init
  ##    and emit a warning if no display can be determined
  ## 3. call Gtk.init with locally derived args
  ##    assuming Gtk.init handles args like in GTK 3 for now
  ##
  ## TBD before Gtk.init: Initialize a logger, ideally such that would
  ## also be used under GTK and such that could be mapped to a PTY
  ## and/or to a file

  ## this needs to access a configuration context from outside of
  ## anything that would be initilized under Ruby with Gtk.init
  ## this << MOAR THE YAML
  ##  0) --arbitrary_args under ARGV
  ##  1) YAML under a user xdg path for (TBD) "This App"
  ##  2) YAML under the gemspec's full dir for a gemspec providing "This app's sources"

  ## Constants for GApp::Support::AppModule
  module Const
    NULL_ARRAY ||= [].freeze
    NS_DELIM ||= "::".freeze
    DOT ||= ".".freeze
    MENUS ||= "menus".freeze
    HOME_ENV ||= "HOME".freeze
    TMPDIR_ENV ||= "TMPDIR".freeze
    TMPDIR ||= "/tmp".freeze
    USER_ENV ||= "USER".freeze
    WHOAMI_CMD ||= "whoami".freeze

    XDG_DATA_DIRS_ENV ||= "XDG_DATA_DIRS".freeze
    XDG_CONFIG_DIRS_ENV ||= "XDG_CONFIG_DIRS".freeze

    XDG_DATA_HOME_ENV ||= "XDG_DATA_HOME".freeze
    XDG_CONFIG_HOME_ENV ||= "XDG_CONFIG_HOME".freeze
    XDG_STATE_HOME_ENV ||= "XDG_STATE_HOME".freeze
    XDG_CACHE_HOME_ENV ||= "XDG_CACHE_HOME".freeze

    XDG_RUNTIME_DIR_ENV ||= "XDG_RUNTIME_DIR".freeze
    XDG_STATE_HOME_ENV ||= "XDG_STATE_HOME".freeze

    XDG_DATA_SUBDIR ||= ".local/share".freeze
    XDG_CONFIG_SUBDIR ||= ".local/config".freeze
    XDG_STATE_SUBDIR ||= ".local/state".freeze
    XDG_CACHE_SUBDIR ||= ".cache".freeze

    ## :nodoc: a divergence from the XDG base directory specification:
    ## this usses File::PATH_SEPARATOR, not per se ":", for delimiting
    ## pathnames in the default XDG_DATA_DIRS value
    DATA_DIRS_DEFAULT ||= %w(/usr/local/share /usr/share).join(File::PATH_SEPARATOR).freeze

    ## :nodoc: FIXME This is the standard default for XDG_CONFIG_DIRS value
    ## but would not be applicable on most BSD operating systems, such
    ## that would use an "etc/xdg" subdirectory under some prefix path,
    ## e.g under "/usr/local" on FreeBSD, or under one of a modular X
    ## Windows subdir or "/usr/pkg" on NetBSD. This prefix path
    ## may typically be configured within the runtime environment, e.g
    ## using a PREFIX environment variable.
    CONFIG_DIRS_DEFAULT ||= "/etc/xdg".freeze
  end

  ## :nodoc: FIXME none of the following methods have been defined with
  ## any particular attention for conventions on Microsoft Windows platforms,
  ## excepting the username method.
  ##
  ## Generally this assumes a POSIX-like ruby environment

  class << self
    def data_dirs
      envdir(Const::XDG_DATA_DIRS_ENV) do
        Const::DATA_DIRS_DEFAULT
      end.split(File::PATH_SEPARATOR)
    end

    def config_dirs
      envdir(Const::XDG_CONFIG_DIRS_ENV) do
        Const::CONFIG_DIRS_DEFAULT
      end.split(File::PATH_SEPARATOR)
    end


    def home
      envdir = ENV[Const::HOME_ENV]
      if envdir
        return envdir
      else
        raise "No HOME available in environment"
      end
    end

    def data_home
      envdir(Const::XDG_DATA_HOME_ENV) do
        return (File.join(self.home, Const::XDG_DATA_SUBDIR))
      end
    end

    def config_home
      envdir(Const::XDG_CONFIG_HOME_ENV) do
        return (File.join(self.home, Const::XDG_CONFIG_SUBDIR))
      end
    end

    def cache_home
      envdir(Const::XDG_CACHE_HOME_ENV) do
        return (File.join(self.home, Const::XDG_CACHE_SUBDIR))
      end
    end

    def state_home
      envdir = ENV[Const::XDG_STATE_HOME_ENV]
      if envdir && File.exists?(envdir)
        return env
      else
        return File.join(self.home, Const::XDG_STATE_SUBDIR)
      end
    end

    def tmpdir
      envdir = ENV[Const::TMPDIR_ENV]
      if envdir && File.exists?(envdir)
        return env
      else
        return Const::TMPDIR
      end
    end

    ## Return a directory suitable as XDG_RUNTIME_DIR, creating the
    ## directory if it does not exist
    def runtime_dir!
      ## FIXME offer a pedantic mode to check file permissions before
      ## returning any existing directory path
      envd = ENV[Const::XDG_RUNTIME_DIR_ENV]
      if envd && File.exists?(envd) && File.owned?(envd)
        return envd
      else
        ## produce a reasonable workaround, assuming that the directory
        ## returned by self.tmpdir exists and is writable by the user
        ##
        ## this does not provide a fully compliant XDG Base Directories
        ## implementation. Nothing here will ensure that the runtime
        ## dir is claned up after the user's last logout during any
        ## single uptime session on the host. This should be generally
        ## portable, regardless.
        run_subdir = format("run-%d", Process.uid)
        rundir = File.join(self.tmpdir, run_subdir)
        n = 0
        while File.exists(rundir) && !File.owned?(rundir)
          rundir = rundir + Const::DOT + n
          n = n + 1
        end
        Dir.mkdir(rundir, 0o0700) if !File.exists(rundir)
        return rundir
      end
    end

    def username
      if envname = ENV[Const::USER_ENV]
        return envname
      else
        ## portable whoami(1)
        who_str, err_str, st = Open3::capture3(Const::WHOAMI_CMD)
        if st.exitstatus.eql?(0)
          ## on MS Windows, 'whoami' with no args produces a name of a
          ## syntax e.g "domain\user". On this same platform, "/" is
          ## typically the file pathname separator, so calling basename
          ## here should serve to return the actual username
          ##
          ## FIXME this needs test with ruby under mingw, where ideally a
          ## POSIX-like 'whoami' would be available under PATH
          return File.basename(who_str)
        else
          raise "Unable to determine username. Shell command %p failed (%d): %p" % [
            Const::WHOAMI_CMD, st.exitstatus, err_str
          ]
        end
      end
    end


    def envdir(envar, &fallback)
      if envdir = ENV[envar]
        return envdir
      else
        fallback.yield(envar) if block_given?
      end
    end

    def map_join(name, dirs)
      dirs.map do |p|
        File.join(p, name)
      end
    end

    def flatten_dirs(dirs)
      dirs.flat_map do |d|
        if File.directory?(d)
          d
        else
          self::Const::NULL_ARRAY
        end
      end
    end

  end

  def self.included(whence)
    class << whence

      ## return the app name for this module
      ##
      ## If no app name has been configured as with app_name= then a
      ## default app name will be initialized from the module's name
      ## with each Ruby namespace string "::" translated to a full stop
      ## character, ".".
      ##
      ## @return [String] an app name
      ##
      ## @see app_name=
      def app_name
        using = GApp::Support::AppModule::Const
        @app_name ||= self.name.split(using::NS_DELIM).join(using::DOT)
      end

      ## configure an app name for this module
      ##
      ## @param name [String] the app name to use
      ##
      ## @return [String] the provided name
      ##
      ## @see app_name
      def app_name=(name)
        @app_name = name
      end

      def app_dirname
        app_name.downcase
      end

      def app_data_dirs()
        using = GApp::Support::AppModule
        dirs = using.flatten_dirs(using.data_dirs)
        ## FIXME this assumes that any of the dirs would be created
        ## during install, if the dir was to exist and contain any files
        ## for the app
        using.flatten_dirs(using.map_join(self.app_dirname, dirs))
      end

      def app_config_dirs()
        using = GApp::Support::AppModule
        dirs = using.flatten_dirs(using.config_dirs)
        ## FIXME this assumes that any of the dirs would be created
        ## during install, if the dir was to exist and contain any files
        ## for the app - siimlar to the data_dirs instance
        using.flatten_dirs(using.map_join(self.app_dirname, dirs))
      end

      def app_menu_dirs()
        using = GApp::Support::AppModule
        dirs = using.flatten_dirs(using.config_dirs)
        ## FIXME similar to the config_dirs instance, from which this derives
        using.flatten_dirs(using.map_join(using::Const::MENUS, dirs))
      end

      ## FIXME in each of the *_home! methods below,
      ## recursively create all nonexistent parent dirs
      ## using the process' active umask

      def app_config_home()
        using = GApp::Support::AppModule
        File.join(using.config_home, app_dirname)
      end

      ## return the vlaue of #app_config_home,
      ## ensuring the directory exists
      def app_config_home!()
        dir = app_config_home
        Dir.mkdir(dir) if !File.exists(dir)
        return dir
      end

      def app_state_home()
        using = GApp::Support::AppModule
        File.join(using.state_home, app_dirname)
      end

      ## return the vlaue of #app_state_home,
      ## ensuring the directory exists
      def app_state_home!()
        dir = app_state_home
        Dir.mkdir(dir) if !File.exists(dir)
        return dir
      end

      def app_cache_home()
        using = GApp::Support::AppModule
        File.join(using.cache_home, app_dirname)
      end

      ## return the vlaue of #app_cache_home,
      ## ensuring the directory exists
      def app_cache_home!()
        dir = app_cache_home
        ## FIXME this and the previous will not recursively create the dirs
        Dir.mkdir(dir) if !File.exists(dir)
        return dir
      end

      def app_runtime_dir!()
        using = GApp::Support::AppModule
        basedir = using.runtime_dir!
        dir = File.join(basedir, app_dirname)
        Dir.mkdir(dir, 0o700) if !File.exists(dir)
        return dir
      end

    end ## class << whence
  end

  ## this cannot be usefully conducated in any method on app's gemspec
  ## as the Gem::Specification class may not be an extensible class
  ## - not in #activate
  ## - and not even in a new #run method if the new #run method must
  ##   necesarily dispatch on any singleton method on a gemspec
  ##   created during gemspec init (when that gemspec is not what the
  ##   gem architecture is actually using for the named gem)

  ## This class, in itself, will not provide any special handling onto
  ## GLib::MainLoop, GLib::MainLoop#context,
  ## or for ctxt = MainLoop#context;
  ##    ctxt.iteration, ctxt.acquire, ctxt.prepare, ctxt.query,
  ##    ctxt.check, and ctxt.disaptch
  ## etc ...


end


