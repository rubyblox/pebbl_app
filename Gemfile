# frozen_string_literal: true
#
# Gemfile for distkit
#

##
## this file is loaded twice, in 'bundle install'
##
puts "Loading #{binding.source_location[0]} (#{self.class})"

module DistKit
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
          ## FIXME find_all_by_name is frankly misleading, it does not
          ## "find all". Neither does Gem::Specifications.each, actually.
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
    end
  end
end

source 'https://rubygems.org'

# stdlib = %w(net/http zlib time)

app_gems=	%w(nokogiri gpgme)
dev_gems=	%w(rbs)

DistKit::BundleTool.def_gems(app_gems)
group :development, :optional => true do
  DistKit::BundleTool.def_gems(dev_gems)
end
