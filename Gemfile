# frozen_string_literal: true
#
# Gemfile for RbLib
#

source 'https://rubygems.org'

# stdlib = %w(net/http zlib time)

## NB gpgme usage
## refer to lib/pkg/rpm/rpmwalk.rb

runtime_gems=	%w(nokogiri gpgme)
tool_gems=	%w(rbs rake rspec standard debug)

project_gems=	%w(thinkum_space-project rikit riview gappkit)

runtime_gems.each do |name|
  gem name
end

group :development, :optional => true do
  tool_gems.each do |name|
    gem name
  end
end

## $DEBUG = true serves to illustrate some odd output with irb under iruby
$DEBUG = true

if $DEBUG
  ##
  ### The following will result in some informative output, albeit delimited
  ### with null characters and not particularly early in the gem resolver process
  ###

  ## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/resolver.rb
  ## @ Bundler::Resolver#debug?
  ENV['BUNDLER_DEBUG_RESOLVER'] = "Defined"

  ## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/vendor/molinillo/lib/molinillo/modules/ui.rb
  ## @ Bundler::Molinillo::UI (Module)
  ENV['MOLINILLO_DEBUG'] = "Defined"
end ## $DEBUG


## NB 'gemspec' method args,
## from e.g
## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/dsl.rb
## :path (default "."), :glob, :name, :development_group (default :development)

##
## This file is being loaded twice in one 'bundle install'
##
## The second evaluation may entail a recursive parse of gemspec deps
##
project_gems.each do |name|
  STDERR.puts("DEBUG gemspec: #{name}") if $DEBUG
  gemspec name: name
  ## FIXME here, ensure that each named gem will be available to each
  ## subsequent gem in project_gems
end
# $GEMFILE_SOURCE = __FILE__

