## pipe-mode IO with GLib::Spawn
##
## Prototype for
## PebblApp::Support::PtyCmd
## and subsq PebblApp::GtkSupport::VtyCmd

require 'pebbl_app/support'
require 'pty'

## for an EOL test (FIXME should be stored in constants)
require 'stringio'

module PebblApp::Support

  module Const
    EOL ||= proc { io = StringIO.new; io.puts; io.string }.call
  end

 class PtyCmd
   attr_reader :input_handler, :stderr_handler, :stdout_handler, :stdout_handlers
   attr_reader :cmd, :env, :pid, :output_thread

   ## Controlling IO channel for the PTY, for input to the subprocess
   ## and standard output from the subprocess
   attr_reader :pty

   ## IO channel for standard error output from the subprocess
   attr_reader :error_channel


   def initialize(cmd = (ENV['SHELL'] || "/bin/sh"),
                  env: ENV)
     @cmd = cmd
     @env = env
     @output_handlers = {}
     @output_streams = {}
     @exitfail = -1
     @sched_mtx = Mutex.new
     @sched_cv = ConditionVariable.new
     @io_mtx = Mutex.new
   end

   def with_stderr_handler(&block)
    with_output_handler(:err, &block)
   end
   def with_stdout_handler(&block)
    with_output_handler(:out, &block)
   end

   def with_output_handler(tag, &block)
     @output_handlers[tag] = block
   end

   def with_pid_init(&block)
     @pid_init_handler = block
   end

   def with_subprocess_init(&block)
     @subprocess_init_handler = block
   end

   def with_exec_error_handler(&block)
     @exec_error_handler = block
   end


   def send(text)
     with_io_sched do
       @pty.puts(text)
       ## FIXME even calling flush after each send, the shell response
       ## is still delayed with the I/O methodology used here
       @pty.flush
     end
   end

   def handle_output()
     ## cache instance variables for local lookup
     streams = @output_streams
     streams_io = streams.keys
     handlers = @output_handlers
     ## read until first of EOF, IO error, or exception in a handler
     while true
       readable = nil
       if (readable = IO.select(streams_io, nil, nil, 0))
         readable.each do |ios|
           ## arrays encapsulating arrays. iterate on each ..
           ##
           ## this should result in a predictable order of I/O
           ios.each do  |io|
             with_io_sched do
               if ((tag = streams[io]) && (hdlr = handlers[tag]))
                 hdlr.yield(io, tag)
               else
                 raise "Unable to find stream for %s %s"  % [
                   io, (tag ? ("with tag " + tag.to_s) : "(tag unknown)")
                 ]
               end
             end
           end
         end
       end
     end
   end

   def handle_output_async()
     Thread.new {
       begin
         self.handle_output
       rescue EOFError, IOError # => e
         ## FIXME use any mapped handlers in the implementation
         # Kernel.warn(e)
         Thread.current.exit
       ensure
         ## close the subprocess after I/O error with thhe subprocess
         @output_streams.each do |elt|
           ## close the PTY, error channel pipe, and any other streams
           elt.first.close
         end
         ## FIXME this needs to be configurable with callback
         ## e.g handle_output_eror
         Process.kill("TERM", self.pid)
       end
     }
   end


   def init_subprocess
     ## initialize a controlling PTY for the subprocess
     ctl_io, pty_io = PTY.open
     ## initialize a pipe for distinct dispatch on error output
     ## from the subprocess
     err_pipe_rd, err_pipe_wr = IO.pipe

     ## @exitfail is used only in this method's representation in the
     ## subprocess, if the call to exec fails.
     ##
     ## The variable should be initialized before fork.
     ##
     ## The value of this instance variable may be changed within any
     ## exec error handler in the subprocess, before the subprocess
     ## exits with this exit code
     @exitfail = -1

     ## variables to initialize for the subprocess, before fork,
     ## for availability to subprocess init handlers, after fork and
     ## before exec.
     ##
     ## overwritten again in the calling process, after fork
     @error_channel = err_pipe_wr
     @pty = pty_io


     if (pid = Process.fork)
       @pid = pid
       ## special streams
       @pty = ctl_io
       @error_channel = err_pipe_rd
       ## close streams unused in the calling process
       pty_io.close
       err_pipe_wr.close
       ## add streams to dispatch for output from the subprocess
       @output_streams[err_pipe_rd] = :err
       @output_streams[ctl_io] = :out
       ## disapatch to any init callback
       self.handle_pid_init(pid)
       ## return the PID
       return pid
     else
       ## subprocess init
       pty_io.close_on_exec = false
       err_pipe_wr.close_on_exec = false
       STDERR.close_on_exec = true
       STDOUT.close_on_exec = true
       STDIN.close_on_exec = true
       STDOUT.flush
       STDERR.flush
       STDIN.flush
       begin
         ## initialize the subprocess and then call exec,
         ## exiting if on failure in either call
         self.handle_subprocess_init()
         Process.exec(env, cmd, in: pty_io, out: pty_io, err: err_pipe_wr)
       rescue
         begin
           ## the exec error handler may update the @exitfail instance variable.
           handle_exec_error($!)
         rescue
           ## nop. Ensure normal exit if there was an error in the handler
         end
         ## clean up & exit with any configured exit status code
         err_pipe_wr.flush
         err_pipe_wr.close
         pty_io.flush
         pty_io.close
         STDERR.flush
         STDERR.close
         STDOUT.flush
         STDOUT.close
         STDIN.flush
         STDIN.close
         exit(@exitfail)
       end
     end
   end

   def run_async()
     ## FIXME not reentrant
     self.init_subprocess
     @output_thread = self.handle_output_async
   end

   protected

   attr_reader :sched_mtx, :sched_cv, :io_mtx

   def with_io_sched(&block) ## FIXME define as protected
     self.sched_mtx.synchronize {
       ## FIXME timeout for sched_cv.wait & handling on timeout
       ##
       ## using the lock state of the io_mtx
       ## as a "work available" condition
       ## for this application onto condition variables
       (got_mtx = self.io_mtx.try_lock) || self.sched_cv.wait(sched_mtx)
       begin
         block.yield(Thread.current)
       ensure
         if got_mtx
           self.io_mtx.unlock
         else
           self.sched_cv.signal
         end
       end
     }
   end

   def handle_pid_init(pid)
     if (instance_variable_defined?(:@pid_init_handler))
       block = instance_variable_get(:@pid_init_handler)
       block.yield(pid)
     end
   end

   def handle_subprocess_init()
     if (instance_variable_defined?(:@subprocess_init_handler))
       block = instance_variable_get(:@subprocess_init_handler)
       block.yield()
     end
   end

   def handle_exec_error(exception)
     if (instance_variable_defined?(:@exec_error_handler))
       block = instance_variable_get(:@exec_error_handler)
       block.yield(exception)
     end
   end

 end


 ## ad hoc tests

