## pipe-mode IO with GLib::Spawn

require 'gtk3'

Gtk.init if Gtk.respond_to?(:init)

STDERR.puts "Is a TTY: #{STDIN.isatty.inspect}"

## FIXME needs port for outside of GLib, using a similar async I/O handling
## and implementing the call to the setup function in the subprocess
## after fork, there
pid, p_in, p_out, p_err =
  GLib::Spawn.async_with_pipes(Dir.pwd, ['bash'],
                               ENV.map{ |v| "%s=%s" % v},
                               GLib::Spawn::SEARCH_PATH) {
  ## setup function for the subprocess
  ##
  ## Advice for implementations is available in the Gtk Documentation
  ## for GSpawnChildSetupFunc.
  ##
  ## see Devehlp docs :: GLib Reference Manual > GLib Utilities
  ## > Spawning Processes @ GSpawnChildSetupFunc
  ##
  ## or on the Web ::
  ## - current GLib version
  ##   https://developer-old.gnome.org/glib/2.68/glib-Spawning-Processes.html#GSpawnChildSetupFunc
  ## - latest GLib version
  ##   https://developer-old.gnome.org/glib/stable/glib-Spawning-Processes.html#GSpawnChildSetupFunc
  ##
  ## TL;DR
  ##
  ## - avoid any system calls that may result in malloc in gtk or libc,
  ##   such that may not be reliable in all operating systems, for the
  ##   section between fork and exec,
  ##
  ## - do not write to ENV here
  ##
  ## - avoid any calls that must rely on mutexes held in the calling process
  ##
  ## - from Linux signal(7) (openSUSE Tumbleweed 20220611, kernel 5.18.2-1)
  ##   apropos signal handlers and fork:
  ##
  ##   "A child created via fork(2) inherits a copy of its parent's signal dispositions.
  ##    During an execve(2), the dispositions of handled signals are reset to the default;
  ##    the  dispositions of ignored signals are left unchanged."
  ##
  ## - pthread docs TBD @ thread inheritance per POSIX / OS
  ##   - in Ruby (??) pthread_atfork(2)
  ##
  ## - Linux signal-safety(7) (openSUSE Tumbleweed, same release info)
  ##
  ##   "POSIX.1-2001 TC1 clarified that if an application calls fork(2)
  ##   from a signal handler and any of the fork handlers registered by
  ##   pthread_atfork(3) calls a function that  is  not async-signal-safe,
  ##   the behavior is undefined.  A future revision of the standard is
  ##   likely to remove fork(2) from the list of async-signal-safe functions."
  ##
  STDERR.puts "In: #{Process.pid}"
  STDIN.close_on_exec = false
  STDOUT.close_on_exec = false
  STDERR.close_on_exec = false
  STDERR.puts "Starting shell ..."
  ## flush any stream that was accessed in the setup function...
  STDERR.flush
  ## FIXME if yielding to an arbitrary setup function here,
  ## yield after begin in a begin/rescue/end block,
  ## then clean up and exit(-1) in the rescue block
  }

sched_mtx = Mutex.new
cv = ConditionVariable.new
out_mtx = Mutex.new


## async i/o for separate output (pty) and error (pipe) streams in the subprocess
##
## orthogonal to the process fork=>exec implementation
##
## FIXME this implementation may ilustrate nondeterministic behaviors,
## as to which reader thread will display its output first.
##
## at least, each reader thread should have independent access to the
## primary output (here, warn => stderr) in this implementation
##
## alternate approach: Use one thread, select on err and out
## - cf ./ptytest.rb

Thread.new {
  begin
    while ! p_err.closed?
      if IO.select([p_err], nil, nil, 0)
        begin
          text = p_err.readpartial(2048)
          sched_mtx.synchronize {
            begin
              out_mtx.try_lock || cv.wait(sched_mtx)
              Kernel.warn("Read from err #{p_err}: #{text}")
              cv.signal
              text = "".freeze
            ensure
              out_mtx.unlock
            end
          }
        end
      end
    end
  rescue EOFError, IOError => e
    Kernel.warn(e)
    Thread.current.exit
  end
  Kernel.warn("err closed")
}

Thread.new {
  begin
    while ! p_out.closed?
      if IO.select([p_out], nil, nil, 0)
        text = p_out.readpartial(2048)
        sched_mtx.synchronize {
          begin
            out_mtx.try_lock || cv.wait(sched_mtx)
            Kernel.warn("Read from out #{p_out}: #{text}")
            cv.signal
            text = "".freeze
          ensure
            out_mtx.unlock
          end
        }
      end
    end
  rescue EOFError, IOError => e
    ## TBD will any partial read before EOFError be lost here?
    ## or would IO#readpartial return normally at eof,
    ## if there was any data read?
    Kernel.warn(e)
    Thread.current.exit
  end
  Kernel.warn("out closed")
}

Kernel.warn("Write to #{p_in}")
p_in.puts 'echo bash ${BASH_VERSION}'
p_in.flush ## this

sleep 3

Kernel.warn("close")
p_in.close
p_out.close
p_err.close
