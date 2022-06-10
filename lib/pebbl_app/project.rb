## module definition for PebblApp::Project

BEGIN {
  ## Ensure that the containing module is defined
  require(__dir__ + ".rb")
}

module PebblApp::Project
  autoload(:ProjectModule, File.join(__dir__, 'project/project_module.rb'))
  autoload(:YSpec, File.join(__dir__, 'project/y_spec.rb'))

  ## FIXME this sandboxing methodology needs further refinement
  if $WITH_SANDBOX || ENV['WITH_SANDBOX'] ||
      ( (gemfile = ENV['BUNDLE_GEMFILE']) &&
       (File.basename(File.dirname(gemfile)) == "rblib"))
    ## running under bundler in rblib - autoload local sandbox sources
    ##
    ## these files would not be published with the gemspec
    autoload(:Sandbox, File.join(__dir__, 'project/sandbox.rb'))
  end
end
