# Gemfile for rblib


source 'https://rubygems.org'

## ensure that 'require' can be used during project development, for
## accessing project source files within project gemspec files, by
## adding the relative "lib" dir as an absolute pathname in $LOAD_PATH
if ! $LOAD_PATH.member?(File.join(__dir__, "lib"))
  $LOAD_PATH.unshift(File.join(__dir__, "lib"))
end

# stdlib = %w(net/http zlib time)

## NB gpgme usage
## refer to lib/pkg/rpm/rpmwalk.rb

runtime_gems=	%w(nokogiri gpgme)
tool_gems=	%w(rbs rake rspec standard debug)

project_gems=	%w(thinkum_space-project rikit riview gappkit)

@gems_defined ||= {}

runtime_gems.each do |name|
  s_name = name.to_sym
  if @gems_defined[s_name]
    STDERR.puts("Gem already defined: #{name}") if $DEBUG
  else
    gem name
    @gems_defined[s_name] = true
    STDERR.puts("Defined gem: #{name}") if $DEBUG
  end
end

group :development, :optional => true do
  tool_gems.each do |name|
    if @gems_defined[name.to_sym]
      STDERR.puts("Gem already defined: #{name}") if $DEBUG
    else
      gem name
      @gems_defined[name.to_sym] = :development
      STDERR.puts("Defined gem (:development): #{name}") if $DEBUG
    end
  end
end

## $DEBUG = true serves to illustrate some particular debugging output
#$DEBUG = true

if $DEBUG
  ## enable some more of infomrative output from bundler

  ## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/resolver.rb
  ## @ Bundler::Resolver#debug?
  ENV['BUNDLER_DEBUG_RESOLVER'] = "Defined"

  ## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/vendor/molinillo/lib/molinillo/modules/ui.rb
  ## @ Bundler::Molinillo::UI (Module)
  ENV['MOLINILLO_DEBUG'] = "Defined"
end ## $DEBUG


## NB args on the Gemfile 'gemspec' method, from e.g
## /usr/local/lib/ruby/gems/3.1/gems/bundler-2.3.14/lib/bundler/dsl.rb
## :path (default "."), :glob, :name, :development_group (default :development)

project_gems.each do |name|
  s_name = name.to_sym
  if @gems_defined[s_name]
    STDERR.puts("Gem already defined: #{name}") if $DEBUG
  else
    STDERR.puts("Defining gem (gemspec): #{name}") if $DEBUG
    gemspec name: name
    @gems_defined[s_name] = :gemspec
    STDERR.puts("Defined gem (gemspec): #{name}") if $DEBUG
  end
end



