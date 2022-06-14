require 'pebbl_app/project/project_module'
require 'pebbl_app/support'

require 'open3'
require 'optparse'

module PebblApp::Support


  ## This class provides access to environment variables and default
  ## values for application pathnames per the XDG Base Directory
  ## specification. More info:
  ## https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
  ## https://wiki.archlinux.org/title/XDG_Base_Directory
  ##
  ## This class alsp provides support for appliation pathnames under
  ## each of the XDG home-relative directory paths.
  ##
  ## This class will be extended in any class including
  ## PebblApp::Support::AppPrototype
  ##
  class FileManager

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
          return (Files.join(self.home, Const::XDG_DATA_SUBDIR))
        end
      end

      def config_home
        envdir(Const::XDG_CONFIG_HOME_ENV) do
          return (Files.join(self.home, Const::XDG_CONFIG_SUBDIR))
        end
      end

      def cache_home
        envdir(Const::XDG_CACHE_HOME_ENV) do
          return (Files.join(self.home, Const::XDG_CACHE_SUBDIR))
        end
      end

      def state_home
        envdir(Const::XDG_STATE_HOME_ENV) do
          return Files.join(self.home, Const::XDG_STATE_SUBDIR)
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
              return Files.basename(who_str.chomp)
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


    attr_reader :app_dirname

    def initialize(app_dirname)
      @app_dirname = app_dirname
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
      Files.join(self.class.config_home, app_dirname)
    end

    ## return the value of #app_config_home,
    ## ensuring the directory exists
    def app_config_home!()
      dir = app_config_home
      Files.mkdir_p(dir)
      return dir
    end

    def app_state_home()
      Files.join(self.class.state_home, app_dirname)
    end

    ## return the value of #app_state_home,
    ## ensuring the directory exists
    def app_state_home!()
      dir = app_state_home
      Files.mkdir_p(dir)
      return dir
    end

    def app_cache_home()
      Files.join(self.class.cache_home, app_dirname)
    end

    ## return the value of #app_cache_home,
    ## ensuring the directory exists
    def app_cache_home!()
      dir = app_cache_home
      Files.mkdir_p(dir)
      return dir
    end

    def app_runtime_dir!()
      basedir = self.class.runtime_dir!
      dir = Files.join(basedir, app_dirname)
      if !Files.exists?(rundir)
        Files.mkdir_p(dir)
        Files.chmod(0o0700, dir)
      end
      return dir
    end

  end ## FileManager class

end ## PebblApp::Supprot
