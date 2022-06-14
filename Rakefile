# Rakefile for rblib

require 'fileutils'

## Notes: The 'install' task
##
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
## package management system
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
  # task default: %i[spec test] ## test : rbs
  task default: %i[spec]

  #
  # task  :docs ... (needs test)
  #

  ## if ENV['CI']
  #### include additional tasks for evaluation under GitHub actions
  ##  require_relative 'Rakefile.ci'
  ## end

  desc 'show bundled mkmf.log files (verbose output)'
  task show_mkmf_logs: [] do
    ## verbsose dianogstic logs for extensions - display every mkmf.log
    ## undler the bundle path extensions dir
    ##
    ## if this task is evaluated under a GitHub action, the diagnostic
    ## log output produced from this task may be available via web-based
    ## Gith Actions reivew or GitHub CLI, e,g
    ##
    ## $ gh run view
    ##
    ## This may be useful as in order to debug any failed extension
    ## installation wihout direct access to the build host.
    ##
    ## Known Limitations
    ##
    ## If ran without 'bundle config set path vendor/bundle' e.g in the
    ## project root directory, this may illustrate every mkmf.log
    ## installed under the gems extension directory in the host package
    ## mangaement system and/or local gems. (not tested)
    ##
    logs = Rake::FileList.new("#{ENV['GEM_HOME']}/extensions/**/mkmf.log")
    logs.each do |f|
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
  end

  desc 'show library dependencies for bundled installation'
  task show_depends_libs: [] do
    ##
    ## usasge: This task may be used with local shell scripting, to
    ## evaluate what dependencies should be installed from the host
    ## package management system
    ##
    ## this assumes that dependencies have been installed under vendor/bundle
    ## and assumes that bundler will have set GEM_HOME in ENV, to match
    ## the pathname for installed gems
    ##
    ## example: see ./bin/show-depends-suse
    ##
    makefiles = Rake::FileList.new("#{ENV['GEM_HOME']}/gems/*/ext/**/Makefile")
    libs = {}
    makefiles.each do |pmkf|
      own_libs = []
      libs[pmkf] = own_libs
      File.open(pmkf) do |mkf|
        mkf.each_line do |mktxt|
          fields = mktxt.split
          if (fields[0] == "LIBS".freeze)
            fields.each do |field|
              if field.match?(/^-l/)
                own_libs.push(field[2..])
              end
            end
          end
        end
      end
    end
    libs_names = libs.values.flatten.sort.uniq
    libs_libs = libs_names.map { |l| "lib" + l }.join(" ")
    puts "LIBS: #{libs_libs}"
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

require 'rake/clean'

## bundle exec rake clean:
##
## Remove files generated from local rake tasks
##
## editor backup files will be included in CLOBBER
CLEAN.exclude %q(*~)
CLEAN.include %w(pkg/** tmp/**)
Rake::Task[:clean].clear_comments
Rake::Task[:clean].add_description "Remove generated files"

## bundle exec rake clobber:
##
## Clean all cleanfiles; Remove local toolchain state data, editor
## backup files, and bundler path files
##
CLOBBER.include %w(*~ Gemfile.lock)
CLOBBER.include(
  ## removing installed bundler path files with clobber
  Bundler::configured_bundle_path.
    base_path_relative_to_pwd.join("**").join("**")
)
Rake::Task[:clobber].clear_comments
Rake::Task[:clobber].add_description "Clean, and remove local toolchain state data"

desc 'Remove all untracked files'
task realclean: [:clobber] do
  if File.exist?(File.join(__dir__,".git"))
    sh "git ls-files -o -z | xargs -0 rm -f"
  else
    Kernel.warn("Not a git repository: #{__dir__}", uplevel: 0)
  end
end
