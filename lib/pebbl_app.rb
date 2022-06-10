## module definition for PebblApp

module PebblApp
  class << self
    ## a rudimentary relative autoloads method
    ##
    ## this method provides some bootstrap support for autoload calls in
    ## this module
    ##
    ## @param name [Symbol, String] name of the symbol for which to
    ##        define an autoload in this module
    ##
    ## @param file [String] pathname for the autoload definition,
    ##        as an absolute pathname or relative to the directory of
    ##        the source file defining this module.
    ##
    ##        If the file does not exist when this method is called,
    ##        no autoload definition will created. If $DEBUG has a
    ##        truthy value at the time of call, a warning will be
    ##        emitted as to indicate the absence of the source file.
    def autoload(name, file)
      path = File.expand_path(file, __dir__)
      if File.exists?(path)
        ## The File.exists? test is used here, as this source file may
        ## be distributed in separate Ruby gems, such that each gem
        ## would not provide the entire source tree of the original
        ## development project.
        super(name, path)
      else
        Kernel.warn(
          "Not definining autoload for %s::%s - file not found; %s" % [
            self, name, file
          ]) if $DEBUG
      end
    end ## self.autoload method
  end ## class << self

  ## distributed with the pebbl_app-support gem
  autoload(:Project, 'pebbl_app/project.rb')
  autoload(:Support, 'pebbl_app/support.rb')

  ## distributed with the pebbl_app-gtk_suport gem
  autoload(:GtkSupport, 'pebbl_app/gtk_support.rb')

end
