## ioproc.rb

module IOProc
end

class IOProc::OutProc

  def self.run(cmd, read_out: nil , read_err: nil, **procopts)

    ## TBD args
    ## read_out_prepare : proc/lambda to call on the read_out stream
    ##                    before spawn
    ## read_err_prepare : similar, called on the read_err stream

    if read_out
      out_read, out_write = IO.pipe
    else
      out_write = :close
    end

    if read_err
      err_read, err_write = IO.pipe
    else
      err_write = :close
    end

    procopts.include?(:in) || procopts[:in] = :close

    read_out && procopts[:out] = out_write
    read_err && procopts[:err] = err_write

    ## spawn the process and wait for the
    ## process to exit
    subpid = Process.spawn(cmd, procopts)
    subpid, status = Process.wait2(subpid)

    read_out && ( out = IO.new(out_read.to_i, "r") )
    read_err && ( err = IO.new(err_read.to_i, "r") )

    read_out && out_write.close
    read_err && err_write.close

    if read_out
      out.each_line do |txt|
        read_out.call(txt)
      end
    end

    if read_err
      err.each_line do |txt|
        read_err.call(txt)
      end
    end

    return status.exitstatus

  ensure

    ## NB fails (EBADF) during close
    # out.closed? || out.close
    # err.closed? || err.close

    if read_out
      out_write.close
      out_read.close
    end

    if read_err
      err_write.close
      err_read.close
    end
  end
end


=begin

## Test - this block should show normal method
## behaviors for OutProc.run when evaluated

out = lambda { |txt| puts "Out: " + txt }
err = lambda { |txt| puts "Err: " + txt }

puts IOProc::OutProc.run("ls -d /etc /var/frob", 
     read_out: out, read_err: err,  )

=end
