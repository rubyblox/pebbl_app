
require 'pebbl_app'

require 'open3'
require 'optparse'

module PebblApp

  ## FileManager provides access to environment variables and default
  ## values for application pathnames, per the XDG Base Directory
  ## specification. More info:
  ## https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  ## https://wiki.archlinux.org/title/XDG_Base_Directory
  ##
  ## This class also provides support for application pathnames under
  ## each of the XDG home-relative directory paths.
  ##
  ## A FileManager will be available as a utility for application pathname
  ## management in each PebblApp::App
  ##
  class FileManager

    class << self

      ## return an array of strings for the value of the XDG_DATA_DIRS
      ## environment variable, if configured, else using a default value
      ## for that variable
      ##
      ## @return [Array<String>] an array of directory names
      def data_dirs
        envdir(Const::XDG_DATA_DIRS_ENV) do
          ## fallback block, env var not bound
          Const::DATA_DIRS_DEFAULT
        end.split(File::PATH_SEPARATOR)
      end

      ## return an array of strings for the value of the XDG_CONFIG_DIRS
      ## environment variable, if configured, else using a default value
      ## for that variable
      ##
      ## @return [Array<String>] an array of directory names
      def config_dirs
        envdir(Const::XDG_CONFIG_DIRS_ENV) do
          ## fallback block
          Const::CONFIG_DIRS_DEFAULT
        end.split(File::PATH_SEPARATOR)
      end

      ## return the value of the HOME environment variable, if
      ## configured, else raise error.
      ##
      ## @return [String] the directory name
      def home
        dir = ENV[Const::HOME_ENV]
        if dir
          return dir
        else
          raise PebblApp::EnvironmentError.new("No HOME available in environment")
        end
      end

      ## return the value of the XDG_DATA_HOME environment variable, if
      ## configured, else a default value for that variable
      ##
      ## @return [String] the directory name
      def data_home
        envdir(Const::XDG_DATA_HOME_ENV) do
          ## fallback block
          return (Files.join(self.home, Const::XDG_DATA_SUBDIR))
        end
      end

      ## return the value of the XDG_CONFIG_HOME environment variable, if
      ## configured, else a default value for that variable
      ##
      ## @return [String] the directory name
      def config_home
        envdir(Const::XDG_CONFIG_HOME_ENV) do
          ## fallback block
          return (Files.join(self.home, Const::XDG_CONFIG_SUBDIR))
        end
      end

      ## return the value of the XDG_CACHE_HOME environment variable, if
      ## configured, else a default value for that variable
      ##
      ## @return [String] the directory name
      def cache_home
        envdir(Const::XDG_CACHE_HOME_ENV) do
          ## fallback block
          return (Files.join(self.home, Const::XDG_CACHE_SUBDIR))
        end
      end

      ## return the value of the XDG_STATE_HOME environment variable, if
      ## configured, else a default value for that variable
      ##
      ## @return [String] the directory name
      def state_home
        envdir(Const::XDG_STATE_HOME_ENV) do
          ## fallback block
          return Files.join(self.home, Const::XDG_STATE_SUBDIR)
        end
      end

      ## return the value of the TMPDIR environment variable, if
      ## configured, else a default value for that variable
      ##
      ## @return [String] the directory name
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
        if envd && Files.exists?(envd) && Files.owned?(envd)
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
          rundir = Files.join(self.tmpdir, run_subdir)
          n = 0
          while Files.exists(rundir) && !Files.owned?(rundir)
            rundir = rundir + Const::DOT + n
            n = n + 1
          end
          if !Files.exists(rundir)
            Files.mkdir_p(rundir)
            Files.chmod(0o0700, rundir)
          end
          return rundir
        end
      end

      ## If a 'USER' value is configured in the process environment,
      ## return that value as a string, Else, return the file basename
      ## of the value produced by the 'whomai' shell command.
      ##
      ## If no 'USER' value is configured in the environment and the
      ## call to the 'whomai' shell command fails, this method will
      ## raise an EnvironmentError
      def username
        if envname = ENV[Const::USER_ENV]
          return envname
        else
          ## portable whoami(1)
          begin
            who_str, err_str, st = Open3::capture3(Const::WHOAMI_CMD)
            if st.exitstatus.eql?(0)
              ## MS Windows/DOS 'whoami' with no args produces a name of a
              ## syntax e.g "domain\user". On this same platform, "\" is
              ## typically the file pathname separator, so calling basename
              ## here may serve to return the actual username.
              ##
              ## FIXME this needs test with ruby under mingw, where ideally a
              ## POSIX-like 'whoami' cmd would be available under PATH
              return Files.basename(who_str.chomp)
            else
              raise PebblApp::EnvironmentError.new(
                "Unable to determine username. Shell command %p failed (%d): %p" % [
                  Const::WHOAMI_CMD, st.exitstatus, err_str
                ])
            end
          rescue SystemCallError => e
            raise PebblApp::EnvironmentError.new(
              "Failed when calling %p : %s" % [Const::WHOAMI_CMD, e]
            )
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
          Files.join(p, name)
        end
      end

      def flatten_dirs(dirs)
        dirs.flat_map do |d|
          if Files.directory?(d)
            d
          else
            []
          end
        end
      end

    end ## class << self


    ## relative directory name for this FileManager
    attr_reader :app_dirname, :app_env_name

    ## create a FileManager, using the provided value as the app_driname
    ##
    ## @param app_dirname [String] the pathname for the app_dirname attribute
    def initialize(app_dirname,
                   app_env_name = app_dirname.split(Const::DOT).last.upcase)
      ## (last name element, upcase) ...
      @app_dirname = app_dirname.to_s
      @app_env_name = app_env_name.to_s
    end

    ## for the set of subdirectories of the class' data_dirs that exists
    ## for the configured app_dirname, return that list of directories
    ## as an array of strings
    ##
    ## @return [Array<String>] The list of app subdirs of data_dirs, if
    ##         existing
    def app_data_dirs()
      dirs = FileManager.flatten_dirs(FileManager.data_dirs)
      ## FIXME this assumes that any of the dirs would be created
      ## during install, if the dir was to exist and contain any files
      ## for the app
      FileManager.flatten_dirs(FileManager.map_join(self.app_dirname, dirs))
    end

    def app_data_home()
      @app_data_home ||=
        FileManager.envdir(app_env_name + "_DATA_HOME") do
          Files.join(FileManager.data_home, app_dirname)
        end
    end

    def app_data_home!()
      dir = app_data_home
      Files.mkdir_p(dir) do |subdir|
        File.chmod(0o0700, subdir)
      end
      return dir
    end

    ## for the set of subdirectories of the class' config_dirs that exists
    ## for the configured app_dirname, return that list of directories
    ## as an array of strings
    ##
    ## @return [Array<String>] The list of app subdirs of config_dirs, if
    ##         existing
    def app_config_dirs()
      dirs = FileManager.flatten_dirs(FileManager.config_dirs)
      ## FIXME this assumes that any of the dirs would be created
      ## during install, if the dir was to exist and contain any files
      ## for the app - siimlar to the data_dirs instance
      FileManager.flatten_dirs(FileManager.map_join(self.app_dirname, dirs))
    end

    ## return a pathname for the class' config_home with the app_dirname
    ## appended to the path, as a string or .. <app_env_name>_CONFIG_HOME
    def app_config_home()
      @app_config_home ||=
        FileManager.envdir(app_env_name + "_CONFIG_HOME") do
          Files.join(FileManager.config_home, app_dirname)
        end
    end

    ## return the value of #app_config_home,
    ## ensuring the directory exists
    def app_config_home!()
      dir = app_config_home
      Files.mkdir_p(dir) do |subdir|
        File.chmod(0o0700, subdir)
      end
      return dir
    end

    ## return a pathname for the class' state_home with the app_dirname
    ## appended to the path, as a string.
    def app_state_home()
      @app_state_home ||=
        FileManager.envdir(app_env_name + "_STATE_HOME") do
          Files.join(FileManager.state_home, app_dirname)
        end
    end

    ## return the value of #app_state_home,
    ## ensuring the directory exists
    def app_state_home!()
      dir = app_state_home
      Files.mkdir_p(dir) do |subdir|
        File.chmod(0o0700, subdir)
      end
      return dir
    end

    ## return a pathname for the class' cache_home with the app_dirname
    ## appended to the path, as a string.
    def app_cache_home()
      @app_cache_home ||=
        FileManager.envdir(app_env_name + "_CACHE_HOME") do
          Files.join(FileManager.cache_home, app_dirname)
        end
    end

    ## return the value of #app_cache_home,
    ## ensuring the directory exists
    def app_cache_home!()
      dir = app_cache_home
      Files.mkdir_p(dir) do |subdir|
        File.chmod(0o0700, subdir)
      end
      return dir
    end

    ## Ensure that a directory exists for the class' runtime_dir, with
    ## the app_dirname appended to the path, as a string.
    ##
    ## If the directory does not exist, it will be created, then configured
    ## with a permissions mask (octal) 0o0700
    ##
    ## @return [String] an app subdir onto the class' runtime_dir
    def app_runtime_dir!()
      basedir = FileManager.runtime_dir!
      dir = Files.join(basedir, app_dirname)
      File.mkdir_p(dir) do |subdir|
        Files.chmod(0o0700, subdir)
      end
      return dir
    end

  end ## FileManager class

end ## PebblApp::Supprot
