## DispatchTest : Example GMain application

## **Example: DispatchTest**
##
## The class DispatchTest extends GMain, there overriding the GMain
## #configure and #main methods
##
## The #main method in DispatchTest calls the superclass' #main method
## via `super`, there providing a custom GMainContext instance and
## a local block to the `super` call. The block implements a custom
## application logic independent to the service main loop. This block
## will be called in the same thread as #main.
##
## In application with the #main method on GMain, the DispatchTest
## event loop will exit after control has exited the block provided to
## the GMain #main method.
##
## The #configure method in the DispatchTest example will add a
## GLib::Idle kind of GLib::Source to the context object provided to the
## method.
##
## This #configure method uses GMain.map_idle_source to add a callback
## on the the idle source and to add the source to the provided
## context. The #configure method then sets a source priority on the
## source object returned by GMain.map_idle_source. In the DispatchTest
## example, the idle source's callback block will call the implementing
## class' `do_work` method. This callback should be reached in each
## normal iteration of the application's main loop.
##
## The `DispatchTest#main` method provides a five second wait in the
## local block, to simulate a duration in application runtime. Semantically,
## the implementation provides an example of event dispatch outside of a
## main application thread, using an extension on GLib::MainContext.
##
## The `main` method on `DispatchTest` produces some output on the
## standard error stream, for purpose of illustration in the test.
##
## Using the DispatchTest example:
## ~~~~
## require_relative 'service-example.rb'
##
## # Initialize a new DispatchTest
## test = DispatchTest.new
##
## # call #main
## test.main
##
## # review the event log in the DispatchTest's data object
## test.data.work_log
##
## # call main again
## test.main
##
## # interrupt the main thread, such as with "Ctl-C"
## # under interactive eval (user input)
##
## # review the event log after interrupt
## test.data.work_log
##

require 'pebbl_app/gmain'
require 'forwardable'

require 'pebbl_app/app_log'

PebblApp::AppLog.app_log ||= PebblApp::AppLog.new()

PebblApp::AppLog.app_log.level = "DEBUG"

## NB signal trap support in GtkApp
require 'pebbl_app/signals'

## Data object class for the DispatchTest example
class TestData

  ## a hash table of Time values and event tags, used for internal
  ## logging in the DispatchTest example
  attr_reader :work_log

  def initialize()
    super()
    @work_log = {}
  end

  ## log an event of the provided tag value using the provided time
  ## as when storing the entry in #work_log
  def log_event(tag, time = Time.now)
    self.work_log[time] = tag
  end
end

## a GMainContext for the DispatchTest example, storing an arbitrary
## data value.
##
## In the DispatchTest example, the data value will typically be a
## TestData instance. The data value to the TestContext will be
## initialied as the data value in the DispatchTest instance.
##
## The availability of the data value in the TestContext will permit for
## forwarding to the TestData#log_event method from within context
## methods
class TestContext < PebblApp::GMainContext
  attr_reader :data

  def initialize(data)
    super(blocking: true)
    @data = data
  end

  ## add an event to the data work log, for purposes of test
  def log_event(tag)
    self.data.log_event(tag)
  end
end

## an adaptation after
## https://developer.gnome.org/documentation/tutorials/main-contexts.html
class DispatchTest < PebblApp::GMain
  self.extend Forwardable

  attr_reader :data, :handlers
  ## TBD Generalization / Modularity - move @handlers to App
  def_delegators(:@handlers, :set_handler, :with_handler)

  ## Create a new DispatchTest, using a new instance of TestData and a
  ## log initialized for a debug level of information.
  def initialize()
    super()
    @handlers = PebblApp::SignalMap.new
    @data = TestData.new
  end

  ## generally emulating `my_func` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
  ##
  ## add to the ostruct.work_log, dependent on the ostruct.cancelled flag
  ## in the ostruct
  ##
  ## called under a callback initialized in #configure
  ##
  def do_work(data)
    PebblApp::AppLog.debug("do_work continuing")
    data.log_event(:loop_cont)
    ## pause a second, for purpose of tests
    sleep 1
  end

  def map_sources(context)
    PebblApp::GMain.map_idle_source(context, priority: :default) do
      ## each idle source's callback will be called
      ## in each main loop iteration
      if context.cancelled?
        ## not yet reached under tests
        PebblApp::AppLog.debug("In callback (cancelled)")
      else
        ## Similar to the original example in the GLib documentaiton,
        ## this modular API will dispatch to a method outside of this
        ## callback/context model, mainly #do_work
        PebblApp::AppLog.debug("In callback => do_work")
        data.log_event(:callback)
        do_work(data)
        # PebblApp::AppLog.debug("Testing error handling") if $DEBUG_ERROR_HANDLING
        # raise "Test" if $DEBUG_ERROR_HANDLING
      end
    end
  end

  def context_new(data)
    TestContext.new(data)
  end

  def context_acquired(context)
    ## protocol method (nop)
  end

  ## a partial adaptation after `main` in
  ## https://developer.gnome.org/documentation/tutorials/main-contexts.html
  ##
  ## @see GMain#main
  def main(wait = 5)
    initial_debug = $DEBUG
    $DEBUG = true

    PebblApp::AppLog.debug("in #main(#{wait})")

    begin ## debug block
      data = self.data
      context = context_new(data)

      ## thread for join in handlers, if set
      main_thread = nil

      ##
      ## Signal trap functions
      ##
      interrupt_tag = :trap
      hdlr_base = proc { |sname, nxt|
        ## append a value to the work log
        context.log_event([:signal, sname])
      }
      hdlr_cancel = proc { |sname, nxt|
        warn("Handling signal #{sname}")
        ## Cancel the main event loop, then join the main thread.
        ## The main thread should return after the cancellation
        hdlr_base.yield(sname)
        self.running = false
        context.cancellation.cancel
        ## joining the main thread in any throw/exit handler should help
        ## to ensure a clean exit for the main thread.
        ##
        ## This assumes that the main thread will exit the main loop and
        ## return, once the context's cancellation object is set to
        ## cancelled, such as in GMain#context_main
        main_thread.join if main_thread
      }
      term_hdlr = proc { |sname, nxt|
        ## cancel, join the main thread, then throw
        ##
        ## the thrown value will provide the return value for this method
        ##
        ## this provides a "throw, not exit" behavior on the assumption
        ## that the caller of this method will handle any exit procedures
        hdlr_cancel.yield(sname)
        throw(interrupt_tag, sname)
      }
      int_hdlr  = proc { |sname, nxt|
        ## cancel, join the main thread, then exit
        hdlr_cancel.yield(sname)
        exit(0)

      }
      quit_hdlr = proc { |sname, nxt|
        ## cancel, join the main thread, then exit immediately
        hdlr_cancel.yield(sname)
        exit!(0)
      }
      usr1_hdlr = proc { |sname, perv|
        ## log the state of the event log, to the service log
        PebblApp::AppLog.info("Handling signal #{sname}")
        hdlr_base.yield(sname)
        PebblApp::AppLog.info("Running")
        self.data.work_log.each do |data|
          PebblApp::AppLog.info("[event] %s : %s" % data)
        end
      }

      ##
      ## signal traps (not tested on Microsoft Windows platforms)
      ##
      if $DEBUG
        ## swapped signal handling for INT, TERM
        ## e.g to have SIGINT via Ctrl-c end the main method
        ## without ending the process. Useful for interactive eval
        handlers.set_handler("INT", &term_hdlr)
        handlers.set_handler("TERM", &int_hdlr)
      else
        ## normal signal handling for INT, TERM
        handlers.set_handler("INT", &int_hdlr)
        handlers.set_handler("TERM", &term_hdlr)
      end
      handlers.set_handler("QUIT", &quit_hdlr)
      handlers.set_handler("USR1", &usr1_hdlr)
      begin
        ## FreeBSD and OSX offer a SIGINFO signal.
        ## This signal is not implemented on Linux.
        ##
        ## More detail, via Safari Books Online:
        ## https://learning.oreilly.com/library/view/advanced-programming-in/9780321638014/ch10.html
        ##
        ## For an example, the ddpt program handles SIGUSR1 (on Linux)
        ## similar to SIGINFO (on FreeBSD) when running under a verbose
        ## option. Similarly, this method handles SIGINFO (when available)
        ## with the same callback as for SIGUSR1.
        handlers.set_handler("INFO", &usr1_hdlr)
      rescue ArgumentError
        ## nop
      end

      cancellation = context.cancellation
      cancellation.reset
      cancellation.signal_connect_after("cancelled") do
        PebblApp::AppLog.debug("Cancellation reached")
        context.log_event(:cancellation)
      end

      catch(interrupt_tag) do
        handlers.with_handlers do ## outside of the main block
          super(context) do |main|
            ## set the main_thread for handlers
            main_thread = main
            ## simulating a duration in application runtime,
            ## while the main loop runs, then cancelling
            ## to ensure the main loop exits.
            ##
            ## logging before return
            sleep wait
            context.cancellation.cancel(:end)
            PebblApp::AppLog.debug("Done")
            context.log_event(:ext_return)
          end
        end ## with_handlers
        return context.data ## not returned on event of interrupt
      ensure
        $DEBUG = initial_debug
      end  ## catch interrupt_tag ... super(...) &block
    end ## debug block
  end ## main
end
