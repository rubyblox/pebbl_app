

require 'pebbl_app/support'

require 'timeout'

module PebblApp::Support

  class DataLocker

    def initialize()
      ## initializing these here, it may work out.
      ## if deferring initailization to the accessors, it may not.
      @mtx = Mutex.new
      @data_mtx = Mutex.new
      @cv = ConditionVariable.new
    end

    ## mutex for scheduling with condition variable #cv
    def mtx
      @mtx ||= Mutex.new
    end

    ## mutex for data operations
    def data_mtx
      @data_mtx || Mutex.new
    end

    ## condition variable for scheduling with mutex #mtx
    def cv
      @cv ||= ConditionVariable.new
    end

    ## conditionally evaluate block with #data_mtx held, signaling with
    ## condition variable #cv after exit from block, if the condition
    ## variable was accessed pursuant to holding the data_mtx
    ##
    ## @param wait [Numeric not Complex, nil] timeout for the
    ##  condition variable synchronization, if not a falsey value
    ##
    ## @param block [Proc] block to evaluate with #data_mx held
    ##
    def with_conditional_access(wait = nil, &block)
      self.mtx.synchronize do
        got_cv = false
        ## try to hold the data_mtx if not already owned.
        ## if not available at this moment, wait on the cv
        ## using the cv scheduling mtx, then try again for the data_mtx.
        ##
        ## when $DEBUG, warnings may be emitted to ensure failures are
        ## visible on STDERR
        if ! ( self.data_mtx.owned? || self.data_mtx.try_lock ||
              ## this may actually need to be called as so - even if nil is
              ## provided as the second arg, it might change how the
              ## actual implementation behaves, compared to when no
              ## second arg is provided
              ##
              ## FIXME still not quite right - at this point, it might
              ## never hold the initial scheduling mtx
              ((got_cv = wait ?
                self.cv.wait(self.mtx, wait) : self.cv.wait(self.mtx)) &&
               self.data_mtx.try_lock))
          e = ThreadError.new("failed conditional access on #{self} in #{Thread.current}")
          ## warn with the exception, to ensure it should be visible
          ## on STDERR - when $DEBUG
          Kernel.warn(e, uplevel: 0) if $DEBUG
          raise e
        end
        begin
          block.yield
        ensure
          ## cv would not have been got if the data_mtx was initially available
          self.cv.signal if got_cv
          begin
            ## cannot accomplish this with Mutex#synchronize
            ## - release the mutex here
            self.data_mtx.unlock
          rescue ThreadError => e
            ## error here may indicate if this thread no longer has
            ## mutex ownership of the data_mtx - warn if debug
            Kernel.warn(e, uplevel: 1) if $DEBUG
          end
        end
      end
    end

    ## conditionally evaluate block with #data_mtx held, broadcasting for
    ## condition variable #cv after exit from block, if the condition
    ## variable was accessed pursuant to holding the data_mtx
    ##
    ## @param wait [Numeric not Complex, nil] timeout for the
    ##  condition variable synchronization, if not a falsey value
    ##
    ## @param block [Proc] block to evaluate with #data_mx held
    ##
    def with_conditional_access(wait = nil, &block)
      self.mtx.synchronize do
        got_cv = false
        ## similar to the previous. differs in how the cv is signaled at end
        if ! ( self.data_mtx.owned? || self.data_mtx.try_lock ||
              ((got_cv = wait ?
                self.cv.wait(self.mtx, wait) : self.cv.wait(self.mtx) )  &&
             self.data_mtx.try_lock))
          e = ThreadError.new("failed conditional access on #{self} in #{Thread.current}")
          Kernel.warn(e, uplevel: 0) if $DEBUG
          raise e
        end
        begin
          block.yield
        ensure
          self.cv.broadcast if got_cv
          begin
            self.data_mtx.unlock
          rescue ThreadError => e
            Kernel.warn(e, uplevel: 1) if $DEBUG
          end
        end
      end
    end

  end
end
