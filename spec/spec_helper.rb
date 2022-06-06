## rblib configuration for rspec

require "thinkum_space/project"

RSpec.configure do |config|
  ## configure a persistence path for rspec
  ##
  ## used with rspec  --only-failures, --next-failure options
  config.example_status_persistence_file_path = ".rspec_status"

  # config.expect_with :rspec do |c|
  #   c.syntax = :expect
  # end
end
