## projectkit.rb - baseline module definition and autoloads

module ProjectKit
  SOURCEDIR=File.join(__dir__, self.name.downcase)

  VERSION=File.expand_path("projectkit_version.inc", SOURCEDIR).
            split("\n").grep(/^[[:space:]]*[^#]/).first

  AUTOLOAD_CLASSES=%w(RSpecTool)

  AUTOLOAD_CLASSES.each { |name|
    autoload(name, File.expand_path(name.downcase + ".rb", SOURCEDIR))
  }
end
