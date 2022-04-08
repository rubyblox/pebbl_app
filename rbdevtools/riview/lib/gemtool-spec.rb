
  require 'forwardable'
  ## Utility class for caching of the specification file's last modified
  ## time.
  class Spec
    extend('Forwardable')

    def_delegators(:@instance,*Gem::Specification.instance_methods(false).
                   dup.concat(Gem::BasicSpecification.instance_methods(false)))

    attr_accessor :instance
    attr_accessor :mtime

    def initialize(spec)
      @instance = spec
    end

    def self.from_spec(spec)
      self.new(spec)
    end

    alias :to_spec :instance
  end
