## rakeproject.rb

#require('./proj.rb') ## ???
#load('./proj.rb')## and this fails too, now?
require_relative('proj') ## ???
require('rubygems/package_task')

## cf. ../../Rakefile

class RbProject < Proj
  def self.project(filename,**loadopts)
    self.load_yaml_file(filename, **loadopts)
  end

  def self.add(value, whence)
    if value
      if whence
        whence.concat(value)
      else
        value
      end
    else
      whence
    end
  end

  def gemspec()
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
        test_files && ( all_files = self.add(test_files,all_files) )
        doc_files && ( all_files = self.add(doc_files, all_files ))
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