def Object.test_pty_cmd()

 it = PtyCmd.new(%(bash))

 it.with_pid_init do |pid|
   Kernel.warn "#{File.basename($0)}: Initialized procecss #{pid}"
 end

 it.with_subprocess_init do
   it.error_channel.puts "Initializing #{Process.pid}"
 end

 it.with_stderr_handler do |io|
   text = ""
   begin
     while (c = io.readchar)
       text << c
       break if c == Const::EOL
     end
   rescue EOFError, IOError # => e
     exit
   ensure
     if ! text.empty?
       Kernel.warn("read from error channel: #{text}")
     end
   end
 end


 it.with_stdout_handler do |io|
   text = ""
   begin
     while (c = io.readchar)
       text << c
       break if c == Const::EOL
     end
     #   text = io.readpartial(512)
   rescue EOFError, IOError # => e
     exit
   ensure
     if ! text.empty?
       Kernel.warn("read from output channel: #{text}")
     end
   end
 end

 it.with_exec_error_handler do |exc|
   Kernel.warn(exc, uplevel: 1)
 end

 it.run_async

# in_thr = Thread.new {
   ## testing i/o synchronization
   ## - a PTY cmd without a separate stderr channel might be more ideal
   ##   for e.g bash
   ##
   it.send("# input to shell, via PtyCmd")
   it.send('echo "using bash ${BASH_VERSION}"')
   sleep 0.01 ## pause to allow the output to display before next cmd
   it.send('echo bye 1>&2')
   it.send('echo "# exiting"')
   sleep 0.01 ## pause to avoid loosing output while the shell exits
   it.send('exit')
# }
# in_thr.join
 it.output_thread.join
end

# ## TBD threads, Gtk, and Vte Pty support  ..
# require 'gtk3'
# Gtk.init if Gtk.respond_to?(:init)
# require 'vte3'
# Vte::Pty.new(ctl_io.fileno)
# ## ^ more or less the only feature that would differ for this impl,
# ##   when using Gtk/GLib support here
##
## in pid init  ..
## Vte::Terminal...watch_proc(pid)

end ## module
