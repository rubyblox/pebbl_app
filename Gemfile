# Gemfile for rblib

# ensure that this file is evaluted under e.g -I 'lib'
if ! $LOAD_PATH.member?(File.join(__dir__, "lib"))
  $LOAD_PATH.unshift(File.join(__dir__, "lib"))
end

if $DEBUG
  ## enable some infomrative output from bundler
  ## e.g for bundler running under env RUBYOPT=--debug

  ## bundler lib/bundler/resolver.rb
  ## @ Bundler::Resolver#debug? (bundler 2.3.14)
  ENV['BUNDLER_DEBUG_RESOLVER'] = "Defined"

  ## bundler lib/bundler/vendor/molinillo/lib/molinillo/modules/ui.rb
  ## @ Bundler::Molinillo::UI (Module) (bundler 2.3.14)
  ENV['MOLINILLO_DEBUG'] = "Defined"
end ## $DEBUG


##
## configure bundler for all project gemspecs
##
require 'pebbl_app/project/y_spec'

yspec = PebblApp::Project::YSpec.new(
  ENV['PROJECT_YAML'] || File.join(__dir__, "project.yaml")
)
project_gems = yspec.load_config.gems

source 'https://rubygems.org'

## NB args on the Gemfile gemspec method
## @ bundler lib/bundler/dsl.rb (bundler 2.3.14)
## :path (default "."), :glob, :name, :development_group (default :development)

project_gems.each do |name|
  STDERR.puts("Defining gem (gemspec): #{name}") if $DEBUG
  gemspec name: name
  STDERR.puts("Defined gem (gemspec): #{name}") if $DEBUG
end
## log processing for failure under bundler in GH actions
if ENV['CI']
  Kernel.warn("will use at_exit action for mkmf.log files", uplevel: 0)
  bdl_config_dir = File.join(__dir__, ".bundle")
  if File.exists?(bdl_config_dir)
    bdl_config_file = File.join(bdl_config_dir, "config")
    if File.exists?(bdl_config_file)
      bdl_config = Psych.load_file(bdl_config_file)
      bdl_path = File.expand_path(bdl_config['BUNDLE_PATH'], __dir__)
      if File.exists?(bdl_path)
        require 'rake'
        require 'rake/file_list'
        ## dianogstic logs
        at_exit {
          STDERR.puts "-- at_exit"
          mkmf_logs = Rake::FileList.new(bdl_path + "/**/mkmf.log")
          mkmf_logs.each do |f|
            if File.exists?(f)
              STDERR.puts "---- BEGIN: #{f}"
              file = File.open(f)
              begin
                file.each_line do |txt|
                  STDERR.puts(txt)
                end
                ensure
                  file.close
              end
              STDERR.puts "---- END: #{f}"
            end
          end
        }
      end
    end
  end
end
