## Makefile for Pebbl App
##
## This Makefile was designed for bmake,
## but should be compatible with GNU Make
## - does not use .CURDIR
##

## bmake vars (not presently used)
# GEM_HOME?=	${:!bundle exec ruby -e 'puts ENV["GEM_HOME"]'!}
# A_GEM_VERSION?=	${:! awk '\$1 == "a_gem" { gsub("[()]", "", \$2); print \$2; exit; }' Gemfile.lock !}

## variables independent of bundler environment,
## each being defined with a default value here
BUNDLE_CONFIG_PATH?=	vendor/bundle
BUNDLE_CONFIG_WITH?=	development

all: test

## set a default .bundle/config
##
## for custom configurations, this file can be created independent of the Makefile
.bundle/config:
	bundle config set path ${BUNDLE_CONFIG_PATH}
	bundle config set with ${BUNDLE_CONFIG_WITH}

## install gems for the project, using the existing bundle config,
## upating after the Gemfile or .bundle/config is updated
Gemfile.lock: Gemfile .bundle/config
	bundle install
	touch $@

## show rake tasks
show-tasks: Gemfile.lock
	bundle exec rake -T

## run rspec tests
test: Gemfile.lock
	Xvfb :10 & env DISPLAY=:10 bundle exec rspec

## clean some files
clean:
	rake clean

## delete all untracked files
realclean:
	rake realclean

##
## ZFS support for the project dir
##
## Assumptions:
## - this project was checked out into a distinct ZFS filesystem
## - the filesystem is mounted directly from ZFS
## - the user has permissions for ZFS snapshots on this filesystem, per zfs-allow(8)
##
## create a new snapshot on the filesystem containing this project directory,
## using the current host time under the active timezone for the name of the
## snapshot
snapshot:
	zfs snapshot $$(df -h $${PWD} | tail -n1 | awk '{print $$1}')@$$(date -Iseconds | sed 's@:@@g')

snapshots:
	zfs list -r -t snapshot -pH -oname $$(df -h $${PWD} | tail -n1 | awk '{print $$1}')

# Local Variables:
# mode: makefile-bsdmake
# End:
