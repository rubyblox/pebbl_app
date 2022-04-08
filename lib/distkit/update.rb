## update.rb for emulators/linux_base-c8

### FIXME move this comment to README / Design docs
## cf. http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/repodata/e04cff091bb49d22e01417da1c3948e1f7a61ed7e08e60e595b4fa827fce1c31-filelists.xml.gz
## ... via http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os/repodata/repomd.xml
## / END FIXME

require 'net/http'
require 'nokogiri'
require 'zlib'

require 'rbs'

module Constants
  HDR_USER_AGENT = 'User-Agent'.freeze
  HDR_ACCEPT = 'Accept'.freeze
  HDR_CONTENT_LOCATION = 'Content-Location'.freeze
end

class RequestFactory

  ## default maximum inclusive limit on HTTP redirections. If set before
  ## this class definition is loaded, the initial value will not be
  ## overwritten.
  REDIRECT_LIMIT_DEFAULT ||= 10

  ## default options for Ruby Net::HTTP.start, when no additional
  ## options are provided to the class constructor. If set before
  ## this class definition is loaded, the initial value will not be
  ## overwritten.
  HTTP_OPTIONS_DEFAULT ||= {}.freeze

  ## default user agent string for HTTP requests. Not overwritten during
  ## class definition.
  AGENT_DEFAULT ||= "Ruby".freeze

  ## default Accept header value for HTTP requests. Not overwritten during
  ## class definition.
  ACCEPT_DEFAULT ||= "*/*".freeze

  ## timeouts cf. Net::HTTP#initialize
  ##
  ## TBD using 'ssl_timeout' onto the HTTP request object x #init_request
  TIMEOUT_OPEN_DEFAULT ||= 45
  TIMEOUT_READ_DEFAULT ||= 45
  TIMEOUT_WRITE_DEFAULT ||= 45
  TIMEOUT_CONTINUE_DEFAULT ||= 45
  TIMEOUT_KEEPALIVE_DEFAULT ||= 15

  RETRIES_LIMIT_DEFAULT ||= 3

  attr_reader :uri, :initheaders, :request_class,
    :agent, :accept, :http_options, :redirect_limit,
    :timeout_open, :timeout_read, :timeout_write, :timeout_continue,
    :timeout_keepalive, :retries_limit

  ##
  ## An overview of parameters:
  ##
  ## request_class: Class whose constructor will be called for
  ##  HTTP requests under #run. This class' constructor should
  ##  accept two arguments: A request URI and secondly, either the value
  ##  nil or a hash table of string header name/value pairs for request
  ##  headers. The class should represent a subclass of Net::HTTPRequest.
  ##
  ## initheaders: If true, a hash table representing headers to use when
  ##   creating each instance of the request_class. For continued
  ##   requests, this may include a 'range' header - in which case,
  ##   any 'accept-encoding' for acceptable HTTP compression methods
  ##   should be provided throughout, in addition to the range header,
  ##   as for consistency per behaviors of the Ruby implementation of
  ##   Net::HTTPGenericRequest. (FIXME partial/continued requests not
  ##   yet fully supported)
  ##
  ##   The 'Accept' and 'User-Agent' headers should not be provided in
  ##   the initheaders hash, as these will be overwritten by the Ruby
  ##   HTTP client library, namely in the method
  ##   `Net::HTTPGenericRequest#initialize`. The 'Host' header should
  ##   generally not be set external to the Ruby HTTP client library.
  ##
  ## agent: User-Agent header value for HTTP requests
  ##
  ## accept: 'Accept' header value for HTTP requests
  ##
  ## redirect_limit: Maximum inclusive number of redirections accepted
  ##   in the initial HTTP request, or nil. If non-nil, the value
  ##   should be provided as a positive integer or zero. If nil or zero
  ##   and a redirection response is received, an error will be signaled.
  ##
  ## options: This argument will receive any additional arguments for
  ##   providing to the `Net::HTTP` constructor, as via the class method
  ##   `Net::HTTP.start`. If no additional options are provided, the
  ##   options set in the class constant `HTTP_OPTIONS_DEFAULT` will be
  ##   used.
  def initialize(uri, request_class: Net::HTTP::Get,
                 initheaders: nil, agent: AGENT_DEFAULT,
                 accept: ACCEPT_DEFAULT, timeout_open: TIMEOUT_OPEN_DEFAULT,
                 timeout_read: TIMEOUT_READ_DEFAULT,
                 timeout_write: TIMEOUT_WRITE_DEFAULT,
                 timeout_continue: TIMEOUT_CONTINUE_DEFAULT,
                 timeout_keepalive: TIMEOUT_KEEPALIVE_DEFAULT,
                 retries_limit: RETRIES_LIMIT_DEFAULT,
                 redirect_limit: REDIRECT_LIMIT_DEFAULT, **options)
    @uri = URI(uri)
    @initheaders = initheaders
    @request_class = request_class
    @agent = agent
    @accept = accept

    @redirect_limit = redirect_limit

    @tiemout_open = timeout_open
    @tiemout_read = timeout_read
    @tiemout_write = timeout_write
    @tiemout_continue = timeout_continue
    @tiemout_keepalive = timeout_keepalive
    @retries_limit = retries_limit

    ## set options for net/http client behaviors under #run
    if options.length.zero?
      @http_options = HTTP_OPTIONS_DEFAULT
    else
      @http_options = options
    end
  end


  ## initialize an HTTP client for subsequent HTTP requests
  def init_client(client)
    client.open_timeout = self.timeout_open
    client.read_timeout = self.timeout_read
    client.write_timeout = self.timeout_write
    client.continue_timeout = self.timeout_continue
    client.keep_alive_timeout = self.timeout_keepalive
    client.max_retries = self.retries_limit
  end


  ## create an HTTP request object for this RequestFactory
  def create_request(uri, headers = nil)
    request_class.new(uri, headers)
  end

  ## initialize a new HTTP request object
  def init_request(request)
    request[Constants::HDR_USER_AGENT] = self.agent
    request[Constants::HDR_ACCEPT] = self.accept
  end

  ## an accessor returning the first available value of the
  ## Content-Location header in the response, or the request URI used in
  ## creating the response. Under HTTP content negotation, the string
  ## representation of the request origin URI may differ to the initial
  ## request URI
  def get_request_origin(response)
    return ( response[Constants::HDR_CONTENT_LOCATION] || response.uri )
  end

  ## initialize and send and HTTP request for the specified URI, using
  ## the request class initialized to this RequestFactory.
  ##
  ## The request will be initialized with any request headers provided
  ## in the optional headers hash value. If provided, this hash value
  ## should represent a table with string header names as keys and
  ## corresponding header values.
  ##
  ## The redirect_limit should be provided as the value nil, a positive
  ## integer, or the integer 0. The value nil would be procedurally
  ## equivalent to 0. If the HTTP response is a redirection response and
  ## this value is 0 or nil, and error will be raised. Otherwise, for
  ## any redirection response, a reqursive call will be made on the
  ## rediect's location URL using the same request class and request
  ## initialization methods for this instance.
  ##
  ## The block, if provided, must receive an HTTP response object as a
  ## single argument. This block should be reentrant, as it may be
  ## called subsequently - such as in a manner of stream-style response
  ## handling under Ruby stdlib HTTP supoprt. It may be assumed that the
  ## block will be called for any response of a type
  ## Net::HTTPSuccess. The block will not be called for any
  ## intermediate redirection responses, server error responses, or
  ## client error responses.
  ##
  ## If no block is provided, the response object and any data in the
  ## response body will be  discarded.
  ##
  ## On event of a response of type Net::HTTPServerError, an exception
  ## of type Net::HTTPServerException will be raised. If the response is
  ## alternately of a type Net::HTTPClientError, an exception of type
  ## Net::HTTPError will be rasised. In either event, the response
  ## message and response object will be made available as external to
  ## this method, in attribute fields of the exception.
  ##
  def run(req_uri = self.uri, headers: self.initheaders,
              redirect_limit: self.redirect_limit, &block)
    Net::HTTP.start(req_uri.host, req_uri.port, **@http_options) do |client|

      self.init_client(client)

      req = self.create_request(req_uri, headers)
      self.init_request(req)

      response_origin = nil

      ## NB For a request without redirection, the following block may
      ## be called multiple times, while any redirection response should
      ## be handled at most once.
      ##
      ## The response_origin variable may serve as a generic indicator
      ## for a condition of reentrant response data handling
      ##
      ## FIXME reponse body length and request range handling could be
      ## generalized to this section
      ##
      ## FIXME this should be tested for redirection handling under
      ## 'head' requests, using a normal HTTP server (ASF or nginx)
      client.request(req) do |response|
        if ( response_origin || response.is_a?(Net::HTTPSuccess) )
          ## record the response origin, and skip any later response type
          ## checking under this block
          response_origin ||= (self.get_request_origin(response) || req_uri )
          ## pass the response instance provided to this block,
          ## passing to any block provided to this method.
          ##
          ## This itself will not check to ensure that the response has
          ## a readable body section.
          block.yield(response) if block_given?
        else
          case response
          when Net::HTTPRedirection
            if (redirect_limit.zero? || redirect_limit.nil?)
              ## FIXME use a specialized exception class here
              raise new "Redirection limit reached at #{response.inspect}"
            else
              ## FIXME needs tests - HTTP mockup server under rspec
              next_loc = response['location']
              used_loc = ( self.get_request_origin(response) || req_uri )
              redir_loc = self.run(next_loc, headers: headers,
                                   redirect_limit: (redirect_limit - 1),
                                   &block)
              if redir_loc.is_a?(Array)
                redir_loc.push(used_loc)
                response_origin = redir_loc
              else
                response_origin = [redir_loc, used_loc]
              end
            end
          when Net::HTTPServerError
            ## TBD as to how these request/response error classes are
            ## actually handled in any section of the Ruby stdlib http
            ## code
            raise new Net::HTTPServerException(response.message, response)
          when Net::HTTPClientError
            ## TBD see previous
            raise new Net::HTTPError(response.message, response)
          else
            ## FIXME use a specialized exception class here
            raise "Unsupported response: #{response.inspect}"
          end
        end
        return response_origin
      end
    end
  end
end

require 'time' ## used below
class FetchClient
  # BUFF_LEN=4096 ## TBD socket stream acess, via Ruby

  ## NB it would not be thread-safe to set these attributes after
  ## initialize and then re-run #fetch in a separate thread.
  ##
  ## These attributes should be set only from the same thread in which
  ## each subsequent #fetch will be performed
  attr_accessor :source, :dest

  def self.ensure_dirs(destdir)
    ## assumption: dest represents a directory name,
    ## such that may or may not presently exist.
    ##
    ## Known limitations: This does not check to ensure
    ## that dest represents a directory or a symbolic
    ## link to a directory
    unless Dir.exists?(destdir)
      indir = File.dirname(destdir)
      ensure_dirs(indir)
      Dir.mkdir(destdir)
    end
  end

  def initialize(source, dest)
    ## FIXME this needs an effective API for parameter pass-through
    ## to the RequestFactory constructor calls
    @source = URI(source)
    ## TBD File.open options/semantics for dest (ovewrite, ...)
    @dest = Pathname(dest)
  end

  def fetch_last_modified()
    ## FIXME provide parameter pass-through for the RequestFactory constructor
    client = RequestFactory.new(@source, request_class: Net::HTTP::Head)
    lm = false
    client.run() do |response|
      lm = response["Last-Modified"]
    end
      ## FIXME verify whether Last-Modified can be assumed to be
      ## available on all responses (RFC ...)
    ( return Time.parse(lm) ) if lm
  end

  def fetch_reachable?()
    ## TBD prototype method
    begin
      ## FIXME verify whether Last-Modified can be assumed to be
      ## available on all responses (RFC ...)
      self.fetch_last_modified
    rescue Net::HTTPServerError, Net::HTTPError
      ## NB see ClientFactory#run for how those exceptions may be
      ## reached here (FIXME needs test)
      return false
    end
    return true
  end

  def fetch_new()
    if @source.scheme == "https"
      ## TBD initialize SSL support per the URL scheme
      ##
      ## FIXME move this into the class initializer x test
      ssl_options = OpenSSL::SSL::OP_NO_SSLv2 + OpenSSL::SSL::OP_NO_SSLv3 +
                    OpenSSL::SSL::OP_NO_COMPRESSION
      client_args = {use_ssl: true, ssl_version: "TLSv1", ## ?? needs test
                     verify_mode: OpenSSL::SSL::VERIFY_PEER,
                     ssl_options: ssl_options}
    else
      client_args = {}.freeze
    end

    req = RequestFactory.new(@source, **client_args)

    outdir = @dest.dirname
    self.class.ensure_dirs(outdir)

    File.open(@dest, "wb") do |io|
      ## FIXME if overwriting, do not truncate the original file
      ## until the remote data is recevied to some temporary local file
      req.run() do |response|
        ## FIXME capture any Last-Modified time here and use to set the
        ## file last modified time (io)
        response.read_body do |data|
          io.write(data)
        end
      end
    end ## file.open

    return @dest
  end ## #fetch_new method

  def fetch(always: false)
    ## NB using conditional fetch
    ##
    ## 1) if the local file already exists and the remote host can be
    ##    reached, checking the local file's last modified time, in
    ##    comparison against the Last-Modified result of a 'head'
    ##    request under the 'source' URI
    ##
    ##    Will fetch only if newer, in this instance
    ##
    ## 2) If the local file exists and the 'source' host cannot be
    ##    reached, using the local file
    ##
    ## 3) If the local file does not exist and the 'source' host cannot
    ##    be reached, fetch_new will err during the failed HTTP request
    ##
    ## FIXME this assumes complete fetch in each instance, neither
    ## storing nor processing any external checksum files or file units
    unless (do_fetch = always)

      if File.exists?(@dest)
        st = File.stat(@dest)
      else
        st = nil
        do_fetch = true
      end

      if st
        mtime = st.mtime
        begin
          rmt_mtime = self.fetch_last_modified
        rescue Net::HTTPServerError, Net::HTTPError
          ## NB see ClientFactory#run for how those exceptions may be
          ## reached here (FIXME needs test)
          rmt_mtime = nil
        end

        if ( ! rmt_mtime )
          ## assumption: remote is unreachable.
          ## here, there is already a local file
          do_fetch = true
        elsif ( rmt_mtime > mtime )
          do_fetch = true
        end
      end
    end ## unless (do_fetch = always)

    fetch_new if do_fetch
    return @dest
  end ## #fetch method

end

## module PkgLib::Format::XML ?

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

## module PkgLib::Repository::Yum

## NB
## https://en.opensuse.org/openSUSE:Standards_Rpm_Metadata
## - Yum repository index (repomd.xml) format
## - Yum XML extensions
## http://yum.baseurl.org/wiki/Guides.html
## - Yum cmdline documentation
## - Yum repository documentation

## Local representation of elements in top-level Yum repository metadata
class IndexData
  ## initial prototype for an API onto objects encoded in repomd.xml
  attr_accessor :repository, :revision, :type, :checksum, :open_checksum
  attr_accessor :location, :timestamp, :size, :open_size
  ## NB :uri will contain an absolute URI processed from the :location
  ## value as relative to the repository's :base URI
  attr_accessor :uri
end

## generic utility class for PkgLib Yum XML support
class YumTraverse < SAXTraverse
  EMPTY = [].freeze

  attr_reader :repository

  def initialize(repo)
    super()
    @repository = repo
  end

  ## NB the XML formats used here do not require
  ## a namespace-aware parser.
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

## Document provider for local SAX-based processing of Yum repomd.xml
## index data
class IndexTraverse < YumTraverse

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
    ## for initializing each IndexData instance
    case lname
    when ELT_DATA
      attrs = attrs.to_h
      d = IndexData.new()
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

## Document provider for local SAX-based processing of primary
## RPM description metadata in Yum XML files
class PrimaryTraverse < YumTraverse
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
      ## NB nokogiri does not simply skip the namespace part
      ##   in #start_element. When the element has a prefix name,
      ##   the prefix will be included in the element's qualified
      ##   name here.
      if attrs.find { |elt| elt[0] == ATTR_FLAGS }
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


## Document provider for local SAX-based processing of primary
## RPM file list metadata in Yum XML files
class FLTraverse < YumTraverse
## e.g <chksum>-filelists.xml[.gz] as referred from repomd.xml
end

## NB <chksum>-other.xml.gz under the repodata URL represents
## abbreviated changelog information for each RPM
## (not used here, presently)

## FIXME GPG support - notes
##
## * user files
#
# $ gpg -verify repomd.xml.asc repomd.xml
#
# gpg: Note: RFC4880bis features are enabled.
# gpg: directory '/usr/home/username/.gnupg' created
# gpg: keybox '/usr/home/username/.gnupg/pubring.kbx' created
# usage: gpg [options] --encrypt [filename]
#
##
## keys required
##
# $ gpg --verify repomd.xml.asc repomd.xml
#
# gpg: Signature made Tue Mar  1 07:24:06 2022 PST
# gpg:                using RSA key 05B555B38483C65D
# gpg: Can't check signature: No public key
#
##
## Ruby support for GnuPG signature verification
##
## - avl API: https://github.com/ueno/ruby-gpgme
##   as port security/rubygem-gpgme
## - TBD determining what key was used to create a signature, and
##   fetching the keey if available in some configured remmote key store
## - Addition of this support will need a tractable application concept
##   in the API, and in which the gnupg support should probably be
##   represented as a separate application used here

##
## Local representation of a Yum repository
##
## FIXME for persistent storage, this class will need a stateful
## representation, as well as methods for obsoleting any expired RPM
## entries and locally cached files on subsequent update
class Repository
  INDEX_MD="repodata/repomd.xml".freeze
  TYP_PRIMARY = "primary".freeze
  TYP_FILELISTS = "filelists".freeze

  attr_reader :base, :cachebase, :repo_data
  attr_accessor :revision ## informative (not a key) w/ CentOS 8-stream

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

  def load(always_fetch: false)

    ## FIXME modularize the fetch calls for repository index, primary
    ## RPM description, and RPM filelist metadata XML files
    ## - create a new FetchClient for each
    ## - create each FetchClient with a URI relative to that for "This
    ##   repository" and a local destination file relative to the
    ##   "Cache root" for "This repository"
    ## - fetch the primary and file list XML (gzipped) before parsing
    ## - create a new SAX traversal doc for processing each XML
    ##   resource, beginning with the index data in repomd.xml
    ## - Stateful storage - Handle obsoleting for locally cached data
    ##   and files, on update

    ## FIXME this needs to maintain state, with regards to
    ## the initial index metadata file (pathname at md_dst here)
    ## - store a signature for the original repomd.xml file used for
    ##   each RPM record (repo index table)
    ## - When the repomd.xml file is updated upstream, any previously
    ##   cached -primary and -filelist files will be obsolete
    ##   and should be archived or removed, along with obsoleting
    ##   any cached RPM data for same - prune unref'd RPMs from DB after
    ##   parse, for anything referred in the earlier repomd.xml file and
    ##   not referred in any later repomd.xml
    ## - Use YAML (??) to maintain an ad hoc representation of the
    ##   original index state - or simply use ActiveRecord here,
    ##   sqlite locally, and the sqlite data at the upstream Yum repository
    md_uri = @base.dup
    md_uri.path = File.join(md_uri.path, INDEX_MD)
    md_dst = @cachebase.join(INDEX_MD)
    STDERR.puts("DEBUG fetch index #{md_uri} => #{md_dst}")
    webclient = FetchClient.new(md_uri, md_dst)
    webclient.fetch(always: always_fetch)

    ## TBD processing the GnuPG signature in the *.asc file
    ## (see previous)
    md_chk_uri = md_uri.dup
    md_chk_uri.path = md_chk_uri.path + ".asc"
    md_chk_dst = @cachebase.join(INDEX_MD + ".asc")
    STDERR.puts("DEBUG fetch index signature #{md_chk_uri} => #{md_chk_dst}")
    webclient.source = md_chk_uri
    webclient.dest = md_chk_dst
    webclient.fetch(always: always_fetch)
    ## FIXME - in Ruby, something like the following
    #  "gpg - verify #{md_chk_dst} #{md_dst}"
    ## assuming GPG may produce some meaningful return codes

    ## load the XML from md_dst (repomd.xml traversal)
    straverse = IndexTraverse.new(self)
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
    webclient.fetch(always: always_fetch)
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
    webclient.fetch(always: always_fetch)
    fltraverse = FLTraverse.new(self)
    sparser.document = fltraverse
    Zlib::GzipReader.open(webclient.dest) do |io|
      sparser.parse(io)
    end
  end

  ## FIXME this represents an initial query API for a single Repository
  ## instance - essentially the goal of the design of this API, for
  ## application in tooling for port upgrades
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
