## rb-zmulti Rakefile

#require 'spec/rake/spectassk'
require 'rubygems/package_task'

## FIXME - no gem yet, for rbproject
require_relative 'lib/rbproject/rbproject_simple'

## TBD @ GH

task :default => [:package]

## NB see then: ./pkg/*

all_projects = [ "rbloader.yprj" ]

all_projects.each do |p|
  proj = RbProject.project(p)

  proj.gem_package_task() do |t|
    ## TBD gem is using plain tar format by default (??)
    t.need_zip = true
    t.need_tar_gz = true
  end
end
