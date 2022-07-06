
require 'pebbl_app'
require 'stringio'

module PebblApp

  module Shell

    module Const
      EOF ||= "\u0004".freeze
      PLATFORM_NL ||= StringIO.new.tap { |io| io.puts }.string
    end

    class << self

      ## search the provided path for a matching file for which a test
      ## proc returns a truthy value
      ##
      ## If no test is provided, a block calling File.executable? on
      ## each existing file will be used as the test.
      ##
      ## This method emulates the common which(1) shell command on
      ## POSIX-like platforms, with adaptations for the Ruby programming
      ## environment. Unlike with conventional pathname expansion
      ## behaviors with a DOS interpreter or Cygwin shell on Microsoft
      ## Windows platforms, this method will not add any file name
      ## suffix -- e.g `.bat`, `.cmd`, `.com`, or `.exe` -- to the
      ## provided file name, when testing for the file's existence.
      ## Pursuant of further usage tests, this limitation may be
      ## addressed in a later release of this API. Presently, the
      ## provided file name must match some file with that exact name
      ## under the search path, on all platforms.
      ##
      ## @param name [String] the name of the file to match. This file
      ##        name will be applied relative to each directory element
      ##        of the provided path.
      ##
      ## @param path [String, Enumerable<String>] the search path. If
      ##        provdied as a string, the string will be split with the
      ##        provided delim string. Otherwise, the value should be an
      ##        enumerable object providing a string to each block on
      ##        the method 'each',
      ##
      ## @param delim [String] a delimiter for the search path, if the
      ##        path value is provided as a string.
      ##
      ## @param test [Proc] the proc to call for any existing
      ##        file. This proc will be called with an absolute path as
      ##        a string representing the file's name expanded relative
      ##        to each element of the search path, for each existing
      ##        file. The first file for which the block returns a
      ##        truthy value will be returned. If no test is provided,
      ##        this method will use a block calling File.executable?
      ##
      ## @return [String, false] the first matching file, or false
      ##         if no matching file is found
      ##
      def which(name, path = ENV['PATH'], delim =  File::PATH_SEPARATOR, &test)
        if ! block_given?
          test = ( proc { |f| File.executable?(f) } ).freeze
        end
        catch(:found) do |tag|
          seq = (String === path) ? path.split(delim) : path
          seq.each do |dir|
              f = File.join(dir, name)
              if File.exist?(f) && File.file?(f) && test.yield(f)
                throw tag, f
              end
          end
          return false
        end
      end ## Shell.which

    end ## class << self

  end ## Shell class

end ## PebblApp module
