## iokit.rb - IOKit module definition and autoloads

## Ruby language extensions for I/O with external processes
module IOKit
  SOURCEDIR=File.join(__dir__, self.name.downcase).freeze

  VERSION=File.read(File.join(SOURCEDIR, self.name.downcase + "_version.inc")).
    split("\n").grep(/^[[:space:]]*[^#]/).first.strip.freeze

  AUTOLOAD_NAMESPACES=%w(OutProc ProcessFacade).tap{ |name| name.freeze }
  AUTOLOAD_FILES={ "ProcessFacade" => "process_facade" }.
    tap { |k,v| k.freeze; v.freeze; }.freeze

  AUTOLOAD_NAMESPACES.each { |name|
    whence = ( AUTOLOAD_FILES[name] || name.downcase ) + ".rb"
    autoload(name, File.expand_path(whence, SOURCEDIR).freeze)
  }
end

# Local Variables:
# fill-column: 65
# End:
