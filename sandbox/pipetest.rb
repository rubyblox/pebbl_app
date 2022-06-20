## pipe-mode IO with GLib::Spawn

require 'gtk3'
Gtk.init if Gtk.respond_to?(:init)

STDERR.puts "stdin is a TTY: #{STDIN.isatty.inspect}"

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
  ## - avoid any calls that would rely on mutexes held in the calling process
  ##
  ## - from Linux signal(7) (openSUSE Tumbleweed 20220611, kernel 5.18.2-1)
  ##   apropos signal handlers and fork:
  ##
  ##   "A child created via fork(2) inherits a copy of its parent's signal dispositions.
  ##    During an execve(2), the dispositions of handled signals are reset to the default;
  ##    the  dispositions of ignored signals are left unchanged."
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
  STDERR.puts "Starting shell"
  ## flush any stream that was accessed in the setup function...
  STDERR.flush
  ## FIXME if yielding to an arbitrary setup function here,
  ## yield after begin in a begin/rescue/end block,
  ## then clean up and exit(-1) in the rescue block
  }


Thread.new {
  begin
    while ! p_in.closed?
      if (selected = IO.select([p_err, p_out], nil, nil, 0))
        selected.each do |avl|
          avl.each do |io|
            begin
              text = io.readpartial(2048)
              Kernel.warn(
                "-- Read from %s\n%s" % [
                  (io == p_err ? :err : :out), text
                ])
            end
          end
        end
      end
    end
  rescue EOFError, IOError => e
    Kernel.warn(e)
    Thread.current.exit
  end
  Kernel.warn("-- input closed")
}

## delay for synch
sleep 0.1

Kernel.warn("-- Writing to pty")
p_in.puts 'echo bash ${BASH_VERSION}'
p_in.flush ## this

## delay for synch
sleep 0.1

Kernel.warn("-- close")
p_in.close
p_out.close
p_err.close
