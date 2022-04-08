## configfile.rb

require('rbloader/fileinfo') ## FIXME gem N/A

module Config
  ## FIXME move the FieldDesc code into this module

  class ConfigFile < Utils::FileInfo
    ## TBD API generalization

    ## see notes under Proj#init_with
    attr_accessor :for_obj
    attr_accessor :included_from ## ConfigFile or nil

    ## TBD
    # attr_accessor :conf_history (used in YAMLConfigFile)
    # attr_accessor :field_descs (used in YAMLConfigFile)

  end

  module YAML
    ## NB FieldDesc classes

    class YAMLConfigFile < Config::ConfigFile
      ## FIXME subclass for Proj : ProjConfigFile

      ## YAML-encdoded tag for the config file syntax
      ##
      ## FIXME use a sytnax config%<class_name>
      ## for the class of any instanace using this class
      extend YAMLExt
      ## YAML_TAG = init_yaml_tag("config")

      attr_reader :yaml_tag
      attr_reader :coder_map ## NB

      ## FIXME @field_descs should only be set once,
      ## then read-only
      attr_accessor :field_descs

      ## FIXME migrate load_* methods from Proj into this class

      def initialize(field_descs)
        @field_descs = field_descs
        @conf_history = []
        @extra_conf_data = {}
      end

      ## retrieve a class name from a YAML tag, such that would
      ## be provided in the +tag+ field of the *Psych::Coder*
      ## provided under *#init_with*
      def self.parse_tag(tag)
        if ( tag =~ /^config:(.*)/ )
          return $1
        else
          raise ArgumentError.new("Invalid tag syntax: " + tag)
        end
      end

      def encode_with(coder)
        ## FIXME implement. See Proj
      end

      ## store the +coder.map+ for subsequent processing
      ## under *#init_instance*
      ##
      ## @param coder [Psych::Coder] a *Coder* object,
      ##  such that must have a +coder.type+ of +:map+.
      ##  This object would generally be provided in the Psych
      ##  API, such as under the *Psych::Visitors::ToRuby+ method
      ##  *#visit_Psych_Nodes_Mapping*
      ##
      ## @see #init_instance
      ##
      def init_with(coder)
        ## NB this YAMLConfigFile cannot be assumed to have
        ## been fully initialized when this method is called
        ## as within Psych::Visitors::ToRuby#*
        (coder.type == :map) ||
          raise("Unsupported coder type #{coder.type} in #{coder}")
        ## store the coder tag and map data for later processing
        @yaml_tag = coder.tag
        @coder_map = coder.map
        ## Subsq, this instance may be returned from
        ## e.g Psych.load...
        initialize(nil)
      end

      def init_include_stream(instance, io, **loadopts)
        sub_config = Psych.safe_load(io,**loadopts)
        ## FIXME ...
        ## TBD if the sub_config is not a YAMLConfigFile,
        ## assume it's a generalized mapping
        if sub_config.is_a?(YAMLConfigFile)
          sub_config.included_from = self
          sub_config.for_obj = instance
          sub_config.init_instance(instance, **loadopts)
        elsif sub_config.is_a?(Hash)
          ## assumption: a generlaized mapping.
          ## can be processed the same as a @coder_map
          sub_config.each do |k, v|
            init_field_dispatch(instance, k, v, **loadopts)
          end
        else
          raise NotImplementedError.
                  new("Not implemented: #{__method__} for sub_config #{sub_config.class} #{sub_config}")
        end
      end

      def init_include_file(instance, filename, **loadopts)
        ## FIXME needed
        f = File.open(filename, "rb:BOM|UTF-8")
        opts = loadopts.dup
        opts[:filename] = filename
        sub_config = init_include_stream(instance, stream, **opts)
        ensure
          f.close
      end

      def init_field_dispatch(instance, name, value, **loadopts)
        ## NB similar to previous Proj#load_yaml_field

        ## NB loadopts would be used on event of 'include'
        if ( source_file = loadopts[:filename] )
          source_file = File.expand_path(source_file)
        end
        if (name == :include) || (name.is_a?(YAMLScalarExt) &&
                                  name.value == "include")
          yfile = value.is_a?(YAMLScalarExt) ? value.value : value

          abs = File.expand_path(yfile, source_file && File.dirname(source_file))
          @conf_history.push[:include, yfile, source_file]
          opts = loadopts.dup
          opts[:filename] = abs
          init_include_file(instance, abs, **opts)
        else
          ## FIXME
          fdesc = field_descs.find {
            |f| f.name == name
          }
          if fdesc
            @conf_history.push[fdesc.name, source_file]
            fdesc.init_field(instance,field_value)
          else
            @extra_conf_data[name] = value
          end
        end
      end

      def init_instance(instance, **loadopts)
        ## NB loadopts would be used on event of 'include'

        # inst_class_name = self.parse_tag(@yaml_tag)
        # @classloader = Psych::ClassLoader.new

        ## FIXME the following exception could be implemented as
        ## a continuable condition, to a side effect of there
        ## being no configuration data resolved with this
        ## YAMLConfigFile instance

        # inst_class = ( @classloader.load(inst_class_name) ||
        #                raise "Cannot find class: #{inst_class_name}" )
        ## FIXME add any field descriptions for fields that
        ## could be used singularly for configuring this
        ## YAMLConfigFile instance

        # field_descs = inst_class.serializable_fields

        ## FIXME scan for the 'instance' key and pass its value
        ## as a map, for the instance fdesc parser, using any
        ## 'config' key singularly for configuring this ConfigFile instance

        # @for_obj = inst_class.allocate

        ## FIXME this looses any pathname information for any
        ## file stream representing the YAMLConfigFile in
        ## serialization to YAML
        @coder_map.each do |k,v|
          init_field_dispatch(instance, k, v, **loadopts)
        end
        ## FIXME needs testing under rspec
        end ## #init_instance
    end ## YAMLConfigFile class
  end ## Config::YAML module
end ## Config module

# Local Variables:
# fill-column: 65
# End:
