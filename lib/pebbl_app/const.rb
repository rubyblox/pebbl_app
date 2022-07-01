## PebblApp::Const module definition

require 'pebbl_app'

## Constants for PebblApp
module PebblApp::Const
  ## name delimiter
  DOT ||= ".".freeze
  ## a frozen empty array
  NULL_ARRAY ||= [].freeze
  ## environment variable name
  HOME_ENV ||= "HOME".freeze
  ## environment variable name
  TMPDIR_ENV ||= "TMPDIR".freeze
  ## default tmpdir base directory
  TMPDIR ||= "/tmp".freeze
  ## environment variable name
  USER_ENV ||= "USER".freeze
  ## shell command
  WHOAMI_CMD ||= "whoami".freeze

  ## environment variable name
  XDG_DATA_DIRS_ENV ||= "XDG_DATA_DIRS".freeze
  ## environment variable name
  XDG_CONFIG_DIRS_ENV ||= "XDG_CONFIG_DIRS".freeze

  ## environment variable name
  XDG_DATA_HOME_ENV ||= "XDG_DATA_HOME".freeze
  ## environment variable name
  XDG_CONFIG_HOME_ENV ||= "XDG_CONFIG_HOME".freeze
  ## environment variable name
  XDG_STATE_HOME_ENV ||= "XDG_STATE_HOME".freeze
  ## environment variable name
  XDG_CACHE_HOME_ENV ||= "XDG_CACHE_HOME".freeze

  ## environment variable name
  XDG_RUNTIME_DIR_ENV ||= "XDG_RUNTIME_DIR".freeze

  ## environment variable name
  XDG_DATA_SUBDIR ||= ".local/share".freeze
  ## environment variable name
  XDG_CONFIG_SUBDIR ||= ".local/config".freeze
  ## environment variable name
  XDG_STATE_SUBDIR ||= ".local/state".freeze
  ## environment variable name
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
end ## PebblApp::Const

