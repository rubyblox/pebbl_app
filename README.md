Pebbl App from Thinkum.Space
============================

**Introducing Pebbl App**

## Developing with the Pebbl App Framework

### GTK Support in Pebbl App

In order to develop with the GTK and GNOME support in Pebbl App, the
[Ruby-GNOME][ruby-gnome] gems and other required software libraries must
be installed.


**SUSE, openSUSE***

GObject Introspection development files should be installed before
installing the [Ruby-GNOME][ruby-gnome] gems. This will provide
pkgconfig information and development headers for GObject Introspection
in [Ruby-GNOME][ruby-gnome].

Using the **zypper(8)** package management framework on openSUSE:

~~~~
$ zypper search --provides "pkgconfig(gobject-introspection-1.0)"
S  | Name                        | Summary                                 | Type
---+-----------------------------+-----------------------------------------+--------
   | gobject-introspection-devel | GObject Introspection Development Files | package
$ sudo zypper install gobject-introspection-devel
~~~~

GTK and other GNOME libraries may typically be installed as part of a
desktop environment on the host.

These libraries should be installed separately, along with any
corresponding typelib data, previous to installing the
[Ruby-GNOME][ruby-gnome] gems.

For openSUSE Tumbleweed platforms, the set of package dependencies for
this project includes:

> libatk-1_0-0 libcairo-gobject2 libcairo-script-interpreter2 libcairo2
> libfontconfig1 libfreetype6 libgdk_pixbuf-2_0-0 libgio-2_0-0
> libgirepository-1_0-1 libglib-2_0-0 libgobject-2_0-0 libgthread-2_0-0
> libgtk-3-0 libharfbuzz-gobject0 libharfbuzz-icu0 libharfbuzz-subset0
> libharfbuzz0 libpango-1_0-0 gobject-introspection-devel
> gegl-devel libsecret-devel clutter-devel libgsf-devel
> libpoppler-glib-devel libpoppler-glib-devel clutter-gtk-devel
> gtksourceview-devel webkit2gtk3-soup2-devel libwnck-devel
> gstreamer-devel clutter-gst-devel [...]

The unabridged dependency map should include typelib information as
available on SUSE platforms, for each library.

If the Cinnamon desktop platform or gnome-builder is installed in
addition to `gobject-introspection-devel`, this should serve to ensure
that all dependencies for Ruby-GNOME are installed, including any
library and typelib dependencies.


**Debian-Based Distributions**

On Debian hosts, the set of installation dependencies for
[Ruby-GNOME][ruby-gnome] can be resolved by installing the
`ruby-gnome` Debian package.

The corresponding '-dev' package should also be installed, to ensure
that extensions can be built for the Ruby installation.

~~~~
$ sudo bash -c 'apt-get update && apt-get install ruby-gnome ruby-gnome-dev'
~~~~

**FreeBSD**

On FreeBSD hosts, the set of installation dependencies for
[Ruby-GNOME][ruby-gnome] can be resolved by installing the
`rubygem-gnome` FreeBSD package.

~~~~
$ sudo pkg install rubygem-gnome
~~~~

Similar to the approach with Debian hosts, this will install the latest
[Ruby-GNOME][ruby-gnome] packages for the distribution's default Ruby
version. Independent of whether this specific Ruby version will be used
for Pebbl App development, installing the `rubygem-gnome` pkg will also
serve to ensure that all dependencies are installed for
[Ruby-GNOME][ruby-gnome] support on FreeBSD.

**All Platforms**

A **bundler(1)** _path_ can be configured for this project, such as in
order to install any required gems under the common `vendor/bundle` path
in the working tree.

~~~~
$ cd source_tree && bundle config set path vendor/bundle
~~~~

This will serve to ensure that the gems are configured and built
independent of any gems installed from the host package management
system or **gem(1)**.

Once the build dependencies for any Gem extensions have been installed,
installation under a _bundle path_ will typically not require superuser
credentials.

When installing under a _bundle path_, bundler will use the latest
gem versions available from [Ruby Gems][rubygems], limited to the set of
gem version requirements in this project.

**Compiler Toolchain**

For developing with [Ruby-GNOME][ruby-gnome] and other gems providing
gem extensions in C and C++ programming languages, a **C compiler toolkit**
and **GNU Make** should also be installed. These would be used for building
the gem extensions under the gem installation with **bundler(1)**.

Typically, the extensions will be built with the same compiler toolchain
that was used when building the Ruby implementation.

For example, with openSUSE Tumbleweed:

~~~
irb(main):001:0> RbConfig::CONFIG['CC']
=> "gcc"
irb(main):002:0> RbConfig::CONFIG['CC_VERSION_MESSAGE'].split("\n")[0]
=> "gcc (SUSE Linux) 12.1.0"
~~~

**Development Dependencies**

This project's _development_ dependencies can be installed
separately. These dependencies would normally be required for Pebbl App
development, e.g **rake**, installed under the configured bundle path.

For example, selecting _development_ dependencies before
**bundle-install(1)**:

~~~~
$ cd source_tree && bundle config set --local with development && bundle install
~~~~

**Interactive Evaluation**

With the `Gemfile` configuration in the Pebbl App project, **bundler**
can be configured to install gem support for pry and/or irb together
with the main project gem dependencies.

e.g for pry
> `$ bundle config set with development:pry`

or for irb
> `$ bundle config set with development:pry`

or for both
> `$ bundle config set with development:pry:irb`

and lastly
> `$ bundle install`

or simply
> `$ env BUNDLE_WITH="development:pry:irb" bundle install`

to an effect
> `$ bundle exec pry`
or
> `$ bundle exec irb`

**Debugging**

When **bundler** is configured for development dependencies in this
project, the [`debug` gem][gem-debug] will be available after `bundle
install`.

Once the shell `PATH` environment variable has been configured to
include the exec path for an installation of the [`debug`
gem][gem-debug]:

> `$ rdbg -c bundle exec ruby`

To use the `rdbg` shell command installed by bundler, configuring the
shell `PATH` at runtime:

~~~~
$ PATH="$(bundle exec ruby -e 'puts ENV[%(GEM_HOME)]')/bin${PATH:+:}${PATH}"
$ which rdbg
$ rdbg -c bundle exec ruby
~~~~

### Primary Work Areas

#### Project Tooling

The `pebbl_app-support` gem provides some generic support for
projects and applications, independent of Gtk support.

The project support code has been organized under the **PebblApp::Project**
module, available with the gem `pebbl_app-support`

- **PebblApp::Project::YSpec** providing support for a YAML-based
  gemspec configuration, for projects publishing any one or more
  gemspecs within a single source tree.

- **PebblApp::Project::ProjectModule** providing a Ruby module
  definition for _extension by include_ in other Ruby source
  modules. This module provides methods for defining autoloads within
  the immediate namespace of an including module, with filenames
  resolved relative to a source pathname interpolated or configured
  for the including module. Using autoloads as resolved relative to
  some configured source path, this may serve to minimize the number of
  `require` calls needed for resolving all Ruby constant references
  within any single Ruby source file.

#### Application Support

The `pebbl_app-support` gem  provides reusable code for applications
using Pebbl App. This support code is organized within the
**PebblApp::Support** module.

This includes the generic **PebblApp::Support::App** class, which can be
extended individually, and the **PebllApp::Support::AppPrototype**
module, which can be applied via `include` in the definition of any
application class in Ruby.

#### GTK Applications (Prototyping)

The `pebbl_app-gtk_support` and `riview` gems serve as a combined work
area for development of GNOME application support in Ruby, in the Pebbl
App project.

(Documentation should be available here, after further testing for Gtk
application support in Pebbl App.)

The `riview` gem may serve as a proof of concept for Glade/UI builder
support with GTK and [Ruby-GNOME][ruby-gnome]. This gem uses the local
`rikit` codebase, in a prototype for a documentation browser in
Ruby. The prototype is an early stage of development.

## Tests

The `pebbl_app-support` and `pebbl_app-gtk_support` gems are accompanied
with RSpec tests, available in this project's source tree under the path,
[spec/](./spec/)

Assuming that Bundler has installed the development dependencies for
this project, the status of the tests may be viewed with the following
shell command:

> `bundle exec rake spec`

**Tests Requiring Gtk/Gdk X11 Support**

Some of the tests for this project will require the availability of an X
Window System display, mainly at and after any call to `Gtk.init`.

If **Xvfb** is installed and no `DISPLAY` environment is configured, the
project's primary `spec_helper.rb` will initialize an **Xvfb** process
for the duration of the rspec tests.

In the project Rakefile, the `spec` task will ensure that `DISPLAY`
is unset - by side effect, ensuring that **Xvfb** will be used for the
test environment - when **Xvfb** is installed.

**Xvfb** may typically be available via the host package management system.

* **openSUSE:** `xorg-x11-server-Xvfb`
* **Debian:** `xvfb`
* **FreeBSD:** `xorg-vfbserver` (port `x11-servers/xorg-vfbserver`)

If **Xvfb** cannot be installed, the same rspec tests can be run
directly, using any active X11 display, via `bundle exec rspec`

## History

The [PebblApp project][pebblapp] project was created originally to serve
as a central development project for a small number of Ruby projects
developed at Thinkum.Space.

#### Sandbox

The sandbox sections of the project's source tree retain some earlier
Ruby gem prototypes, from previous to the development of this
centralized project at Thinkum.Space.

[pebblapp]: https://github.com/rubyblox/pebbl_app
[rubygems]: https://www.rubygems.org/
[ruby-gnome]: https://github.com/ruby-gnome/ruby-gnome
[gem-debug]: https://rubygems.org/gems/debug

<!--  LocalWords:  Pebbl Thinkum GTK openSUSE GObject pkgconfig zypper -->
<!--  LocalWords:  gobject devel sudo typelib dev FreeBSD rubygem cd mv -->
<!--  LocalWords:  depdendencies bundler config rubygems Toolchain irb -->
<!--  LocalWords:  toolchain gcc Gemfile bak fi rspec Xvfb env xorg gtk -->
<!--  LocalWords:  xvfb vfbserver pebbl YAML gemspec gemspecs autoloads -->
<!--  LocalWords:  namespace pathname riview UI rikit PebblApp pebblapp -->
