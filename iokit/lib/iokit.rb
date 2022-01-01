## iokit.rb - baseline module definition and autoloads

## Ruby language extensions for I/O with external processes
module IOKit
  SOURCEDIR=File.join(__dir__, self.name.downcase).freeze

  VERSION=File.read(File.join(SOURCEDIR, self.name.downcase + "_version.inc")).
                      split("\n").grep(/^[[:space:]]*[^#]/).first.strip.freeze

  AUTOLOAD_CLASSES=%w(OutProc).freeze

  AUTOLOAD_CLASSES.each { |name|
    autoload(name, File.expand_path(name.downcase + ".rb", SOURCEDIR))
  }
end

# Local Variables:
# fill-column: 65
# End:
