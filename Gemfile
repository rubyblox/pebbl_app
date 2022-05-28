# frozen_string_literal: true
#
# Gemfile for RbLib
#

source 'https://rubygems.org'

# stdlib = %w(net/http zlib time)

runtime_gems=	%w(nokogiri)
tool_gems=	%w(rbs)

runtime_gems.each do |name|
  gem name
end

group :development, :optional => true do
  tool_gems.each do |name|
    gem name
  end
end
