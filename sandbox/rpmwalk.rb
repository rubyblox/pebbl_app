## rpmwalk.rb - generic RPM repository tooling

require 'net/http'
require 'nokogiri'
require 'zlib'
require 'rubygems' ## for version parsing

class ClientResponse
  attr_reader :data, :uri, :redirect_response
  def initialize(data, uri, redirect_response = nil)
    @data = data
    @uri = uri
    @redirect_response = redirect_response
  end
end

class ClientRequest
  REDIRECT_LIMIT_DEFAULT = 10
  HTTP_OPTIONS_DEFAULT = {}.freeze

  attr_reader :uri, :http_options, :redirect_limit

  def initialize(uri, **options)
    @uri = URI(uri)

    ## set and trim options singularly for this instance
    if (rdr = options[:redirect_limit])
      @redirect_limit = rdr
      options.remove(:redirect_limit)
      options = nil if options.length.zero?
    else
      @redirect_limit = REDIRECT_LIMIT_DEFAULT
    end

    ## set options for the http methods under #run
    if options
      @http_options = options
    else
      @http_options = HTTP_OPTIONS_DEFAULT
    end
  end

  def run(&block)
    ## FIXME this is implicitly a 'run get' method
    ##
    ## FIXME generalize/parameterize onto the request class
    ## using some local enum module for supported request classes
    ## (at least for get, post, header request types)
    ##
    Net::HTTP.start(@uri.host, @uri.port, **@http_options) do |client|
      req = Net::HTTP::Get.new(@uri) ## FIXME generalize

      redirect_skip = nil

      ## FIXME the design of this API needs the block attached here.
      ##
      ## The block will be called multiple times, while any redirection
      ## must be handled at most once
      client.request(req) do |response|
        if ( redirect_skip || response.is_a?(Net::HTTPSuccess) )
          redirect_skip = true
          if block_given?
            block.yield(response)
          else
            return new ClientResponse(response, @uri)
          end
        elsif response.is_a?(Net::HTTPRedirection)
          rdr = self.redirect_limit
          if rdr.zero?
            ## FIXME use a specialized exception class here
            raise new "Redirection limit reached at #{response.inspect}"
          else
            rloc = response['location']
            rreq = self.class.new(rloc, **@options)
            rrsp = rreq.run(rdr - 1, &block)
            return new ClientResponse(response, @souce, rrsp) unless block_given?
          end
        else
          ## FIXME use a specialized exception class here
          raise "Unsupported response: #{response.inspect}"
        end
      end
    end
  end
end


class FetchClient
  # BUFF_LEN=4096 ## TBD socket stream acess, via Ruby

  ## NB it would not be thread-safe to set these attributes after
  ## initialize and then re-run #fetch in a separate thread.
  ##
  ## These attributes should be set only from the same thread in which
  ## each subsequent #fetch will be performed
  attr_accessor :source, :dest

  def self.ensure_dirs(dest)
    ## assumption: dest represents a directory name,
    ## such that may or may not presently exist.
    ##
    ## Known limitations: This does not check to ensure
    ## that dest represents a directory or a symbolic
    ## link to a directory
    unless Dir.exists?(dest)
      indir = File.dirname(dest)
      ensure_dirs(indir)
      Dir.mkdir(dest)
    end
  end

  def initialize(source, dest)
    @source = URI(source)
    ## TBD File.open semantics for dest (ovewrite, ...)
    @dest = Pathname(dest)
  end

  def fetch

    ## FIXME add a defauilt request timeout option, if supported,
    ## or else wrap the call in timer block

    if @source.scheme == "https"
      ## TBD initialize for URL scheme
      ssl_options = OpenSSL::SSL::OP_NO_SSLv2 + OpenSSL::SSL::OP_NO_SSLv3 +
                    OpenSSL::SSL::OP_NO_COMPRESSION
      client_args = {use_ssl: true, ssl_version: "TLSv1", ## ?? needs test
                     verify_mode: OpenSSL::SSL::VERIFY_PEER,
                     ssl_options: ssl_options}
    else
      client_args = {}.freeze
    end

    req = ClientRequest.new(@source, **client_args)

    outdir = @dest.dirname
    self.class.ensure_dirs(outdir)

    ## FIXME continuable fetch could be implemented here
    ## - accumulate the number of bytes read
    ## - if supported by the server, resume after some exception/wait

    File.open(@dest, "wb") do |io|
      req.run do |response|
        response.read_body do |data|
          io.write(data)
        end
      end
    end ## file.open

    return @dest
  end
end

class SAXTraverse < Nokogiri::XML::SAX::Document

  def initialize()
    @context = nil ## used internally for parser state
    @previous = [] ## used internally for parser state
  end

  def start_element(lname, attrs)
    @previous.push(@context)
    @context = lname
  end

  def end_element(lname)
    ## TBD this is called for empty elements (??)
    if @context == lname
      @context = @previous.pop
    else
      ## FIXME use a specialized exception class
      raise "Parser error. Not an active element (expected #{@context}): #{lname}"
    end
  end
end

class RepoData
  ## initial prototype for an API onto objects encoded in repomd.xml
  attr_accessor :repository, :revision, :type, :checksum, :open_checksum
  attr_accessor :location, :timestamp, :size, :open_size
  ## NB :uri will contain an absolute URI processed from the :location
  ## value as relative to the repository's :base URI
  attr_accessor :uri
end

class RepoTraverse < SAXTraverse
  EMPTY = [].freeze

  attr_reader :repository

  def initialize(repo)
    super()
    @repository = repo
  end

  ## NB the XML formats used here do not require
  ## a namespace-aware parse.
  ##
  ## moreover, this would change how the attribute data
  ## is recevied in start_element

  # def start_element_namespace(name, attrs = EMPTY,
  #                             pfx = nil, uri = nil,
  #                             nsdata= EMPTY)
  #   start_element(name, attrs)
  # end

  # def end_element_namespace(name, pfix = nil, uri = nil)
  #   end_element(name)
  # end

end

class RepomdTraverse < RepoTraverse

  ELT_REVISION = "revision".freeze
  ELT_DATA = "data".freeze
  ELT_LOCATION = "location".freeze

  ELT_TIMESTAMP = "timestamp".freeze
  ELT_CHECKSUM = "checksum".freeze
  ELT_OPEN_CHECKSUM = "open-checksum".freeze
  ELT_SIZE = "size".freeze
  ELT_OPEN_SIZE = "open-size".freeze

  ATTR_TYPE = "type".freeze
  ATTR_HREF = "href".freeze

  EMPTY = [].freeze

  ## e.g repomd.xml as with
  ## http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/repodata/repomd.xml

  def start_element(lname, attrs = EMPTY)
    super(lname, attrs)
    ## NB the 'data/location' element in repomd.xml is one
    ## element with attribute data that needs to be
    ## processed here for its data/location/@href
    ##
    ## furthermore, the data/@type attribute will be used
    ## for initializing each RepoData instance
    case lname
    when ELT_DATA
      attrs = attrs.to_h
      d = RepoData.new()
      d.type = attrs[ATTR_TYPE]
      @last_data = d
    when ELT_LOCATION
      attrs = attrs.to_h
      loc = attrs[ATTR_HREF]
      @last_data.location = loc
      uri = @repository.base.dup
      uri.path = File.join(uri.path, loc)
      @last_data.uri = uri
    end
  end

  def end_element(lname)
    super(lname)
    case lname
    when ELT_DATA
      @repository.add_data(@last_data)
      @last_data = nil
    end
  end

  def characters(str)
    case @context
    when ELT_REVISION
      @repository.revision = str
    when ELT_TIMESTAMP
      @last_data.timestamp = str
    when ELT_CHECKSUM
      @last_data.checksum = str
    when ELT_OPEN_CHECKSUM
      @last_data.open_checksum = str
    when ELT_TIMESTAMP
      @last_data.timestamp = str
    when ELT_SIZE
      @last_data.size = str
    when ELT_OPEN_SIZE
      @last_data.open_size = str
    end
  end ## #characters

end

## RPM primary repository data traversal (SAX)
class PrimaryTraverse < RepoTraverse
## e.g <chksum>-primary.xml[.gz] as referred from repomd.xml

  PFX_RPM = "rpm".freeze

  def self.attrs_arg_map(attrs)
    attrs.map { |elt| [elt[0].to_sym, elt[1]] }.to_h
  end
  def self.rpm_qname(name)
    return (PFX_RPM + ":" + name).freeze
  end

  ## NB this will not store all repository information (summary, ...)
  ELT_PACKAGE="package".freeze
  ELT_NAME="name".freeze
  ELT_ARCH="arch".freeze
  ELT_VERSION="version".freeze
  ELT_CHECKSUM="checksum".freeze
  ELT_LOCATION="location".freeze ## relative to the repository base URL
  ELT_FORMAT="format".freeze
  ELT_SOURCERPM= rpm_qname("sourcerpm")
  ELT_PROVIDES= rpm_qname("provides")
  ELT_REQUIRES= rpm_qname("requires")
  ELT_CONFLICTS=rpm_qname("conflicts")
  ELT_OBSOLETES=rpm_qname("obsoletes")
  ELT_SUGGESTS=rpm_qname("suggests")
  ELT_SUPPLEMENTS=rpm_qname("supplements")
  ELT_RECOMMENDS=rpm_qname("recommends")
  ELT_ENHANCES=rpm_qname("enhances")
  ELT_ENTRY=rpm_qname("entry")
  ATTR_FLAGS="flags".freeze
  ATTR_NAME="name".freeze
  ATTR_HREF="href".freeze

  NS_BASE="http://linux.duke.edu/metadata/common".freeze
  NS_RPM="http://linux.duke.edu/metadata/rpm".freeze

  EMPTY=[].freeze

  ## FIXME encode a VersionDecl for each
  ## package/(provides|requires|conflicts|obsoletes)/entry
  ## with a @flags attribute on the entry element

  def start_element(lname, attrs = EMPTY)
    prev_context = @context
    super(lname, attrs)
    case lname
    when ELT_PACKAGE
      @last_package = Package.new(self.repository)
    ## process some leaf elements here
    when ELT_VERSION
      args = self.class.attrs_arg_map(attrs)
      @last_package.epoch = args[:epoch]
      @last_package.version = args[:ver]
      @last_package.release = args[:rel]
    when ELT_ENTRY
      # STDERR.puts("DEBUG (entry)")
      ## FIXME not reached
      ## - nokogiri does not simply skip the namespace part,
      ##   when the element has a prefix name ... apparently
      if attrs.find { |elt| elt[0] == ATTR_FLAGS }
        # STDERR.puts("DEBUG: VERSION ATTRS #{attrs}")
        args = self.class.attrs_arg_map(attrs)
        args.delete(:pre)
        decl = VersionDecl.new(**args)
      else
        if (decl = attrs.find { |elt| elt[0] == ATTR_NAME })
          decl = decl[1].freeze
        end
      end
      case prev_context
      when ELT_PROVIDES
        @last_package.add_provides(decl)
      when ELT_REQUIRES
        @last_package.add_requires(decl)
      when ELT_CONFLICTS
        @last_package.add_conflicts(decl)
      when ELT_OBSOLETES
        @last_package.add_obsoletes(decl)
      when ELT_SUGGESTS
        @last_package.add_suggests(decl)
      when ELT_SUPPLEMENTS
        @last_package.add_supplements(decl)
      when ELT_RECOMMENDS
        @last_package.add_recommends(decl)
      when ELT_ENHANCES
        @last_package.add_enhances(decl)
      else
        Kernel.warn("Unkown context for entry: #{prev_context}", uplevel: 1)
      end
    when ELT_LOCATION
      loc = attrs.find { |elt| elt[0] == ATTR_HREF } ## unique to each rpm
      @last_package.location = loc[1]
    end
  end

  def characters(str)
    case @context
    when ELT_NAME
      @last_package.name = str.freeze
    when ELT_ARCH
      @last_package.arch = str.freeze
    when ELT_CHECKSUM
      ## assumption:  the containing checksum element
      ## contains an attribute pkgid="YES"
      s = str.freeze
      @last_package.id = s
      @last_package.checksum = s
    when ELT_SOURCERPM
      @last_package.source_rpm = str.freeze
    end
  end

  def end_element(lname)
    super(lname)
    case lname
    when ELT_PACKAGE
      @repository.add_package(@last_package)
      @last_package = nil
    end
  end

end

