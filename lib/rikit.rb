## rikit.rb - baseline module definition and autoloads

gem 'thinkum_space-project'
require 'thinkum_space/project/project_module'

module RIKit
  include ThinkumSpace::Project::ProjectModule

  defautoloads({"rikit/storetool" =>
                %w(QueryError StoreTool SystemStoreTool
                   SiteStoreTool HomeStoreTool GemStoreTool),
              "rikit/storetopics" =>
                %w(TopicRegistryClass TopicRegistrantClass TopicRegistry
                   Topic NamedTopic NamespaceTopic RITopicRegistry
                   ModuleTopic ClassTopic MethodTopic ConstantTopic)
               })
end

# Local Variables:
# fill-column: 65
# End:
