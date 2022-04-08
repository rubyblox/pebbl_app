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

## FIXME spectool.rb moved to rbdevtools/riview/sandbox/spectool.rb
require_relative 'spectool'

class GemDocs ## FIXME rename => YARDocTool ....
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

  ## NB see also ./gemreg.rb. ./spectool.rb

  def self.build_gemdocs(name, **yardopts)
    ## NB for syntax of yardopts, refer to YARD::CLI::YardocOptions src
    s = ::GemReg::SpecTool.find_gem_spec(name)
    ## ^ FIXME this is not resulting in a correct value for #full_gem_path
    puts "DEBUG:G building docs for Gem Spec #{s.name}"
    self.build_specdocs(s, **yardopts)
  end

  def self.build_specdocs(spec, **yardopts)
    ## NB for syntax of yardopts, refer to YARD::CLI::YardocOptions src
    files = ::GemReg::SpecTool.spec_lib_files(spec)
    self.build_filedocs(files, **yardopts)
  end

  def self.build_filedocs(files, **yardopts)
    ## cf. YARD::CLI::Yardoc.run ...
    ##  ... run_generate(checksums) cf. use_cache @ checksums (??)
    ##  ... YARD.parse(files,??)
    runner = YARD::CLI::Yardoc.new
    ## runner.options ...
    ## NB YARD::CLI::Yardoc#parse_arguments
    #runner.files = files ## ??

    ## NB runner.options => ... (options for the parse)
    ## FIXME set runner.options.serializer.basepath => absolute path
    ## (e.g tmpdir for tests)
    ##
    ## NB here runner.options.serializer is a YARD::Serializers::FileSystemSerializer

    #puts "DEBUG:f #{files}"

    runner.send(:optparse, "-o", "/tmp/frobdocs") ## NB uses *args syntax
    ## TBD still producing only boilerplate files, no actual docs

    puts "DEBUG: Using serializer #{runner.options.serializer.inspect}"
    #return -1


    runner.send(:log).show_progress=true
    runner.send(:log).level=Logger::DEBUG ## ... verbose

    ## no-nop (??)
    #runner.send(:run_generate,false)
    ## also no-op (??)
    #YARD.parse(files)
    ## ^ similar to: YARD.parse ## no args

    ## FIXME retry some of the following, with the updated spec
    ## files list builder

    ## NB #parse at line 100 of source_parser.rb - line nr & file
    ## via YARD::Parser::SourceParser.method(:parse).source_location
    ##
    #YARD.parse(files,[],Logger::DEBUG) ## nothing, does not even generate boilerplate

    ## alternately (??)
    #parser = YARD::Parser::SourceParser.new(:ruby)
    #parser.parse(files,[],Logger::DEBUG) ## NOPE

    ## ...
    #YARD::Parser::SourceParser.parse(files,[],Logger::DEBUG) ## nothing


    # runner.generate = true ## ?? a default
    # runner.save_yardoc = true ## another default. no effect on the absence of useful file output
    ##
    ## is YARD.parse where it's failing to write anything useful
    # to the basedir?

    #runner.list = true  ## mutually exclusive to 'generate'

    ## FIXME parse *.rb and e.g *.rdoc files with separate
    ## parsers ?? ... TBD how to provide top-level *.rdoc files to
    ## YARD, which presumably includes an rdoc parser already.

    ## FIXME try to parse spec.rdoc_options for YARD ... above ^^
    ## or simply use rdoc instead of YARD, when the gem spec includes
    ## an rdoc_options or extra_rdoc_files attr?

    # runner.send(:optparse,*files) ## N/A ?

    ## NB THIS is how to provide the files list:
    runner.run(*files)

    ## FIXME generating YARD docs for all source files in the
    ## yard gem, this results in a lot of spurious names in the
    ## output, e.g 'ABC' module, presumably from test files
    ##
    ## NB This is still the case, even when filtering on the
    ## require_paths for the gem, per se YARD.
    ##
    ## - Does the YARD project's rakefile define some novel way
    ##   to build its documentation?
    ##
    ## - This lot of arbitrary hacking does not serve to provide
    ##   a basis for any normal documentation system onto Ruby,
    ##   outside of so many project-specific contrivances
    ##  (see alternately: ports? can the docs be installed with gems, there?)

    ## 'gem install' generates docs singularly for 'ri' ??
  end
end

# Local Variables:
# fill-column: 65
# End:

