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

## configuration for modules including PebblApp::Support::AppModule
lambda {
    if (gemfile = ENV['BUNDLE_GEMFILE'])
      ENV['XDG_DATA_HOME']=File.join(File.dirname(gemfile), "config")
    end
}.call

## additional dependencies can be added to Gemfile.local.
##
## This file will not be added to version control
##
## This allows for e.g using pry via bundle exec, once pry has been
## added to the set of development dependencies for this project
## (see README)
##
local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist?(local_gemfile)
  ## to in effect include Gemfile.local within this gemfile, per how
  ## this gemfile itself is evaluated, each line of the included file
  ## will be evaluated directly
  begin
    File.open(local_gemfile) do |io|
      io.each_line do |txt|
        eval(txt)
      end
    end
  rescue
    Kernel.warn("Failed to include #{local_gemfile}: #{$!}",
                uplevel: 0)
  end
end
