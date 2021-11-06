## ioproc.rb


class OutProc

  def self.run(cmd, read_out: nil , read_err: nil, **procopts)

    if read_out
      out_rd, out_wr = IO.pipe
    else
      out_wr = :close
    end

    if read_err
      err_rd, err_wr = IO.pipe
    else
      err_wr = :close
    end

    procopts.include?(:in) || procopts[:in] = :close
    procopts[:out] = out_wr
    procopts[:err] = err_wr

    subpid = Process.spawn(cmd, procopts)

    subpid, status = Process.wait2(subpid)

    read_out && ( out = IO.new(out_rd.to_i, "r") )
    read_err && ( err = IO.new(err_rd.to_i, "r") )

    read_out && out_wr.close
    read_err && err_wr.close

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

    return status

  ensure

    ## NB fails (EBADF) during close
    # out.closed? || out.close
    # err.closed? || err.close

    if read_out
      out_wr.close
      out_rd.close
    end

    if read_err
      err_wr.close
      err_rd.close
    end
  end
end


/*


out = lambda { |txt| puts "Out: " + txt }
err = lambda { |txt| puts "Err: " + txt }

puts
OutProc.run("ls -d /etc /var/frob", read_out: out, read_err: err,  )

*/
