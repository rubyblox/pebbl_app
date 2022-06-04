## iokit.gemspec

lib_name = File.basename(__dir__).downcase

require_relative(File.join("lib", lib_name + ".rb"))

lib_module = IOKit

$GEMSPEC = Gem::Specification.new do |s|
  s.name = File.basename(__dir__)
  s.version = File.read(File.join(__dir__, "lib", lib_name, lib_name + "_version.inc")).
                split("\n").grep(/^[[:space:]]*[^#]/).first.strip
  s.files = lib_module::AUTOLOAD_CLASSES.map { |name|
    File.join("lib", lib_name, name.downcase + ".rb")
  }
  s.require_paths = ["lib", File.join("lib", lib_name)]
end
