# gemdocs.rb


## [PROTOTYPE]

=begin remarks

Remarks: Gem::Specification.load(file)
- loads a Gem specification exactly once,
  subsequently reusing any stored specification
  in Gem::Specification::LOAD_CACHE

  -  Gem::Specification::LOAD_CACHE has been defined as
     a private constant, and is still accessible via
     Gem::Specification.const_get(:LOAD_CACHE)

=end

## NB for a Gem::Specification s => s.full_gem_path

require 'rubygems'
require 'yard'
require 'rbconfig'

require_relative 'spectool'

class GemDocs
  APP_DIRNAME=self.name.downcase

  ## file types to parse, by default
  PARSE_FILE_TYPES=YARD::Templates::Helpers::MarkupHelper::
    MARKUP_EXTENSIONS.values.flatten

  def self.spec_docs_path(s)
    fullname=s.name + "-" + s.version.to_s
    p = s.full_gem_path
    #if p.match?("^" + RbConfig::CONFIG['rubylibprefix'])
    ## NB rublibprefix is used in computing a default Gem.default_dir
    ## such that may be overridden with the GEM_HOME environment
    ## variable, in some methods - e.g via Gem::PathSupport. This
    ## value may then be used in e.g Gem::Installer, as when
    ## constructing a Gem's filesystem paths (gem_dir and subsq)
    ## - avl at runtime via Gem.paths.home
    ##
    if p.match?("^" + Gem.paths.home)
      ## NB datadir may be e.g /usr/share,
      ## under one common Ruby installation prefix
      host_datadir=RbConfig::CONFIG['datadir']
      return File.join(host_datadir, APP_DIRNAME, fullname)
    elsif p.match?("^" + Gem.user_dir)
      ## NB one default Gem.data_home =~ ~/.local/share
      return File.join(Gem.data_home, APP_DIRNAME, fullname)
    else
      ## assumption: gem is installed under some form of a project
      ## directory. FIXME this branch needs testing e.g w/ bundler paths
      ##
       return File.join(s.full_gem_path, "doc") ## ?? (TBD, see also bundler)
    end
  end


  def self.build_gemdocs(name, **yardopts)
    ## NB for syntax of yardopts, refer to YARD::CLI::YardocOptions src
    s = ::GemReg::SpecTool::find_gem_spec(name)
    ## ^ FIXME this is not resulting in a correct value for #full_gem_path
    puts "DEBUG:G building docs for Gem Spec #{s.name}"
    self.build_specdocs(s, **yardopts)
  end

  def self.build_specdocs(spec, **yardopts)
    ## NB for syntax of yardopts, refer to YARD::CLI::YardocOptions src
    files = spec.files.filter{ |f|
      if ( ext = File.extname(f) )
          ext = ext[1..]
          PARSE_FILE_TYPES.any? { |type|
            type == ext
          }
      end
    }
    files.concat(spec.extra_rdoc_files)
    puts "DEBUG:F building docs with #{files.length} files"
    #specdir = spec.full_gem_path
    ## ^ DNW here. workaround for a bug/error in spec source eval:
    specdir = File.dirname(spec.loaded_from)
    files.map! { |f| File.expand_path(f,specdir) }
    self.build_filedocs(files,**yardopts)
  end

  def self.build_filedocs(files, **yardopts)
    ## cf. YARD::CLI::Yardoc.run ...
    ##  ... run_generate(checksums) cf. use_cache @ checksums (??)
    ##  ... YARD.parse(files,??)
    runner = YARD::CLI::Yardoc.new
    ## runner.options ...
    ## NB YARD::CLI::Yardoc#parse_arguments
    runner.files = files ## ??

    ## NB runner.options => ...

    #puts "DEBUG:f #{files}"

    runner.send(:log).show_progress=true
    runner.send(:log).level=Logger::DEBUG
    ## no-nop (??)
    #runner.send(:run_generate,false)
    ## also no-op (??)
    #YARD.parse(files)
    ## ^ similar to: YARD.parse ## no args

    ## FIXME retry some of the following, with the updated spec
    ## files list builder

    ## NB #parse at line 100 of source_parser.rb - line nr & file
    ## via YARD::Parser::SourceParser.method(:parse).source_location
    #YARD.parse(files,[],Logger::DEBUG)

    ## alternately (??)
    #parser = YARD::Parser::SourceParser.new(??type??)


    #runner.run()
    ## ^ "Could not load default RDoc formatter"
    runner.run(nil)  ## does mostly nothing - skipping #parse_arguments
    ## ^ produces doc/** boilerplate, but otherwise nothing

  end
end

# Local Variables:
# fill-column: 65
# End:

