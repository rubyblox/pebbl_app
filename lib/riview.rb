## riview.rb - baseline module definition and autoloads

module RIView
  ## FIXME use 'require' for these two source-bundled deps, pursuant of
  ## A) development tooling onto $LOAD_PATH
  ## B) gem installation
  require_relative 'gappkit'
  require_relative 'rikit'

  require 'gtk3'

  SOURCEDIR=File.join(__dir__, self.name.downcase).freeze

  RESOURCE_ROOT=File.expand_path("..", __dir__)

  VERSION=File.read(File.join(SOURCEDIR, self.name.downcase + "_version.inc")).
            split("\n").grep(/^[[:space:]]*[^#]/).first.strip.freeze

  AUTOLOAD_MAP={
    "riview_app" => %w(RIViewApp RIViewWindow TreeBuilder),
    "dataproxy" => %w(DataProxy),
  }.freeze

  AUTOLOAD_MAP.each { |file, names|
    path = File.join(SOURCEDIR, file + ".rb")
    names.each { |name| autoload(name, path) }
  }
end

# Local Variables:
# fill-column: 65
# End:
