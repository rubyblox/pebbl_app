## gappkit.rb - baseline module definition and autoloads

module GAppKit
  SOURCEDIR=File.join(__dir__, self.name.downcase).freeze

  VERSION=File.read(File.join(SOURCEDIR, self.name.downcase + "_version.inc")).
            split("\n").grep(/^[[:space:]]*[^#]/).first.freeze

  AUTOLOAD_MAP={
    "logging" => %w(LoggerDelegate LogManager LogModule),
    "threads" => %w(NamedThread),
    "sysexit" => %w(SysExit),
    "glib_type_ext" => %w(GTypeExt),
    "gtk_type_ext" => %w(UIBuilder TemplateBuilder
                         ResourceTemplateBuilder FileTemplateBuilder),
    "gbuilder_app" => %w(GBuilderApp),
    "basedir" => %w(FileResourceManager)
  }

  AUTOLOAD_MAP.each { |file, names|
    path = File.join(SOURCEDIR, file + ".rb")
    names.each { |name| autoload(name, path) }
  }
end

# Local Variables:
# fill-column: 65
# End:
