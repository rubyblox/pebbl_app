## PebblApp::NameUtil module

require 'pebbl_app'

module PebblApp

  module Const
    ## regular expression matching upper case characters
    UPCASE_RE ||= /[[:upper:]]/.freeze
    ## regular expresion matching alphanmueric characters
    ALNUM_RE ||= /[[:alnum:]]/.freeze
    ## the character `_`
    UNDERSCORE ||= "_".freeze
    ## the character `:`
    COLON ||= ":".freeze
    ## the character `-`
    DASH ||= "-".freeze
  end

  ## utilities for name parsing
  ##
  ## This module will define the following methods at an instance scope,
  ## in the extending namespace,
  ## - flatten_name
  ##
  ## These methods are provided directly from this module, as singleton
  ## methods.
  module NameUtil

    def self.included(whence)
      ## return a string interpolation for a symbol or string using a
      ## simple naming syntax
      ##
      ## For any sequence of consecutive uppercase characters after the
      ## first index in the string representation of the input value, the
      ## the last uppercase character in the sequence will be prefixed
      ## with a provided `case_delim` string, by default `"_"` in the
      ## output value.
      ##
      ## For any one or more characters matching a namespace mark
      ## character, by default `":"`, a namespace delimiter string will be
      ## interpolated into the output value. By default, the string "-" is
      ## used as the output namespace delimiter string.
      ##
      ## Other characters in the string representation of S will be added
      ## to the return value using each character's lower-case form.
      ##
      ## The default syntax used here for translation of a symbol name
      ## to an output string should be generally congruous to the syntax
      ## for gemspec name to module name translation applied under the
      ## bundle-gem(1) shell command. e.g the shell command `bundle gem
      ## a_b_name` may produce a module named `ABName`, or in the case of
      ## the shell command `bundle gem a_b-name`, a module `AB::Name`.
      ##
      ## @example Examples
      ##
      ##   extend PebblApp::NameUtil
      ##
      ##   flatten_name(:CC)
      ##   => "cc"
      ##
      ##   flatten_name("simpleName")
      ##   => "simple_name"
      ##
      ##   flatten_name(String)
      ##   => "string"
      ##
      ##   flatten_name(:ABCName)
      ##   => "abc_name"
      ##
      ##   flatten_name(:ABCName, case_delim: " ")
      ##   => "abc name"
      ##
      ##   flatten_name("ABC::Name")
      ##   => "abc-name"
      ##
      ##   flatten_name("ABC::Name", ns_delim: "/")
      ##   => "abc/name"
      ##
      ##   flatten_name("App::Features::AClass", ns_delim: ".", case_delim: "-")
      ##   => "app.features.a-class"
      ##
      ##   flatten_name("Test01Feature")
      ##   => "test01_feature"
      ##
      ## @param s [Object] the value to translate. The string form of this
      ##  value will be interpolated to the output value.
      ##
      ## @param ns_delim [String] delimiter string to interpolate for any
      ##  sequence of one or more _ns_mark_ characters on input.
      ##
      ## @param ns_mark [String] string to interpret as a namespace
      ##  delimiter character on input. Any one or more consecutive
      ##  characters equal to this character will be interpolated as the
      ##  _ns_delim_ string for output. If this string contains more than
      ##  one character, only the first character will be
      ##  applied. Alphanumeric characters are not supported in this
      ##  string.
      ##
      ## @param case_delim [String] delimiter string to interpolate within
      ##  a change of consecutive character case for characters in `s`
      ##
      ## @return [String] the interpolated string
      def flatten_name(s, ns_delim: Const::DASH,
                       ns_mark: Const::COLON,
                       case_delim: Const::UNDERSCORE)
        require 'stringio'
        ## convert the input string to an array of unicode codepoints
        codepoints = s.to_s.unpack("U*")
        last = codepoints.length
        ## a single codepoint representing a namespace delimiter mark
        mark_cp = ns_mark.to_s.unpack("U*").first
        ## buffer for the return value
        io = StringIO.new
        ## booleans for parser state
        inter = false ## flag: intermediate parsing / alphanumeric character
        in_delim = false ## flag: parsed a namespace delimiter character
        in_upcase = false ## flag/storage: deferred output for upcase characters
        ## the parser
        n = 1
        codepoints.each do |cp|
          c  = cp.chr
          if c.match?(Const::UPCASE_RE)
            in_delim = false
            if inter && ((! in_upcase) ||
                         ((nxtcp = codepoints[n+1]) &&
                          (! nxtcp.chr.match?(Const::UPCASE_RE))))
              io.putc(case_delim)
            end
            in_upcase = c
          elsif (cp == mark_cp)
            if inter && ! n.eql?(last)
              io.write(ns_delim)
            end
            in_delim = true
            in_upcase = false
          else
            in_delim = false
            in_upcase = false
          end
          if n.eql?(last)
            if in_upcase
              io.putc(c.downcase)
            elsif ! in_delim
              io.putc(c.downcase)
            end
          else
            io.putc(c.downcase) if ! in_delim
            inter = c.match?(Const::ALNUM_RE)
            n = n + 1
          end
        end
        io.close
        return io.string
      end
    end

    self.singleton_class.include NameUtil

  end ##NameUtil module
end
