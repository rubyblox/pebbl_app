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


    ## Initialize a new DbMgr for persistent storage under some data
    ## directory.
    ##
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
      @mtx = Mutex.new
    end

    ## Return an abbreviated string representation for this DbMgr
    ##
    ## The string will indicate the class, object id, database name,
    ## database directory, and db open state for this DbMgr
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
      "#<%s %s @ %s (%s) 0x%06x>".freeze % [
        self.class, self.name, self.dir, state, __id__
      ]
    end

    def with_mgr_lock(&block)
      ## not quite a recursive mutex
      ##
      ## FIXME this uses no timeout
      mtx = @mtx
      begin
        new_lk = (mtx.lock if !mtx.owned?)
        yield
      ensure
        mtx.unlock if new_lk
      end
    end

    ## Create or open the db instance for this DbMgr
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
      with_mgr_lock do
        if (inst = self.db)
          if inst.closed?
            @db = nil
            open()
          else
            return inst
          end
        elsif File.file?(self.path)
          @db = Groonga::Database.open(self.path, context: self.context)
        else
          ## if some files exist at time of database create, Groonga may
          ## emit an error suggesting no memory is available, e.g given a
          ## file with a suffix ".0000000" on the db path for the database
          datadir = self.dir
          FileUtils.mkdir_p(datadir) if !File.directory?(datadir)
          @db = Groonga::Database.create(path: self.path, context: self.context)
        end
      end ## mtx.synchronize
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

    ## A utility method, yielding the database for this DbMgr to the
    ## provided block
    ##
    ## @raise [DbError] if the database is not opened
    def with_db(&block)
      with_mgr_lock do
        if (inst = self.db) && !inst.closed?
          yield inst
        else
          raise DbError.new("Database not open for #{self}")
        end
      end
    end

    ## return an array of filenames used by the database for this DbMgr
    ##
    ## @raise [DbError] if the database is not opened
    ##
    ## @see #db_files_glob
    def db_files
      with_db do |db|
        base = db.path
        conf = base + ".conf".freeze
        options = base + ".options".freeze
        f001 = base + ".001".freeze
        specs = base + ".0000000".freeze
        files = [base, conf, options, f001, specs]
        db.tables.each do |tbl|
          files << tbl.path
          tbl.columns.each do |col|
            colbase = col.path
            files << colbase
            colbase_idx = colbase + ".c".freeze
            files << colbase_idx
          end
        end
        return Dir.glob(files)
      end
    end

    ## Return an array of filenames estimated to be used by the database
    ## for this DbMgr
    ##
    ## This method uses a filename globs pattern such that does not
    ## require that the database is opened. This may match files not in
    ## use by the database.
    def db_files_glob
      dbf = self.path
      if File.exist?(dbf)
        return [dbf, * Dir.glob(dbf + ".*".freeze)]
      else
        return []
      end
    end

    ## Close the datbase for this DbMgr and remove all files for the
    ## database.
    ##
    ## For purpose of constructing a list of files for the database, this
    ## method requires that the database would be opened. The database
    ## will be closed before removing files. If the database cannot be
    ## opened, the files list returned by #db_files_glob can be reviewed
    ## separately, before removing any files indicated with that method.
    ##
    ## @return [Array<String>, false] an array of filenames for removed
    ##  files, or false if no files were found for this DbMgr
    ##
    ## @raise [DbError] if the database cannot be opened
    def destroy()
      files = []
      begin
        self.open
        files = self.db_files
      ensure
        self.close
      end
      files.filter! { |f| File.exist?(f) }
      if files.empty?
        Kernel.warn("#{self.class}#{__method__}: \
Found no files for database #{self}", uplevel: 0)
        return false
      else
        FileUtils.rm(files, force: true)
        return files
      end
    end

    ## If the db instance for this DbMgr is initialized, close the db
    def close()
      if (inst = self.db)
        inst.close
        @db = false
      end
      ## if (ctxt = self.context)
      ##   # ctxt.close # FIXME on finalization
      ## end
    end

    ## Retrieve the schema for the database of this DbMgr. The schema
    ## will be configured with the provied schema options.
    ##
    ## In Rroonga, schema options may be used to provide default options
    ## for each call to Schema#create_table
    ##
    ## See also: Groonga::Schema#create_table and the Rroonga tutorial
    ## * (ja) http://ranguba.org/rroonga/ja/file.tutorial.html
    ## * (en) http://ranguba.org/rroonga/en/file.tutorial.html
    ##
    ## @see #schema_define
    def schema(**options)
      ##
      ## e.g options
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

    ## Define a reader method for accessing the table described
    ## in the table definition.
    ##
    ## The name of the reader method will be interpolated as the
    ## table_prefix for this DbMgr suffixed with a downcased
    ## representation of the table name.
    ##
    ## This will redefine any existing instance method for the
    ## interpolated method name.
    ##
    ## @param definition [Groonga::Schema::TableDefinition]
    ##
    ## @see #schema_define
    def definition_connect(definition)
      ## TBD this could be defined and evaluated at a class scope,
      ## but requires instance variable access for the database
      ##
      ## See also: Active Record
      ##
      name = definition.name
      s_name = name.downcase
      if (pfx = self.table_prefix)
        pfx = pfx.to_s
      else
        pfx = "".freeze
      end

      ## determine what context to use for retrieving the table
      ##
      ## this will prefer any context provided in the schema definition
      ## for the table
      if ! ( (def_opts = definition.instance_variable_get(:@options)) &&
             (tbl_ctx = def_opts[:context]) )
        ## else use the context for this DbMgr
        tbl_ctx = self.context
      end

      ## retrieve the table and bind a method that will return that
      ## table, or raise a DbError if the table is not found
      if (tbl = tbl_ctx[name])
        mtd = (pfx + s_name).to_sym
        lmb = lambda { tbl }
        self.class.define_method(mtd, &lmb)
      else
        raise DbError.new("Table from schema not found in context: %p @ %s" %
                          [name, tbl_ctx])
      end
    end

    ## define or update the schema for this instance
    ##
    ## The schema for this instance will be yielded to the provided block.
    ##
    ## After the block, Groonga::Schema#define will be called for the
    ## schema.
    ##
    ## After the call to Groonga::Schema#define, each table definition
    ## in the schema will be passed to the method #definition_connect
    ##
    ## **Known Limitation:** This release of the DbMgr API has not
    ## included support for persistent schema storage with Groonga.
    ##
    ## @raise [DbError] if the database for this DbMgr is not opened
    def schema_define(&block)
      with_db do
        sch = self.schema
        yield sch
        ## important to call Schema#define after defining the schema,
        ## This would ensure that tables described in the schema will be
        ## available under the context for each table.
        ##
        ## TBD (should) fail if calling this after #close on the db
        ##
        sch.define
        sch.instance_variable_get(:@definitions).each do |defn|
          self.definition_connect(defn)
        end
        return sch
      end
    end

    ## a forwarding method, returning the array of tables for the
    ## database instance of this datbase manager
    ##
    ## @raise [DbError] if the database for this DbMgr is not opened
    def tables()
      with_db do |db|
        db.tables
      end
    end

    ## return a named table for the #context of this DbMgr
    ##
    ## @param name [String] a table name
    ##
    ## @see #schema_define
    ##
    ## @raise [DbError] if the database for this DbMgr is not opened
    def [](name)
      with_db do |db|
        db.context[name]
      end
    end

    ## forwarding to Groonga::DatabaseInspector, produce a report for
    ## the database of this DbMgr
    ##
    ## @param output [IO] output stream for the report
    ##
    ## @param tables [boolean] true if database tables should be
    ##  inspected for the report
    ##
    ## @param colunmns [boolean] true if table columns should be
    ##  inspected for the report
    ##
    ## @raise [DbError] if the database for this DbMgr is not opened
    def report(output: STDOUT, tables: true, columns: true)
      with_db do |db|
        opts = Groonga::DatabaseInspector::Options.new
        opts.show_tables = tables
        opts.show_columns = columns
        ictor = Groonga::DatabaseInspector.new(db, opts)
        ictor.report(output)
        return ictor
      end
    end

    ## Add or update the field data for a record in a named table.
    ##
    ## @param table [String] a table name, under the active schema
    ##
    ## @param key [Object] a key value uniquely identifying the record
    ##  within the named table. The syntax for this value may be
    ##  determined for each table when defining the schema. If this key
    ##  value matches an existing key in the table, the record for the
    ##  existing key will be updated with the field values as provided.
    ##
    ## @param fields [Hash] An options map providing column names
    ##  (symbols) with field values for the data record. The syntax for
    ##  each field value may be determined when defining the schema.
    ##
    ## @see #schema_define
    ##
    ## @raise [DbError] if the database for this DbMgr is not opened, or
    ##  if no table is found for the provided table name
    ##
    ## @raise [ArgumentError] if the column name `:_key` is provided.
    ##  The calling method should provide the key for the record via the
    ##  _key_ parameter on this method.
    ##
    ## @raise [ArgumentError] if the column name `:_id` is provided. The
    ##  `:_id` column may be used internally in Groonga and should not be
    ##  provied during record update.
    def update(table, key, **fields)
      with_db do
        ## TBD testing for thread-safe update in some subclass
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
    end

  end ## DbMgr


  ## see api-yardwalk.rb

  class YardMgr < DbMgr
    ## see api-test.db
  end

end
