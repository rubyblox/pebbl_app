## pipe-mode IO with GLib::Spawn

require 'gtk3'

Gtk.init if Gtk.respond_to?(:init)

#STDERR.puts "Is a TTY: #{STDIN.isatty.inspect}"

require 'pty'
ctl_io, pty_io = PTY.open

## with Gtk support now ..
require 'vte3'
Vte::Pty.new(ctl_io.fileno)
## ^ more or less the only feature that would differ for this impl,
##   when using Gtk/GLib support here

## NB an encoding arg is accepted on IO.pipe
##
## Add'l concerns for encoding support
## - The subprocess cmd may configure an encoding internally,
##   such that may be affected by some environment settings e.g LC_ALL
## - The section after fork and before exec will inherit any encoding
##   for streams open at the time of fork
##
## This initial implementation will use the default encoding in the Ruby
## process, at time of call

err_pipe_rd, err_pipe_wr = IO.pipe

sub_env = ENV

## marker for an instance variable
$EXITSTATUS = 0

if (pid = Process.fork)
  ## in the calling process

  Kernel.warn("Forked process #{pid}")
  ## Vte::Terminal...watch_proc(pid)

  p_out = ctl_io
  p_in = ctl_io
  p_err = err_pipe_rd

else
  ## subprocess setup section
  ## - simlar to the setup function for GLib::Spawn.async* via Ruby-GNOME GLib
  ##
  ## FIXME see docs for notes on limitations & concerns for the section
  ## betwen fork and exec in portable applications
  ##
  ## FIXME this API could support a user-provided setup block here,
  ## additional to any user-provided "error in exec" block.
  ##
  pty_io.close_on_exec = false
  err_pipe_wr.close_on_exec = false
  STDERR.close_on_exec = true
  STDOUT.close_on_exec = true
  STDIN.close_on_exec = true
  ## flushing these streams here may cause a peculiar scheduling behavior
  ## for read from the err_pipe_rd && ctl_io streams in the calling process
  ## seen with Ruby 3.1 on FreeBSD 13.1 (amd64)
  # STDOUT.flush
  # STDERR.flush
  # STDIN.flush
  err_pipe_wr.puts "In: #{Process.pid}"
  err_pipe_wr.puts "Starting shell ..."
  ## flush any streams accessed directly
  err_pipe_wr.flush
  ## TBD side effects (??) for I/O scheduling in the calling process,
  ## with or without flushing other streams here,
  ## or simply the concern as to whether the err reader or out reader
  ## displays its output first in the calling process
  # pty_io.flush
  # STDERR.flush
  # STDOUT.flush
  ## using an exit status that can be set in any exec_error handler
  ## FIXME once implemented, store this in an instance attr/ivar
  $EXITSTATUS = -1
  begin
    Process.exec(sub_env, "bash", in: pty_io, out: pty_io, err: err_pipe_wr)
  ensure
    ## FIXME call any exec_error handler initialized before fork,
    ## ... yielding Process.pid to the exec_error handler here
    ## ... in an additional begin/rescue block,
    ##     no-op under the rescue section
    ##
    ## then clean up & exit
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
    exit($EXITSTATUS)
  end
end


sched_mtx = Mutex.new
cv = ConditionVariable.new
out_mtx = Mutex.new

Thread.new {
  while ! p_err.closed?
    if IO.select([p_err], nil, nil, 0)
      begin
        ## TBD make the readpartial extent a configurable field
        text = p_err.readpartial(512)
      rescue EOFError, IOError => e
        Kernel.warn(e)
        Thread.current.exit
      end
      sched_mtx.synchronize {
        begin
          cv.wait(sched_mtx) if ! out_mtx.try_lock
          Kernel.warn("Read from err #{p_err}: #{text}")
          cv.signal
          text = "".freeze
        ensure
          out_mtx.unlock
        end
      }
    end
  end
  Kernel.warn("err closed")
}


Thread.new {
  while ! p_out.closed?
    ## FIXME the EOFError, IOError handler
    ## needs to be applicable also for IO.select
    if IO.select([p_out], nil, nil, 0)
      begin
        text = p_out.readpartial(512)
      rescue EOFError, IOError => e
        ## will any partial read before EOFError be lost here?
        ## or would readpartial return normally at eof
        ## if there was any data read?
        Kernel.warn(e)
        Thread.current.exit
      end
      sched_mtx.synchronize {
        begin
          cv.wait(sched_mtx) if ! out_mtx.try_lock
          Kernel.warn("Read from out #{p_out}: #{text}")
          cv.signal
          text = "".freeze
        ensure
          out_mtx.unlock
        end
        }
    end
  end
  Kernel.warn("out closed")
}

Kernel.warn("Write to #{p_in}")
p_in.puts 'echo bash ${BASH_VERSION}'
p_in.flush ## this

## needed until fixing the threaded readers' error handling (FIXME)
sleep 0.1

Kernel.warn("close")
p_in.close
p_out.close
p_err.close
