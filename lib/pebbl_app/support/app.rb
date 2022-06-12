## Definition of PebblApp::Support::App

require 'pebbl_app/project/project_module'
require 'pebbl_app/support'

require 'open3'
require 'optparse'

## :nodoc: Goals
## [X] provide support for pathname handling for applications
## [ ] provide support for parsing of application configuration data
##     in a YAML syntax, from directories configured per project
##     (e.g GEMFILE dir), per user (using XDG dirs) and per application
##     (also using XDG dirs)
## [ ] provide support for storing configuration data to a YAML syntax

## provides general compatbility with the XDG Base Directory
## Specification.
##
## More info:
## https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
class PebblApp::Support::App

  ## Constants for PebblApp::Support::App
  module Const
    NULL_ARRAY ||= [].freeze
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
    ## e.g under "/usr/local" on FreeBSD or "/usr/pkg" on NetBSD. During
    ## package installation tasks, this prefix path may be furthermore
    ## configured within the runtime environment, e.g using a PREFIX
    ## environment variable
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
        raise PebblApp::Support::EnvironmentError.new("No HOME available in environment")
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
      envdir(Const::XDG_STATE_HOME_ENV) do
        return File.join(self.home, Const::XDG_STATE_SUBDIR)
      end
    end

    def tmpdir
      envdir(Const::TMPDIR_ENV) do
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
        if !File.exists(rundir)
          PebblApp::Support::Files.mkdir_p(rundir)
          File.chmod(0o0700, rundir)
        end
        return rundir
      end
    end

    def username
      if envname = ENV[Const::USER_ENV]
        return envname
      else
        ## portable whoami(1)
        begin
          who_str, err_str, st = Open3::capture3(Const::WHOAMI_CMD)
          if st.exitstatus.eql?(0)
            ## on MS Windows, 'whoami' with no args produces a name of a
            ## syntax e.g "domain\user". On this same platform, "/" is
            ## typically the file pathname separator, so calling basename
            ## here should serve to return the actual username
            ##
            ## FIXME this needs test with ruby under mingw, where ideally a
            ## POSIX-like 'whoami' would be available under PATH
            return File.basename(who_str.chomp)
          else
            raise PebblApp::Support::EnvironmentError.new(
              "Unable to determine username. Shell command %p failed (%d): %p" % [
                Const::WHOAMI_CMD, st.exitstatus, err_str
              ])
          end
        rescue SystemCallError => e
          raise PebblApp::Support::EnvironmentError.new(
            "Failed when calling %p : %s" % [Const::WHOAMI_CMD, e]
          )
        end
      end
    end

    protected

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

  end ## class << self

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
    using = PebblApp::Project::ProjectModule
    const = PebblApp::Support::App::Const
    @app_name ||= using.s_to_filename(self.class, const::DOT)
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
    dirs = self.class.flatten_dirs(self.class.data_dirs)
    ## FIXME this assumes that any of the dirs would be created
    ## during install, if the dir was to exist and contain any files
    ## for the app
    self.class.flatten_dirs(self.class.map_join(self.app_dirname, dirs))
  end

  def app_config_dirs()
    dirs = self.class.flatten_dirs(self.class.config_dirs)
    ## FIXME this assumes that any of the dirs would be created
    ## during install, if the dir was to exist and contain any files
    ## for the app - siimlar to the data_dirs instance
    self.class.flatten_dirs(self.class.map_join(self.app_dirname, dirs))
  end

  def app_menu_dirs()
    dirs = self.class.flatten_dirs(using.config_dirs)
    ## FIXME similar to the config_dirs instance, from which this derives
    self.class.flatten_dirs(self.class.map_join(Const::MENUS, dirs))
  end

  def app_config_home()
    File.join(self.class.config_home, app_dirname)
  end

  ## return the value of #app_config_home,
  ## ensuring the directory exists
  def app_config_home!()
    dir = app_config_home
    PebblApp::Support::Files.mkdir_p(dir)
    return dir
  end

  def app_state_home()
    File.join(self.class.state_home, app_dirname)
  end

  ## return the value of #app_state_home,
  ## ensuring the directory exists
  def app_state_home!()
    dir = app_state_home
    PebblApp::Support::Files.mkdir_p(dir)
    return dir
  end

  def app_cache_home()
    File.join(self.class.cache_home, app_dirname)
  end

  ## return the value of #app_cache_home,
  ## ensuring the directory exists
  def app_cache_home!()
    dir = app_cache_home
    PebblApp::Support::Files.mkdir_p(dir)
    return dir
  end

  def app_runtime_dir!()
    basedir = self.class.runtime_dir!
    dir = File.join(basedir, app_dirname)
    if !File.exists(rundir)
      PebblApp::Support::Files.mkdir_p(dir)
      File.chmod(0o0700, dir)
    end
    return dir
  end

  ## return a configuration object for this application
  def config
    @config ||= PebblApp::Support::Config.new
  end

  ## configure this application
  ##
  ## the provided argv may be destructively modified by this method
  def configure(argv: ARGV)
    config.configure(argv: ARGV)
  end

  ## activate the application
  ##
  ## The method provided here will pass the provided argv array to
  ## #configure.
  ##
  ## the provided argv may be destructively modified by this method
  def activate(argv: ARGV)
    configure(argv: argv)
    ## reduce memory usage, clearing the module's original autoloads
    ## definitions
    PebblApp::Support.freeze unless self.config.option(:defer_freeze)
  end

end


