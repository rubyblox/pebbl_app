## Makefile for Pebbl App
##
## This Makefile was designed for bmake,
## but it should be compatible with GNU Make
## - does not use .CURDIR or bmake-specific syntax
##
## Many of these make tgts are implemented similarly in the project Rakefile
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
## for custom configurations, the file can be created independent of this Makefile
.bundle/config:
	bundle config --local set path ${BUNDLE_CONFIG_PATH}
	bundle config --local set with ${BUNDLE_CONFIG_WITH}

## install gems for the project, using the existing bundle config,
## after the Gemfile or .bundle/config is updated
Gemfile.lock: Gemfile .bundle/config
	bundle install --verbose
	touch $@

## show rake tasks
show-tasks: Gemfile.lock
	bundle exec rake -T

## yardoc via bundler
## - output is produced under ./doc
yardoc: Gemfile.lock
	bundle exec yardoc 'lib/**/*.rb'

## run rspec tests
## - this assumes an sh(1) or bash shell with make
## - using the shell's PID to provide a unique display name for Xvfb
## - portable to GNU Make and bmake
test: Gemfile.lock
	env -u XAUTHORITY -u XAUTHLOCALHOSTNAME -u DISPLAY bundle exec rspec

## clean some files
clean:
	rake clean

## delete all untracked files (no backups, no warranty)
realclean:
	rake realclean

##
## ZFS support for the project dir
##
## Assumptions:
## - that this project was checked out into a distinct ZFS filesystem
##   i.e to a filesystem not shared with other projects, the user homedir, etc
## - the filesystem is mounted directly from ZFS
## - the user can create ZFS snapshots on this filesystem, as per zfs-allow(8)
##
## create a new snapshot on the filesystem containing this project directory,
## using the current host wall time under the active timezone for the name of the
## snapshot
##
## the snapshot can be recovered to, using 'zfs rollback' and sent to
## any virtual machine environments, filesystem backup media, or other
## hosts, using 'zfs send'
##
## These tgts use a syntax that should be portable to GNU Make as well as bmake,
## assuming a generally BSD sh(1)-like shell is used with this Makefile
##
snapshot:
	zfs snapshot $$(df -h $${PWD} | tail -n1 | awk '{print $$1}')@$$(date -Iseconds | sed 's@:@@g')

snapshots:
	zfs list -r -t snapshot -pH -oname $$(df -h $${PWD} | tail -n1 | awk '{print $$1}')

# Local Variables:
# mode: makefile-bsdmake
# End:
