## process_facade.rb

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

module IOKit
  ## NB usage @ rbdevtools:projectkit/lib/projectkit/rspectool.rb

  ## extension module for a class to provide a +fork_in+ method
  module ProcessFacade
    def self.extended(extclass)

      ## FIXME [DEPRECATED]
      ## listed at the end of the documentation for its args,
      ## process.spawn accepts a :chdir arg

      def self.fork_in(dir, *block_args, &block)
        ## FIXME rename => sfork && implement like Process.spawn

        ## FIXME support additonal args for the fork procedure,
        ## in a manner similar to Process.spawn, generally at least for
        ## FD handling onto the IO.pipe implementation

        ## NB this of course requires a usable fork() implementation on
        ## the host
        ##
        ## NB the block may call 'exit' before the 'rescue' or 'default'
        ## handlers, below, would be reached
        ##
        unless (has_block = block_given?)
          ## FIXME this may represent a style warning ...
          warn("No block provided to #{self}.#{__method__}", uplevel: 1)
        end

        pid = Process.fork()
        if pid
          ## running in the calling process
          pid, st = Process.waitpid2(pid)
          return st.exitstatus
        else
          ## running in the forked process
          begin
            Dir.chdir(dir)
            ## handle other args (I/O, Process.setrlimit, env, ...)
            block.yield(*block_args) if has_block
          rescue
            Kernel.exit(-1)
          else
            Kernel.exit(0)
          end
        end
      end

    end
  end
end
