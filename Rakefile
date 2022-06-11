# Rakefile for rblib

require 'fileutils'

# ensure that this file is evaluted under e.g -I 'lib'
if ! $LOAD_PATH.member?(File.join(__dir__, "lib"))
  $LOAD_PATH.unshift(File.join(__dir__, "lib"))
end

## Notes: The 'install' task

## This project defines more than one gemspec.
##
## This project's Rakefile provides an 'install' task that operates
## only on a set of gems denoted in the project.yaml file, under the
## field 'publish_gems' (array)
##
## In addition to providing a manner of project-level control over which
## gems are selected for the 'install' task, this also serves to
## mitigate the concern of the default 'install' task retrieving and
## installing gems such that have already been installed under the host
## package management system. For the gtk4 gem and dependent gems, this
## install task was considered to be particularly time-consuming
##
## FIXME This project has yet to provide any further workaround for that
## original 'install' task. Ostensibly, the native-package-installer gem
## may be used under 'rake install', with some integration for the gem
## installation paths used under the original 'rake install' task in this
## gemfile, primarily integrating with bundler.
##
## In the meanwhile, the `publish_gems' field in project.yaml has not
## included any project gemspecs depending on the Ruby-GNOME gems and
## their direct and system-level dependencies. For developing these gems
## under this project, the 'bundle install' and 'bundle exec' shell
## tools would be recommended. These project gemspecs have not yet been
## tested under publish.
##
## FIXME: This project has not yet conducted any testing for the
## behaviors of `bundle exec rake release' in this project. Under the
## present Rakefile, it should publish only those gems denoted in the
##`publish_gems` field as such, not until after conducting any source
## code tests, documentation tests, and potentially any linitian tests.
##
## This not been tested for any more than one gem selected in 'publish_gems'
##
if ENV['BUNDLE_GEMFILE'] &&
  ( File.dirname(ENV['BUNDLE_GEMFILE']) == __dir__ )
  ##
  ## project tasks, accessible for `bundle exec rake`
  ##

  gem 'bundler'
  require "bundler/gem_helper"
  ## initialize Rake tasks for all project gems
  ##
  require 'pebbl_app/project/y_spec'
  yspec = PebblApp::Project::YSpec.new(
    ENV['PROJECT_YAML'] || File.join(__dir__, "project.yaml")
  )
  yspec.load_config
  ## FIXME this set of gems should only be used for publish
  publish_gems =
    yspec.project_field_value('publish_gems') do
      ## fallback block
      ##
      ## if no publish_gems field is configured for the project, use all
      ## gems defined in project.yaml
      ##
      yspec.gems
    end
  publish_gems.each do |name|
    Bundler::GemHelper.install_tasks(name: name)
  end

  gem 'rspec'
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec)


  ENV['RBS_TEST_LOGLEVEL'] ||='debug'
  ENV['RBS_TEST_TARGET'] ||= 'Project::*'

  gem 'rbs'
  require 'rbs/test/setup'
  ## "No type checker was installed!" ??

  desc 'Default tasks'
  task default: %i[spec test]

  #
  # task  :docs ... (needs test)
  #

  require 'rake/clean'

  ## bundle exec rake clean:
  ##
  ## Remove files generated from local rake tasks
  ##
  ## editor backup files will be included in CLOBBER
  CLEAN.exclude %q(*~)
  CLEAN.include %w(pkg/**  tmp/**)
  Rake::Task[:clean].clear_comments
  Rake::Task[:clean].add_description "Remove generated files"

  ## bundle exec rake clobber:
  ##
  ## Clean all cleanfiles; Remove local toolchain state data, editor
  ## backup files, and bundler path files
  ##
  CLOBBER.include %w(*~ Gemfile.lock)
  CLOBBER.include(
    ## remove cached bundler path files with clobber
    Bundler::configured_bundle_path.
      base_path_relative_to_pwd.join("**").join("**")
  )
  Rake::Task[:clobber].clear_comments
  Rake::Task[:clobber].add_description "Clean, and remove local toolchain state data"

  ## bundle exec rake realclean:
  ##
  ## Clean, clobber, and remove local bundler configuration
  realclean_files = %w(.bundle/config)
  desc 'Clean, clobber, and remove bundler config'
  task realclean: [:clobber] do
    Rake::Cleaner.cleanup_files(realclean_files)
  end

else
  ##
  ## development bootstrap tasks, for rake outside of bundler
  ##

  task %q(init:pkg) do |task, args|
    ## pseudocode for this task - see also:
    ## https://rubygems.org/gems/native-package-installer
    ##
    ## require psych because it's a build dependency here
    ##
    ## for each gem in gems from project.yaml ...
    ## ... traverse dependencies ...
    ##    ... for each dep not defined in this project ...
    ##        ... ensure each dep will be installed from a host pkg if available ...
    ##            ... using some su-exec method (sudo) that does not ask for
    ##                user credentials for every single pkg install
    ##        ... else use bundler for installing all the deps (FIXME)
  end

end

##
## tasks accessible within or without bundler
##

task %q(test:name) do |task|
  STDERR.puts(%q(Reached test:name))
end

# task %q(init:bundle) do |task, args|
#   sh %q(bundle install) # TBD cmd args pass-thru to here
# end

# task %q(update:bundle) do |task, args|
#   ## FIXME if running a bundler(1) of a newer version than in
#   ## Gemfile.lock and BUNDLE_PATH is  (?) unset,
#   ## then clobber Gemfile.lock and init:bundle here
# end
