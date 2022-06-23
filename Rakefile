# Rakefile for rblib

require 'fileutils'

$THIS = File.basename($0)

if ENV['BUNDLE_GEMFILE'] &&
    ( File.dirname(ENV['BUNDLE_GEMFILE']) == __dir__ )

  ##
  ## project tasks, accessible under bundle exec
  ##
  ## e.g for `bundle exec rake`
  ##

  task default: %i(spec)

  ##
  ##

  gem 'rspec'
  require "rspec/core/rake_task"
  require 'pebbl_app/support/sh_proc' ## local file

  ## Some rspec tests in this project's Gtk support will require an
  ## active X Window System display.
  ##
  ## If Xvfb is installed and available in the runtime PATH and no
  ## DISPLAY is configured for the rspec environment, this project's
  ## spec_helper.rb will initialize an Xvfb process to provide a
  ## DISPLAY for the tests. An at_exit proc will be initialized, to
  ## ensure that the XVfb process will exit on normal exit from the Ruby
  ## process under rspec.
  ##
  ## To prevent the tests from interacting with any active X Window
  ## System display environment, if Xvfb is available under the runtime
  ## PATH, then in the 'spec' task: This Rakefile will ensure that any
  ## DISPLAY environment variable is removed for this Rake process,
  ## hence for the rspec environment under rake.
  ##
  ## TBD providing an ENV hash to the rspec subprocess for the
  ## initialized spec task, without modifying the environment for the
  ## calling rake process - ideally, reusing existing rake support in rspec
  task spec: [] do
    ## when configured first, this task should be run before the :spec
    ## task from RSpec
    cmd = PebblApp::Support::ShProc.which('Xvfb')
    this = File.basename($0)
    ## unset DISPLAY in the rake environment, only if Xvfb is available
    if cmd
      STDERR.puts "#{this}: Unsetting display for rspec tests"
      ENV['DISPLAY']=nil
    else
      Kernel.warn("#{this}: could not find Xvfb: #{err.chomp}")
    end
  end
  RSpec::Core::RakeTask.new(:spec)
  Rake::Task[:spec].clear_comments
  Rake::Task[:spec].add_description "Run RSpec tests"

  ENV['RBS_TEST_LOGLEVEL'] ||='debug'
  ENV['RBS_TEST_TARGET'] ||= 'PebblApp::*'

  gem 'rbs'
  require 'rbs/test/setup'
  ## TBD "No type checker was installed!"
  ## - presumably via rbs, tbd to be configured for steep

  desc 'update documentation products'
  task doc: [] do
    ## FIXME integrate with GH actions, e.g when ENV['CI']
    ## => publish docs (after some review)
    sh %(bundle exec yardoc "lib/**/*.rb")
  end

  ## if ENV['CI']
  #### additional tasks for evaluation under GitHub actions
  ## end

  desc 'show bundled mkmf.log files (verbose output)'
  task show_mkmf_logs: [] do
    ## verbsose dianogstic logs for extensions - display every mkmf.log
    ## under the bundle path's extensions dir
    ##
    ## If this task is evaluated under a GitHub action, the diagnostic
    ## log output produced from this task may be available via web-based
    ## GH Actions review at GitHub, or GitHub CLI tools, e.g:
    ## $ gh run view
    ##
    ## This may be helpful if in order to debug any failed installations
    ## for gem extensions, wihout direct access to the build host.
    ##
    ## Known Limitations
    ##
    ## If ran without a configured bundle path for bundler, this may
    ## illustrate every mkmf.log installed under the gems extension
    ## directory in the host mangaement system and/or local gems.
    ## (not tested)
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
    ## package management system. if for any new installation on a
    ## single operating system platform. This information can be used
    ## for documentation updates.
    ##
    ## example: see ./bin/show-depends-suse
    ##
    ## bundler must already have installed all gem dependencies, or this
    ## task defnition would not be reached
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
              if field.match?(/^-l/.freeze)
                ## add the library name as a substring
                ## after the "-l" linker flag
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
  ## non-bundler-env tasks for rake

  task default: %i(bundle:subrake)

  namespace 'bundle' do
    desc 'run rake under bundler'
    ## By side effect corresponding to the deps of this task, this task
    ## should serve to ensure that bundler will have installed the deps
    ## for this project, before rake will call the default task under a
    ## rake subprocess via bundler.
    ##
    ## To pass args to the subrake, e.g -T:
    ## $ rake subrake -- -T
    ##
    task subrake: ['Gemfile.lock'] do
      sh %(bundle exec rake ) + ARGV.difference(%w(subrake --)).join(" ")
    end

  end


  ## The following tasks are defined with Bundler::GemHelper but should
  ## generally not be called under 'bundle exec'.
  ##
  ## if running the following tasks under 'bundle exec rake', then for
  ## each install task defined in the following, the gem tool would
  ## install each project gem to any locally configured bundle path,
  ## not to the user gems path.
  ##
  ## Consequently, these tasks are defined as to not be avaialble
  ## when rake is run under bundler

  ## Support for logging w/ local gem_wrapper, used for tasks that will
  ## be added via Bundler::GemHelper
  ##
  ## The environment can set GEM_BIN to specify a gem command
  ## to use in bin/gem_wrapper for Bundler::GemHelper tasks
  ##
  ## LOGDIR will be set for purpose of recording output from the
  ## gem cmd, in tasks that will be added by Bundler::GemHelper
  ##
  ## This can be used e.g to verify that the 'install' task --
  ## when called under a bundler env with a local bundler path
  ## configured -- that it will install the gem under the
  ## project's bundle path & not in user or host gem paths
  ##
  ENV['GEM_COMMAND']= File.join(__dir__, "bin/gem_wrapper")
  if ! ENV.key?('LOGDIR')
    ENV['LOGDIR'] = File.join(__dir__, "tmp/build_logs")
  end

  ## ad hoc project.yaml parser for Bundler::GemHelper tasks
  gem 'bundler'
  require 'psych'
  require "bundler/gem_helper"
  ##
  ## configure gem tasks for all published gems
  ##
  proj_yaml = File.join(__dir__, "project.yaml")
  if Psych.respond_to?(:safe_load_file)
    proj_data = Psych.safe_load_file(proj_yaml)
  else
    proj_data = Psych.load_file(proj_yaml)
  end


  if (publishing = proj_data['publish_gems'])
    ## value must be an array
    local_gems = publishing
  else
    ## if no publishing_gems, use all gems defined in project.yaml
    if (all_gems = proj_data['gems'])
      local_gems = all_gems.keys
    else
      local_gems = [].freeze
    end
  end

  namespace "gems" do

    namespace "each" do
      local_gems.each do |name|
        namespace name do
          ## ** FIXME ** wrong placement for this, and yet this will need
          ## access to the project.yaml parser & its deps
          Bundler::GemHelper.install_tasks(name: name)
        end
      end
    end

    ## e.g for the gems:build task to build all specified gems
    %w(build build:checksum install install:local).each do |dispatch|
      all_disp = local_gems.map { |name| "%s:each:%s" % [name, dispatch]}
      desc "#{dispatch} for #{local_gems.join(", ")}"
      task dispatch => all_disp
    end

  end

