

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
## - Due to the present implementation of the #data `quit` field
## ... should not be accessed outside of the thread in which
##   MainDispatch#main was called
##
## FIXME/TBD
##
## - Define an internal class for the #data field (work log optional)
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
  ##    a) via #with_dispatch: initialize a callback block, for dispatch
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
    ## log the event
    data.work_log[Time.now] = :init

    ## Initialize and hold a mutex during configuration and application runtime
    main_mtx = Mutex.new

    ## local context object for the GLib::MainLoop
    ## which will be created in the main thread
    STDERR.puts "Init context"
    context = GLib::MainContext.new

    main_thr = false

    ## using a separate mutex for blocking the main loop
    ## during event source configuration
    conf_mtx = Mutex.new

    ## then releasing the mutex and begininng
    ## processsing for the main event loop.
    ##
    ## The nop-op block on the mutex in the context_main thread
    ## should serve to prevent that the event loop would be reached
    ## before all event sources are configured from here. (DNW)
    ##
    begin
      conf_mtx.lock
      ## configuring all known event sources on the context,
      ## before initializing the main thread
      STDERR.puts "Configure dispatch for work"

      begin
        with_dispatch(context, data) ## do ... do_work .. end (block form)
        STDERR.puts "Call for main thread"
        main_thr = context_main(context, data, main_mtx, conf_mtx)
      rescue
        data.quit = $!
        main_thr.exit if main_thr
        return false
      end

      ## simulating a duration in application runtime, before return
      main_mtx.synchronize do
        conf_mtx.unlock
        sleep 5
        STDERR.puts "Done"
        time = Time.now
        ## log the event, for data review
        data.quit = time
        data.work_log[time] = :quit
      end ## main_mtx

      # context.unref # n/a
      main_thr.join
      return data

    end ## conf_mtx
  end

  ## protected methods can be extended in a subclass
  protected

  ## emulating `my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html#
  ##
  ## add to the ostruct.work_log, dependent on the ostruct.quit flag
  ## in the ostruct
  ##
  ## called under a callback initialized in #with_dispatch
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
  def with_dispatch(context, ostruct)
    STDERR.puts "dispatch setting callback"
    ostruct.work_log[Time.now] = :dispatched
    src = GLib::Idle.source_new
    src.set_callback do
      ## called in each main loop iteration
      STDERR.puts "In callback => do_work"
      ostruct.work_log[Time.now] = :callback
      do_work(ostruct)
    end
    src.priority = GLib::PRIORITY_DEFAULT
    ## add the source and its callback to the provided main context
    src.attach(context)
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
  def context_main(context, ostruct, main_mtx, conf_mtx)
    thr = Thread.new do
      ostruct.work_log[Time.now] = :main_run
      STDERR.puts "... main thread begins"
      main = GLib::MainLoop.new(context, false) ## false => not run
      @main = main

      ## block on conf_mtx, while caller is configuring event sources
      conf_mtx.synchronize do
        Thread.exit if ostruct.quit

        ## Iterate in the event loop until the mutex provided by the
        ## caller can be held in the dispatch loop, or until
        ## ostruct.quit is indicated.
        ##
        ## Once the mutex can be held here: Cleanup (quit main),
        ## release the mutex and return
        ostruct.work_log[Time.now] = :main_iterate
        catch(:quit) do |tag|
          while ! main_mtx.try_lock
            if ostruct.quit
              ## lock held, but ostruct.quit is indicated
              throw tag
            else
              context.iteration(true) ## blocking iteration
            end
          end
        end
        begin
          ostruct.work_log[Time.now] = :main_quit
          STDERR.puts ".. quit main context"
          ## cleanup
          main.quit
          #main.unref # n/a
        ensure
          main_mtx.unlock
        end
      end ## conf_mtx
    end ## thread
    return thr
  end

end

