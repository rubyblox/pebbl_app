## rikit.rb - baseline module definition and autoloads

gem 'pebbl_app-support'
require 'pebbl_app/project_module'

module RIKit
  include PebblApp::ProjectModule

  defautoloads({
    "rikit/storetool" =>
      %w(QueryError StoreTool SystemStoreTool SiteStoreTool
         HomeStoreTool GemStoreTool),
    "rikit/storetopics" =>
      %w(TopicRegistryClass TopicRegistrantClass TopicRegistry
         Topic NamedTopic NamespaceTopic RITopicRegistry
         ModuleTopic ClassTopic MethodTopic ConstantTopic)
  })
end

# Local Variables:
# fill-column: 65
# End:
