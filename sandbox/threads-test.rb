

require 'ostruct'


if ! Kernel.const_defined?(:Gtk)
  if ! ENV['DISPLAY']
    Kernel.warn("No display", uplevel: 0)
    exit
  end
  require 'gtk3'
end

## An adaptation after
## https://developer.gnome.org/documentation/tutorials/main-contexts.html
## using GLib context support in Ruby-GNOME
##
## Example
## ~~~~
## test = MainDispatch.new
## data = test.main
## data.work_log.to_a
## ~~~~
##
## Notes
##
## - MainDispatch#main can be called more than once, within one calling thread
##
## - Due to the present implementation of the #data `quit` field and an
##   internal flag as #data `dispatched`, the protected methods on each
##   MainDispatch, and the 'quit' and 'dispatched' flags on the #data
##   object should not be accessed outside of the thread in which
##   MainDispatch#main was called
##
## FIXME/TBD
##
## - Define an internal class for the #data field
##
## - Integration with GTK
##
## - Application with FD polling for vtytest
##
class MainDispatch

  attr_reader :data

  ## an adapted emulation of `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## 1) ensure that an OpenStruct is initialized for the #data field on
  ##    this instance, setting tue 'quit' field to false on that #data
  ##    object
  ##
  ## 2) for a new GLib::MainContext and the #data object for the instance:
  ##
  ##    a) via #dispatch_work: initialize a callback block, for dispatch
  ##       in each iteration of the main loop. The #do_work method will
  ##       be called in each call to the callback,
  ##
  ##    b) via #context_main: initialize a main thread, providing a
  ##       main loop implementation in the thread. The loop will run
  ##       until the `quit` field on the #data object is true
  ##
  ## 3) pause before return, to simulate application runtime
  ##
  ## 4) return the #data object
  ##
  ## This method can be called zero or more times, within any single
  ## thread.
  ##
  ## After return, the work_log field of the #data struct may illustrate
  ## any new events that were processed for this instance.
  ##
  def main
    STDERR.puts "main"

    STDERR.puts "Init data"
    data = (@data ||= OpenStruct.new(work_log: {}))
    ## re/initialize all runtime flags
    data.quit = false
    data.dispatched = false
    ## log the event
    data.work_log[Time.now] = :init

    ## local context object for the GLib::MainLoop
    ## which will be created in the main thread
    STDERR.puts "Init context"
    context = GLib::MainContext.new

    ## configuring all known event sources on the context,
    ## before initializing the main thread
    STDERR.puts "Configure dispatch for work"
    dispatch_work(context, data)

    STDERR.puts "Call for main thread"
    main_thr = context_main(context, data)

    ## simulating a duration in application runtime, before return
    sleep 5
    STDERR.puts "Done"
    time = Time.now
    ## log the event, for data review
    data.quit = time
    data.work_log[time] = :quit
    # context.unref # n/a
    main_thr.join
    return data
  end

  ## protected methods can be extended in a subclass
  protected

  ## emulating `my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## add to the ostruct.work_log, dependent on the ostruct.quit flag
  ## in the ostruct
  ##
  ## called under a callback initialized in #dispatch_work
  ##
  def do_work(ostruct)
    if ostruct.quit
      STDERR.puts "do_work reached under quit"
      ostruct.work_log[Time.now] = :loop_quit
    else
      STDERR.puts "do_work continuing"
      ostruct.work_log[Time.now] = :loop_cont
      sleep 1
    end
  end

  ## emulating `invoke_my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## initialize a GLib::Idle source for a provided GLib::MainContext,
  ## creating a callback block on that idle source as to dispatch
  ## to do_work on the provided ostruct data
  ##
  ## The callback will be called in each iteration of the main loop
  ## for the provided main context
  ##
  ## called under #main
  ##
  ## returns the new GLib::Idle source, as added to the context
  ##
  def dispatch_work(context, ostruct)
    STDERR.puts "dispatch setting callback"
    ostruct.work_log[Time.now] = :dispatched
    src = GLib::Idle.source_new
    src.set_callback do
      ## tcalled in each main loop iteration
      STDERR.puts "In callback => do_work"
      ostruct.work_log[Time.now] = :callback
      do_work(ostruct)
    end
    src.priority = GLib::PRIORITY_DEFAULT
    ## add the source and its callback to the provided main context
    src.attach(context)
    ## set a synchronization flag, for the main loop to begin iteration
    ostruct.dispatched = true
    STDERR.puts "callback set"
    return src
  end

  ## an adaptated emulation of `thread1_main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## within a separate thread:
  ## 1) initialize a GLib::MainLoop for a provided GLib::MainContext
  ##    and local data
  ## 2) Iterate on the context until ostruct.quit returns true
  ##
  ## called under #main
  ##
  ## returns the new thread
  def context_main(context, ostruct)
    thr = Thread.new do
      ostruct.work_log[Time.now] = :main_run
      STDERR.puts "... main thread begins"
      main = GLib::MainLoop.new(context, false) ## false => not run
      @main = main
      while ! ostruct.dispatched
        ## wait for other threads to catch up
        ##
        ## FIXME could use a mutex and cv wait, here,
        ## rather than spinning in a wait loop ...
      end
      ostruct.work_log[Time.now] = :main_iterate
      STDERR.puts "... dispatched" unless ostruct.dispatched
      while ! ostruct.quit
        context.iteration(true)
      end
      ostruct.work_log[Time.now] = :main_quit
      STDERR.puts ".. quit main context"
      main.quit
      #main.unref # n/a
    end
    return thr
  end

end

