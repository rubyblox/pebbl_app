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
## corresponding to each <name>.gemspec file
## limited to the set of gems defined in project.yaml
##
require 'pebbl_app/project/y_spec'

conf = File.join(__dir__, "project.yaml")
yspec = PebblApp::Project::YSpec.new(conf)
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

## configuration for modules using PebblApp::Support::FileManager
## - XDG_DATA_HOME usage: FileManager.new(<app_dirname>).data_home
if (gemfile = ENV['BUNDLE_GEMFILE'])
  ENV['XDG_DATA_HOME'] = File.join(File.dirname(gemfile), "config")
end


## IRB, Pry support for bundle exec
##
## e.g configuration
## $ bundle config --local set path vendor/bundle
## $ bundle config --local set with development:irb:pry
##
%w(irb pry).each do |name|
  group name.to_sym, optional: true do
    gem name
  end
end


## local dependencies can be configured in Gemfile.local. This file will
## not be added to project version control.
local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist?(local_gemfile)
  ## to in effect include Gemfile.local within this gemfile, the
  ## included file will be evaluated directly
  begin
    eval (File.read(local_gemfile))
  rescue
    ## handling any exception in the parse/eval for Gemfile.local as a
    ## continuable error for purposes of bundler eval
    Kernel.warn("Failed to include #{local_gemfile}: #{$!}",
                uplevel: 0)
  end
end

##
## source configuration for gems from Ruby-GNOME
##

gem "yard-gobject-introspection", github: "ruby-gnome/yard-gobject-introspection"

rg_packages = %w(atk cairo-gobject clutter clutter-gdk clutter-gstreamer
                 clutter-gtk gdk3 gtk3 gtksourceview3 gdk_pixbuf2 gegl
                 gio2 glib2 gobject-introspection gsf gstreamer libsecret
                 pango poppler vte3 webkit2-gtk wnck3)
## TBD
#  gdk4
#  gtk4
#  gtksourceview4
#  gnumeric
#  goffice
#  rsvg2
 # webkit-gtk

git 'https://github.com/ruby-gnome/ruby-gnome.git' do
  rg_packages.each do |pkg|
    gem pkg, glob: "#{pkg}/*.gemspec" ## ??
  end
end

## TBD configuring steep, rbs for type checking under the rake 'test' task (rbs)
gem 'steep', group: :development