## RPM file list repository traversal (SAX)
class FLTraverse < RepoTraverse
## e.g <chksum>-filelists.xml[.gz] as referred from repomd.xml
end

## NB <chksum>-other.xml.gz under the repodata URL represents
## abbreviated changelog information for each RPM
## (not used here, presently)


class Repository
  REPO_MD="repodata/repomd.xml".freeze
  TYP_PRIMARY = "primary".freeze
  TYP_FILELISTS = "filelists".freeze

  attr_reader :base, :cachebase, :repo_data
  attr_accessor :revision

  attr_reader :rpm_data ## key : package id (RPM, SRPM)

  def initialize(base, cachebase)
    ## @revision : read from repomd.xml
    @base = URI(base)
    @cachebase = Pathname(cachebase).cleanpath
    @repo_data = {} ## firstly initialized during #load (MD traverse)
    @rpm_data = {} ## secondly initialized during #load (Primary, FL traverse)
  end

  def inspect()
    "#<%s 0x%04x %s => %s>" % [self.class, object_id, @base, @cachebase]
  end

  def add_data(repodata)
    id = repodata.type.freeze
    ## set the frozen value back
    repodata.type = id
    @repo_data[id] = repodata
  end

  def add_package(pkgdata)
    ## NB the id should be unique to each pkg. It will not be
    ## frozen here
    id = pkgdata.id
    @rpm_data[id] = pkgdata
  end

  def load()
    ## fetch and (FIXME) overwrite repomd.xml
    ## - FIXME set the file last modified time from server response data
    ## - FIXME overwrite only if server has published a newer file
    ## - FIXME overwite by way or file rename, not truncating
    md_uri = @base.dup
    md_uri.path = File.join(md_uri.path, REPO_MD)
    STDERR.puts("DEBUG md_uri #{md_uri}")
    md_dst = @cachebase.join(REPO_MD)
    webclient = FetchClient.new(md_uri, md_dst)
    webclient.fetch

    ## load the XML from md_dst (repomd.xml traversal)
    straverse = RepomdTraverse.new(self)
    sparser = Nokogiri::XML::SAX::Parser.new(straverse)
    ## the repomd.xml file is typically not a large file
    sdata = File.read(md_dst)
    sparser.parse(sdata)
    sdata = nil

    ## fetch referred files
    rpmdata = @repo_data[TYP_PRIMARY]
    ## FIXME have to fetch the thing first ...
    webclient.source = rpmdata.uri
    STDERR.puts("DEBUG rpmdata uri #{rpmdata.uri}")
    webclient.dest = @cachebase.join(rpmdata.location)
    webclient.fetch
    ## now traverse
    rpmtraverse = PrimaryTraverse.new(self)
    ## TBD reusing the initial **::SAX::Parser here
    sparser.document = rpmtraverse
    Zlib::GzipReader.open(webclient.dest) do |io|
      sparser.parse(io)
    end

    ## ... cont (referred files)
    fldata = @repo_data[TYP_FILELISTS]
    ## FIXME have to fetch the thing first ...
    webclient.source = fldata.uri
    STDERR.puts("DEBUG fldata uri #{fldata.uri}")
    webclient.dest = @cachebase.join(fldata.location)
    webclient.fetch
    fltraverse = FLTraverse.new(self)
    sparser.document = fltraverse
    Zlib::GzipReader.open(webclient.dest) do |io|
      sparser.parse(io)
    end
  end

  def find_providers(match, arch: nil)
    mclass = match.class
    matches =[]
    @rpm_data.each { |k,v|
      if ( match.is_a?(String) && v.name == match )
        matches.push(v) if ( arch.nil? || v.arch == arch )
      else
        if ( match.is_a?(Regexp) && match.match?(v.name))
          matches.push(v) if ( arch.nil? || v.arch == arch )
        end
        m = v.provides.find { |p|
          if ( match.is_a?(Regexp) && p.is_a?(String) && match.match?(p))
            matches.push(v) if ( arch.nil? || v.arch == arch )
          elsif p.is_a?(mclass)
            case p
            when String
              p == match
            when VersionDecl
              case p.kind
              when :==
                p == match
              when :>
                p > match
              when :<
                p < match
              when :>=
                p >= match
              when :<=
                p <= match
              end ## case p.kind
            end ## case p
          end ## p is_a mclass
          matches.push(m) if (m && ( arch.nil? || m.arch == arch ) )
        }
      end
    }
    matches.uniq
  end
