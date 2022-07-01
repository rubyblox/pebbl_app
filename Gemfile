# Gemfile for Pebbl App

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
require 'pebbl_app/y_spec'

$YSPEC_DEBUG = $DEBUG
conf = File.join(__dir__, "project.yaml")
yspec = PebblApp::YSpec.new(conf)
project_gems = yspec.load_config.gems

source 'https://rubygems.org'

## NB args on the Gemfile gemspec method
## @ bundler lib/bundler/dsl.rb (bundler 2.3.14)
## :path (default "."), :glob, :name, :development_group (default :development)

project_gems.each do |name|
  STDERR.puts("Adding gem (gemspec) #{name} to Gemfile") if $DEBUG
  gemspec name: name
  STDERR.puts("Added gem (gemspec) #{name} to Gemfile") if $DEBUG
end

## configuration for modules using PebblApp::Support::FileManager
## - XDG_DATA_HOME usage: FileManager.new(<app_dirname>).data_home
if (gemfile = ENV['BUNDLE_GEMFILE'])
  ENV['XDG_DATA_HOME'] = File.join(File.dirname(gemfile), "config")
end

##
## ccflags/cxxflags for extensions @ RbConfig::CONFIG
##
## FIXME move defs to PebblApp::Support::ExtUtil
##
require 'rbconfig'
require 'shellwords'

def rbconfig_export_append(elt,  name)
  if (flags = RbConfig::CONFIG[name])
    elts = Shellwords.split(flags)
    if ! elts.include?(elt)
      flags << (" " + elt)
    end
    RbConfig::CONFIG[name] = flags.freeze
    ENV[name] = flags.freeze
  else
    Kernel.warn("No RbConfig CONFIG flag found for #{name.inspect}",
                uplevel: 0)
  end
end

def rbconfig_export_remove(expr, name)
  if (flags = RbConfig::CONFIG[name])
    elts = Shellwords.split(flags)
    elts.filter! { |elt| ! elt.match?(expr) }
    filt_str = elts.join(" ").freeze
    RbConfig::CONFIG[name] = filt_str
    ENV[name] = filt_str
  else
    Kernel.warn("No RbConfig CONFIG flag found for #{name.inspect}",
                uplevel: 0)
  end
end

##
## filtering for CEXPORT, CXXEXPORT under RbConfig::CONFIG
##
## - compile with debug symbols
## - do not optimize with -O3
## - do not quiet warnings
%w(CFLAGS CXXFLAGS).each do |flvar|
  rbconfig_export_append("-g", flvar)
  rbconfig_export_remove("-O3", flvar)
  rbconfig_export_remove(/^-Wno-/, flvar)
  STDERR.puts("%s: Using %s %p" % [
    File.basename($0), flvar, ENV[flvar]
  ]) if $DEBUG
end
##
## ensure that the extensions code will not be stripped
##
ENV['STRIP'] = RbConfig::CONFIG['STRIP'] = "true"

## IRB & Pry support for bundle exec
##
## e.g configuration
## $ bundle config --local set path vendor/bundle
## $ bundle config --local set with development:irb:pry
##
%w(irb pry).each do |name|
  ## >> :irb group with an irb gem dep
  ## >> :pry group with a pry gem dep
  group name.to_sym, optional: true do
    gem name
  end
end

##
## source configuration for development with gems from Ruby-GNOME
##
## Development Notes:
##
## The published gemspecs from this project would use literal version
## bounds for each dependency to gem(1) e.g gtk3 '>= 3'
##
## For development purposes, this project will use the latest Ruby-GNOME
## src when configuring the gem dependencies to bundler(1) via this Gemfile.
##
## Previous to any gemspec release in this project, the pre-release
## gemspecs should be tested in a clean builder environment under GitHub
## actions. This may serve to verify that the code tests out with the
## dependencies resolved by gem(1), given the gemspec dependencies in
## in each gemspec as to be released (configured via project.yaml)
##
## Previous to release, this project will use the latest src for gems
## from Ruby-GNOME


if ENV['CI']
  ## using dependencies from rubygems.org when building under GitHub actions
  rg_packages = nil
else
  ## using the latest Ruby-GNOME src / local patches

  gem "yard-gobject-introspection",
    ## local patches => pushed in contrib
  github: "rubyblox/yard-gobject-introspection"
  ## orignal src:
  # github: "ruby-gnome/yard-gobject-introspection"

  rg_packages = %w(atk cairo-gobject clutter clutter-gdk clutter-gstreamer
                   clutter-gtk gdk3 gtk3 gtksourceview3 gdk_pixbuf2 gegl
                   gio2 glib2 gobject-introspection gsf gstreamer libsecret
                   pango poppler vte3 webkit2-gtk wnck3)
end

## additional gems available via Ruby-GNOME:
# gdk4
# gtk4
# gtksourceview4
# gnumeric
# goffice
# rsvg2
# webkit-gtk

if rg_packages && (! rg_packages.empty?)
  # git 'https://github.com/ruby-gnome/ruby-gnome.git' do ## upstream
  git 'https://github.com/rubyblox/ruby-gnome.git', branch: 'thinkum' do ## local patches
    rg_packages.each do |pkg|
      ## this glob literal should match each gem's gemspec
      ## in each gem's subdir, relative to the source tree root
      gem pkg, glob: "#{pkg}/#{pkg}.gemspec"
    end
  end
end

## TBD configuring steep, rbs for type checking under rake - rbs 'test' task
gem 'steep', group: :development

## local dependencies can be configured in Gemfile.local. This file will
## not be added to project version control.
local_gemfile = File.join(__dir__, 'Gemfile.local')
if File.exist?(local_gemfile)
  begin
    ## evaluating Gemfile.local in a scope for a Bundler::Dsl instance
    self.eval_gemfile (local_gemfile)
  rescue
    ## handling exceptions in the parse/eval for Gemfile.local
    ## as a continuable error for purposes of bundler eval
    Kernel.warn("Failed to include #{local_gemfile}: #{$!}",
                uplevel: 0)
  end
end
