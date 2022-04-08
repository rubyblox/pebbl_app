## rakeproject.rb

#require('./proj.rb') ## ???
#load('./proj.rb')## and this fails too, now?
require_relative('proj') ## ???
require('rubygems/package_task')

## cf. ../../Rakefile

class RbProject < Proj

  ## TBD storing development_depends, runtime_depends
  ## with a hash whose key is the name of each dependency
  ## and whose value may store an element or array of dependency
  ## qualifiers (version strings) or the value 'true'
  SERIALIZE_FIELDS = Proj::SERIALIZE_FIELDS.dup.
                       concat([[:development_depends, :mapping],
                               [:runtime_depends, :mapping]
                              ])

  ## FIXME need re-map the license[s] name handling onto a seq field

  ## scalar, seq, and mapping field mappings
  ## - FIXME this FieldMapping API should be merged
  ##   with the FieldDesc API more effectively
  ##
  ##   e.g fdesc#add_mapping(ext_class, ext_method, mapping_kind=fdesc.type)
  ##   and fdesc#get_mapping(ext_class)#export(internal_instance,external_instance)
  ##   for an ext_kind of Gem::Specification or ...
  ##
  ##   NB extend forwardable, in each field mapping class - extending
  ##   onto the field description to which each external mapping is bound
  GEMSPEC_FIELDS = [:name, :version, :license,
                    :summary, :description,
                    [:authors, :authors],
                    [:require_paths, :require_paths],
                    [:lib_files, :all_files],
                    [:test_files, :all_files],
                    [:doc_files, :all_files],
                    [:development_depends, :add_development_dependency],
                    [:runtime_depends, :add_runtime_dependency]
                   ]


  extend CollectionAttrs
  attr_seq(:development_depends,
           add_name: :add_development_depends_qualified)
  attr_seq(:runtime_depends,
           add_name: :add_runtime_depends_qualified)

  def self.project(filename,**loadopts)
    self.load_yaml_file(filename, **loadopts)
  end

  def self.join_seq!(value, external)
    if value
      if external
        external.concat(value)
      else
        value
      end
    else
      external
    end
  end

  def add_development_depends(name, version=nil)
    version ||= true
    add_development_depends_qualified(name, version)
  end

  def add_runtime_depends(name, version=nil)
    version ||= true
    add_runtime_depends_qualified(name, version)
  end


  def gemspec()
    ## FIXME use field mapping, self.class => Gem::Specification
    if ! @gemspec
      @gemspec = Gem::Specification.new do |s|
        ## FIXME redefine this as an iterator on some sequence for
        ## gemspec interop
        name && ( s.name = name )
        version && ( s.version = version )
        authors && ( s.authors = authors )
        summary && ( s.summary = summary )
        description && ( s.description = description )
        license && ( s.license = license )
        all_files = lib_files
        test_files && ( all_files = self.join_seq!(test_files,all_files) )
        doc_files && ( all_files = self.join_seq!(doc_files, all_files ))
        s.files = all_files

        if metadata
          ## this will stringify all keys in the metadata table,
          ## such as to be compatible with gemspec syntax
          use_metadata = metadata.map { |k,v| [k.to_s, v] }.to_h
          s.metadata = use_metadata
        end
      end
    end
    yield @gemspec if block_given?
    return @gemspec
  end

  ## FIXME also provide methods onto
  ## Rake::RDocTask
  ## ... rspec && rake ...

  def gem_package_task(spec = gemspec)
    ## TBD no memoization here
    ##
    ## TBD parameterize for site (app) defaults
    ## in any block syntax onto the return?
    task = Gem::PackageTask.new(spec)
    yield task if block_given?
    task.define ## NB run after block, if any
    return task
  end
end