end

## version encoding for RPM provides/requires data
class VersionDecl
  FL_EQ = "EQ".freeze
  FL_GT = "GT".freeze
  FL_LT = "LT".freeze
  FL_GE = "GE".freeze
  FL_LE = "LE".freeze
  NAME_UNSPEC = "unspecified".freeze

  attr_reader :flags ## from @flag in the repo -primary.xml.gz data
  attr_reader :name, :epoch, :ver, :rel
  attr_reader :sversion

  alias :version :ver
  alias :release :rel
  alias :kind :flags

  ## NB this uses a parameter syntax similar to how 'entry' attributes
  ## are encoded in repository -primary.xml.gz data. This may serve to
  ## support using attr.to_h  on element attribute data, when calling
  ## this method
  def initialize(name: NAME_UNSPEC, flags: nil, epoch: nil, ver: nil, rel: nil)
    case flags
    when FL_EQ
      flags = :==
    when FL_GT
      flags = :>
    when FL_LT
      flags = :<
    when FL_GE
      flags = :>=
    when FL_LE
      flags = :<=
    when nil
      ## typically not reached
      flags = nil
   else
      ## typically not reached
      Kernel.warn("Unrecognized flag #{kind}", uplevel: 1)
      kind = kind
    end
    @epoch = epoch
    @ver = ver
    @rel = rel

    ## Notes
    ## - the @epoch value appears to be largely unused in actual
    ##   version decls for RPMs.
    ## - typically, an @epoch, @version, and @release would all be
    ##   provided along with a flags value (here parsed as @kind)
    if (ver && rel)
      ## typically occurs as part of the RPM filename
      ##
      ## FIXME this needs a semantic version API, without the
      ## lot of limitations on syntax for Gemspec version strings
      @sversion = ver + "-" + rel
    elsif ver
      ## typically not reached
      @sversion = ver
    else
      ## typically not reached
      @sversion = nil
    end
  end
end


class Package
  ## NB @id : provided as package/checksum[@pkgid="yes"] in -primary.xml.gz
  ## and used as package/@pkgid in -filelist.xml.gz
  attr_reader :repository
  attr_accessor :id, :name, :arch, :checksum
  attr_accessor :version, :release, :epoch

  attr_accessor :files, :dirs ## <..>-files.xml.gz

  attr_accessor :location ## <..>-primary.xml.gz
  attr_accessor :source_rpm

  def initialize(repository)
    @repository = repository
  end

  def inspect()
    "#<%s 0x%04x %s (%s) %s-%s>" % [
      self.class, object_id, self.name, self.arch, self.version, self.release
    ]
  end

  def uri()
    if @uri
      @uri
    else
      if location && repository && repository.base
        ## deferred initialization
        u = repository.base.dup
        u.path = File.join(u.path, location)
        @uri = u
      else
        ## deferred initialization n/a
        raise "Cannot compute URI for partially initialized package #{self.inspect}"
      end
    end
  end


  def provides()
    @provides ||= []
  end

  def requires()
    @requires ||= []
  end

  def conflicts()
    @conflicts ||= []
  end

  def obsoletes()
    @obsoletes ||= []
  end

  def suggests()
    @suggests ||= []
  end

  def supplements()
    @supplements ||= []
  end

  def recommends()
    @recommends ||= []
  end

  def enhances()
    @enhances ||= []
  end

  def add_provides(decl)
    provides.push(decl)
  end

  def add_requires(decl)
    requires.push(decl)
  end

  def add_conflicts(decl)
    conflicts.push(decl)
  end

  def add_obsoletes(decl)
    obsoletes.push(decl)
  end


  def add_suggests(decl)
    suggests.push(decl)
  end

  def add_supplements(decl)
    supplements.push(decl)
  end

  def add_recommends(decl)
    recommends.push(decl)
  end

  ## "sigh" ... metadata glut

  def add_enhances(decl)
    enhances.push(decl)
  end


  ## def add_file(path)

  ## def add_dir(path)
end

=begin TBD

r = Repository.new(
  'http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/',
  '/tmp/repo.test.d'
)

r.load

r.rpm_data.first

=end
