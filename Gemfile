# frozen_string_literal: true
#
# Gemfile for RbLib
#

##
## this file is loaded twice, in 'bundle install'
##
puts "Loading #{binding.source_location[0]} (#{self.class})"

module RbLib
  module Dist
    class BundleTool < Bundler::Dsl
      ## prefer installed gems if available
      def self.def_gems(which)
        gem_map = {}

        which.each { |g|

          puts "Searching for #{g}" if $DEBUG

          case g
          when Array
            name = g[0]
            quals = g[1..]
          else
            name = g
            quals = []
          end

          gem_map[g] = false

          req = Gem::Dependency.new(name,*quals);

          catch (:found) do
            ## This will simply iterate across all cached gemspecs,
            ## until finding the first available match for each
            ## Gmefile dependency. Anything not found will be installed
            ## from the URL provided to the 'source' method at the Gemfile
            ## top-level.
            Gem::Specification.each { |s|
              puts "Searching for #{name} ?= #{s.name} @ #{s.version}" if $DEBUG
              if s.satisfies_requirement?(req)
                origin = s.loaded_from
                whence = File.dirname(origin)
                puts "Using #{origin} for #{name}"
                gem_map[g] = s
                gem(g, source: whence)
                throw :found
              end
            }
          end ## :found
        }
        ## gems not found in any local installation
        gem_map.each do |g, found|
          if !found
            puts "Not found: #{g}" if $DEBUG
            gem g
          end
        end
      end ## BundleTool.def_gems
    end ## BundleTool class
  end ## Dist module
end ## RbLib module

## NB cannot wrap all of these Bundler::Dsl methods in a subclass,
## or things break

source 'https://rubygems.org'

# stdlib = %w(net/http zlib time)

app_gems=	%w(nokogiri gpgme)
dev_gems=	%w(rbs)

RbLib::BundleTool.def_gems(app_gems)
group :development, :optional => true do
  RbLib::BundleTool.def_gems(dev_gems)
end
