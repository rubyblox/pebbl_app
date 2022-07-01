## exceptions.rb -- exception classes in PebblApp

require 'pebbl_app'

module PebblApp

  ## Error class for uncontinuable conditions in the runtine environment
 class EnvironmentError < RuntimeError
   ## usage e.g
   ## - FileManager.home when no HOME is bound in env
   ## - FileManager.username if reaching 'whoami' and the call fails
 end

end