end

##
## tasks accessible within or without a bundler environment
##


namespace :console do
  desc 'Run IRB in a console in rake'
  $TBD = Rake.application.instance_variable_get(:@scope)
  task :irb do |task, args|
    $RAKE_APP = Rake.application
    $RAKE_SCOPE = task.scope
    require %q(irb)
    require %q(irb/completion)
    rake = File.basename($0)
    STDERR.puts "#{rake} #{task.name} : Rake.application available as $RAKE_APP"
    STDERR.puts "#{rake} #{task.name} : Current task scope available as $RAKE_SCOPE"
    IRB.setup(__FILE__, argv: args)
    IRB::Irb.new().run()
  end
end


desc %(fetch ui/gtkbuilder.rnc)
task uischema: %w(ui/gtkbuilder.rnc)

file 'ui/gtkbuilder.rnc' do |task|
  require 'net/http'
  schema_origin =
    URI(%(https://gitlab.gnome.org/GNOME/gtk/-/raw/gtk-3-24/gtk/gtkbuilder.rnc))
  STDERR.puts("#{$THIS}: fetching #{schema_origin}")
  schema_io = Net::HTTP.get(schema_origin)
  out = task.name
  File.open(out, 'wb') do |io|
    io.write(schema_io)
  end
  STDERR.puts("#{$THIS}: wrote #{out}")
end

## does not modify the environment for rake:
BUNDLE_PATH ||= (ENV['BUNDLE_PATH'] || "vendor/bundle")
BUNDLE_WITH ||= (ENV['BUNDLE_WITH'] || "development:gtk:irb")

## create a default bundler config, if no config exists
file '.bundle/config' do
  sh %(bundle config set --local path "#{BUNDLE_PATH}")
  sh %(bundle config set --local with "#{BUNDLE_WITH}")
end

## a bundle install task
## - may be useful after updating the Gemfile, project.yaml,
##   or addng Gemfile.local
## - does not depend on bundler having the latest dependencies
##   available, when using rake from the host pkg mangement
##   system or from gem install
file 'Gemfile.lock': %w(.bundle/config Gemfile) do
  sh %(bundle install --verbose)
  File.utime(File.atime('Gemfile.lock'), Time.now, 'Gemfile.lock')
end


namespace 'bundle' do
  desc 'install dependencies'
  task install: %w(Gemfile.lock)

  ## the task as visible under rake -T
  desc %(update bundler installation for project)

  task update: %w(.bundle/config Gemfile) do
    sh %(bundle update --verbose)
    File.utime(File.atime('Gemfile.lock'), Time.now, 'Gemfile.lock')
  end

  desc %(bundle update, bundle clean)
  task refresh: [:update] do
    sh %(bundle clean --verbose)
  end
end ## bundle


require 'rake/clean'
## rake clean:
##
## Remove files generated from local rake tasks
##
## editor backup files will be included in CLOBBER
CLEAN.exclude %(*~)
CLEAN.include %w(pkg/** tmp/** doc/**)
Rake::Task[:clean].clear_comments
Rake::Task[:clean].add_description "Remove generated files"

## rake clobber:
##
## Clean all cleanfiles; Remove local bundler state data, bundler path
## files, and editor backup files
##
CLOBBER.include %w(*~ .#* *# *.bak *.rej Gemfile.lock)
if Kernel.const_defined?(:Bundler)
  CLOBBER.include(
    ## removing any installed bundler path files with clobber
    Bundler::configured_bundle_path.
      base_path_relative_to_pwd.join("**").join("**")
)
end

Rake::Task[:clobber].clear_comments
Rake::Task[:clobber].add_description "Clean, remove local toolchain state data"

desc 'Remove all untracked files (git)'
task realclean: [:clobber] do
  if File.exist?(File.join(__dir__,".git"))
    sh "git ls-files -o -z | xargs -0 rm -f"
  else
    Kernel.warn("#{$THIS}: Not a git repository: #{__dir__}",
                uplevel: 0)
  end
end
