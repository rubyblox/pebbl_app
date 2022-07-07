## ApiDb (sandbox)

##
## This source file requires that the rroonga gem is listed in Gemfile.local
##
## see also: Groonga in host package management systems (RPM, Deb, FreeBSD)
##

gem 'rroonga'
require 'groonga'

require 'fileutils'


module ApiDb

  module Constants
    ## name suffix for DbMgr name => database file paths
    DBTYPE = ".db".freeze
  end

  class DbError < RuntimeError
  end


  ## Database manager for an application of Groonga::Database
  class DbMgr
    attr_reader :name, :dir, :path, :context, :db, :schema

    ## @see #definition_connect
    ## @see #schema_defined
    attr_accessor :table_prefix


    ## @param name [String] name of this database, used mainly for
    ## database files
    ##
    ## @param dir [String] pathname of a directory for database files
    ##
    ## @param context [Groonga::Context] Groonga context for tables
    ##  created in this DbMgr
    ##
    ## @param table_prefix [String, Symbol, nil] If a string or a
    ##  symbol, a prefix for instance varaible and method names created
    ##  under #definition_connect. If nil or false, an empty string will
    ##  be used as the prefix.
    ##
    def initialize(name, dir, context: Groonga::Context.new,
                   table_prefix: :table_)
      ## TBD `dir` could be selected as a subdir of some
      ## default app data directory. see also: XDG ...
      ## ... or as a subdir of some project directory.
      @name = name
      @dir = File.expand_path(dir)
      fname = File.basename(name, Constants::DBTYPE) + Constants::DBTYPE
      @path = File.join(dir, fname)
      @context = context
      @db = false
      @table_prefix = table_prefix
    end

    def to_s
      case self.opened?
      when TrueClass
        state = "opened".freeze
      when NilClass
        state = "closed".freeze
      when FalseClass
        state = "n/a".freeze
      else
        state = "??".freeze
      end
      "#<%s 0x%06x %s @ %s (%s) >".freeze % [
        self.class, __id__, self.name, self.dir, state
      ]
    end

    ## create or open the db instance for this DbMgr
    ##
    ## @return [Groonga::Database] the db instance
    ##
    ## @see #db
    ## @see #close
    ## @see #schema_define
    ## @see #update
    def open()
      ## TBD @ features: fcntl, file locking
      ##
      ## NB past here:
      ##  self.context == self.db.context
      if (inst = self.db)
        return inst
      elsif File.file?(self.path)
        @db = Groonga::Database.open(self.path context: self.context)
      else
        datadir = self.dir
        FileUtils.mkdir_p(datadir) if !File.directory?(datadir)
        @db = Groonga::Database.create(path: self.path, context: self.context)
      end
    end

    ## When the db instance for this DbMgr is initialized, returns true if
    ## the database is in an opened state, else nil. When no db instance
    ## is initailzied, returns false.
    def opened?
      if (inst = self.db)
        if inst.closed?
          ## returning nil instead of !inst.closed?
          nil
        else
          true
        end
      else
        ## returning false when there is no self.db
        false
      end
    end

    ## close the datbase for this DbMgr and remove all files for the
    ## database
    ##
    ## @return [Array<String>, false] an array of the filenames removed,
    ##  or false if no files were found for this DbMgr
    def destroy()
      self.close
      files = Dir.glob(self.path + "*")
      if files.empty?
        Kernel.warn("#{self.class}#{__method__}: \
Found no files for database #{self}", uplevel: 0)
        return false
      else
        FileUtils.rm(files, force: true)
        return files
      end
    end

    ## if the db instance for this DbMgr is initialized, closes the db
    ## instance
    def close()
      if (inst = self.db)
        inst.close
        @db = false
      end
    end

    def schema(**options)
      ## schema options will be used as default options (args)
      ## for each call to schema.create_table
      ##
      ## e.g options
      ##  type: <trie_type_symbol>
      ##  default_tokenizer: "TokenBigram"
      ## equivalent to the options args for schema.create_table
      ## http://ranguba.org/rroonga/en/file.tutorial.html
      opts = options.dup
      opts[:context] ||= self.context
      if (inst = @schema)
        schema_opts = inst.instance_variable_get(:@options)
        opts.each do |k, v|
          schema_opts[k] = v
        end
        inst
      else
        @schema = Groonga::Schema.new(opts)
      end
    end

    ## Define an instance variable and a reader method for accessing the
    ##  table described in the table definition
    ##
    ## **Known Limitation:** This release of the DbMgr API has not included
    ##  extensive testing for the behaviors of this method with relation
    ##  to individual tables, as subsequent of any schema redefinition.
    ##  Absent of further testing for this feature of the API, it
    ##  may be recommended to define the schema exactly once within
    ##  each process environment, using #schema_define
    ##
    ## @param definition [Groonga::Schema::TableDefinition]
    ##
    ## @see #schema_define
    def definition_connect(definition)
      name = definition.name
      s_name = name.downcase
      if (pfx = self.table_prefix)
        pfx = pfx.to_s
      else
        pfx = "".freeze
      end
      ivar = ("@".freeze + pfx + s_name).to_sym

      if self.instance_variable_defined?(ivar)
        false
      else
        ## prefer any context defined for the table itself,
        ## using options from the table definition
        if ! ( (def_opts = definition.instance_variable_get(:@options)) &&
              (tbl_ctx = def_opts[:context]))
          ## else use the context for this DbMgr
          tbl_ctx = self.context
        end
        ## retrieve the table and bind a method, or raise DbError
        if (tbl = tbl_ctx[name])
          self.instance_variable_set(ivar, tbl)
          mtd = (pfx + s_name).to_sym
          lmb = lambda { tbl }
          self.class.define_method(mtd, &lmb)
        else
          raise DbError.new("Table from schema not found in context: %p @ %s" %
                            [name, tbl_ctx])
        end
      end
    end

    ## define or update the schema for this instance
    ##
    ## The active schema for this instance will be yielded to the
    ## provided block.
    ##
    ## Subsequently, Groonga::Schema#define will be called for the schema
    ## object
    ##
    ## After the call to Groonga::Schema#define, each table definition
    ## in the schema will be passed to #definition_connect
    ##
    ## The DbMgr#definition_connect method will define an instance
    ## method for each table. Classes may override this method as
    ## needed.
    ##
    ## **Known Limitation:** This release of the DbMgr API has not
    ## included support for persistent schema storage. There is an API
    ## available for this feature, in Groonga
    ##
    def schema_define(&block)
      inst = self.schema
      yield inst
      ## important to call Schema#define after defining the schema,
      ## This would ensure that tables described in the schema will be
      ## available under the context for each table.
      inst.define
      inst.instance_variable_get(:@definitions).each do |defined|
        self.definition_connect(defined)
      end
      return inst
    end

    ## a forwarding method, returning the tables of the database
    ## instance for this datbase manager
    ##
    ## raises DbError if the database #db is not open
    def tables()
      if (inst = self.db)
        inst.tables
      else
        ## avoiding an invalid API call => segfault ...
        raise DbError.new("Database not open: #{self}")
      end
    end

    ## return a named table for the #context of this DbMgr
    ##
    ## raises DbError if the database #db is not open
    ##
    ## @param name [String] a table name
    ##
    ## @see #schema_define
    ##
    def [](name)
      ## table accessor @ Groonga context scope
      if self.opened?
        self.context[name]
      else
        raise DbError.new("Database not open: #{self}")
      end
    end

    ## Add or update the field data for a record in a named table.
    ##
    ## This method will raise a DbError if the db for this DbMgr is not
    ## open.
    ##
    ## Supported field options:
    ##
    ## - If the column name `:_key` is provided, this method will raise
    ##   an ArgumentError. The calling method should provide the key
    ##   object for each record via the _key_ parameter on this method.
    ##
    ## - If the column name `:_id` is provided, this method will raise
    ##   an ArgumentError. The `:_id` value may be used internally in
    ##   Groonga, such as for identifying individual table rows. The
    ##   record `_id` should not be provied during record update.
    ##
    ## - For other fields, each provided field value should match the
    ##   syntax specified when defining the corresponding column for
    ##   this table in the schema.
    ##
    ## @param table [String] a table name, under the active schema
    ##
    ## @param key [Object] a key value uniquely identifying the record
    ##  within the named table. The syntax for this value may be
    ##  determined for each table when defining the schema. If this key
    ##  value matches an existing key in the table, the record for the
    ##  existing key will be updated with the field values as provided.
    ##
    ## @param fields [Hash] A mapping of column names (symbols) with
    ##  field values for the record. The syntax for each field value
    ##  may be determined when defining the schema.
    ##
    ## @see #schema_define
    ##
    def update(table, key, **fields)
      if fields[:_key]
        raise ArgumentError.new("Invalid field name :_key")
      elsif fields [:_id]
        raise ArgumentError.new("Invalid field name :_id")
      elsif (tbl = self[table])
          tbl.add(key, **fields)
      else
        raise DbError.new("Table not found: #{table}")
      end
    end

  end ## DbMgr


  ## see api-yardwalk.rb

  class YardMgr < DbMgr
    ## see api-test.db
  end

end
