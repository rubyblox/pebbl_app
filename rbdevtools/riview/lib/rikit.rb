## rikit.rb - baseline module definition and autoloads

module RIKit
  SOURCEDIR=File.join(__dir__, self.name.downcase).freeze

  VERSION=File.read(File.join(SOURCEDIR, self.name.downcase + "_version.inc")).
            split("\n").grep(/^[[:space:]]*[^#]/).first.strip.freeze

  AUTOLOAD_MAP={
    "storetool" => %w(QueryError StoreTool
                      SystemStoreTool SiteStoreTool HomeStoreTool GemStoreTool),
    "storetopics" => %w(TopicRegistryClass TopicRegistrantClass TopicRegistry
                        Topic NamedTopic NamespaceTopic RITopicRegistry
                        ModuleTopic ClassTopic MethodTopic ConstantTopic)
  }.freeze

  AUTOLOAD_MAP.each { |file, names|
    path = File.join(SOURCEDIR, file + ".rb")
    names.each { |name| autoload(name, path) }
  }
end

# Local Variables:
# fill-column: 65
# End:
