PebblApp from Thinkum.Space
===========================

**Introducing PebblApp**

The [PebblApp project][pebblapp] was created to serve as a central
development project for a small number of Ruby projects developed at
Thinkum.Space.

## Rationale: Design Goals

This project provides central development tooling for a number of Ruby
gems developed in this project.

Reusable sections of this code have been bundled in the stand-alone
gem, `thinkum_space-project`. This gem finds an application for
development of this and other gems developed in this source repository.

### Primary Work Areas

#### Project Tooling

The `thinkum_space-project` gem provides some stand-alone development
tooling for Ruby projects developed at Thinkum.Space. This support code
has been organized under the module **PebblApp::Project**

Primary features as published in this gem may include:

- **PebblApp::Project::YSpec** providing support for a YAML-based
  gemspec configuration method, for projects publishing any one or more
  gemspecs within a single source tree.

- **PebblApp::Project::ProjectModule** providing a Ruby module
  definition for extension by inclusion in other Ruby source
  modules. This module provides methods for defining autoloads within
  the immediate namespace of an including module.

#### GTK Applications (Prototyping)

The `pebbl_app-gtk_support`, `riview`, and `rikit` gems serve as a
combined work area for GNOME application support in Ruby. These gems are
developed local to this project and have not been published to
[rubygems.org][rubygems]

#### Sandbox

The sandbox sections of the project's source tree would serve a purpose for
retaining some earlier Ruby gem prototypes, from previous to the
development of this centralized project at Thinkum.Space.

[pebblapp]: https://github.com/rubyblox/pebbl_app
[rubygems]: https://www.rubygems.org/

