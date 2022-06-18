

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
      self.mtx.synchronize {
        if (self.data_mtx.owned? || self.data_mtx.try_lock)
          begin
            block.yield
          ensure
            self.data_mtx.unlock
            self.cv.signal
          end
        else
          got_cv = wait ? self.cv.wait(self.mtx, wait) : self.cv.wait(self.mtx)
          if got_cv
            begin
              self.data_mtx.synchronize {
                block.yield
              }
            ensure
              self.cv.signal
            end
          else
            raise ThreadError.new("Conditional wait failed")
          end
        end
      }
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
      self.mtx.synchronize {
        if (self.data_mtx.owned? || self.data_mtx.try_lock)
          begin
            block.yield
          ensure
            self.data_mtx.unlock
            self.cv.broadcast
          end
        else
          got_cv = wait ? self.cv.wait(self.mtx, wait) : self.cv.wait(self.mtx)
          if got_cv
            self.data_mtx.synchronize {
              block.yield
            }
          else
            raise ThreadError.new("Conditional wait failed")
          end
        end
      }
    end

  end
end
