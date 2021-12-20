## iokit.rb - baseline module definition and autoloads

## Ruby language extensions for I/O with external processes
module IOKit
  VERSION=File.read(File.expand_path("iokit_version.inc", __dir__)).
            split("\n").grep(/^[[:space:]]*[^#]/).first

  AUTOLOAD_CLASSES=%w(OutProc)

  AUTOLOAD_CLASSES.each { |name|
    autoload(name, File.join(__dir__, name.downcase + ".rb"))
  }
end


# Local Variables:
# fill-column: 65
# End:
