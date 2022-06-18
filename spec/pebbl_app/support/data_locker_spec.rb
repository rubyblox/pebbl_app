##

## TBD the testing framework itself may not be higly reliable here
##
## These are each independent tests, and yet they may demonstrate
## some peculiar side effects to each, after a change in the
## implementation of any other.

## the library to test
require 'pebbl_app/support/data_locker'

describe PebblApp::Support::DataLocker do
  let(:delay) { 5 }
  let(:token) { nil }
  subject { nil }

  it "locks data mtx in block" do
    inst = PebblApp::Support::DataLocker.new
    thr_a_gotlock = false
    thr_a_eval = false
    thr_b_gotlock = false
    thr_b_eval = false
    thr_a = Thread.new {
      inst.with_conditional_access {
        thr_a_eval = true
        thr_a_gotlock = inst.data_mtx.owned?
        sleep delay
      }
    }
    thr_b = Thread.new {
      inst.with_conditional_access {
        thr_b_eval = true
        thr_b_gotlock = inst.data_mtx.owned?
      }
    }
    thr_a.join
    thr_b.join
    expect(thr_a_eval).to be true
    expect(thr_b_eval).to be true
    expect(thr_a_gotlock).to be true
    expect(thr_b_gotlock).to be true
  end

  it "enables conditional data access" do
    inst = PebblApp::Support::DataLocker.new()
    token = nil
    thr_a = Thread.new {
      inst.with_conditional_access {
        sleep delay
        token = 1
      }
    }
    thr_b = Thread.new {
      inst.with_conditional_access {
        expect(token).to be == 1
        token = 0
      }
    }
    thr_a.join
    thr_b.join
    expect(token).to be == 0
  end

  ## FIXME untested: the timeout condition in with_conditional_access

  it "enables conditional data access in time" do
    inst = PebblApp::Support::DataLocker.new
    token = nil
    thr_a = Thread.new {
      inst.with_conditional_access {
        sleep delay
        token = 1
      }
    }
    thr_b = Thread.new {
      inst.with_conditional_access(delay + 5) {
        token = 0
      }
    }
    thr_a.join
    thr_b.join
    ## this test fails when the conditional/timeout test above
    ## is not defined? how is that now?
    expect(token).to be == 0
  end

end
