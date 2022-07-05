## ApiDb (sandbox)

##
## This source file requires that the rroonga gem is listed in Gemfile.local
##
## see also: Groonga in host package management systems (RPM, Deb, FreeBSD)
##

gem 'rroonga'
require 'rroonga'

require 'fileutils'

module ApiDb

  module Constants
    DBTYPE = ".db".freeze
  end

  ## Proxy class for Groonga::Database applications in ApiDb
  class DbStorage
    attr_reader :name, :dir, :path, :context, :db

    def initialize(name, dir, context: Groonga::Context.default)
      ## TBD `dir` could be selected as a subdir of some
      ## default app data directory. see also: XDG ...
      @name = name
      @dir = File.expand_path(dir)
      fname = File.basename(name, Constants::DBTYPE) + Constants::DBTYPE
      @path = File.join(dir, fname)
      @db = false
    end


    def open()
      ## TBD @ features: fcntl, file locking
      if (opened = dl)
        return opened
      elsif File.file?(self.path)
        @db = Groonga::Database.open(self.path, context: self.context)
      else
        d = self.dir
        FileUtils.mkdir_p(d) if !File.directory?(d)
        @db = Groonga::Database.create(path: self.path, context: self.context)
      end
    end
  end


  ## see api-yardwalk.rb

  class ApiDb
    ## TBD @ features: search for yard (YRI/yardoc)
  end
end
