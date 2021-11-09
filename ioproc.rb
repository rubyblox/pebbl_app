## ioproc.rb


=begin rdoc
<b>IOProc - Ruby language extensions for I/O with external processes</b>
=end
module IOProc
end


=begin rdoc
= Overview
The *OutProc::run* class method provides an extension
for *Process::spawn*  in supporting a generally functional 
approach for parsing output from external processes.

In addition to the set of parameters supported by
*Process::spawn*, the *OutProc::run* method
accepts a +Proc+ or +lambda+ form for each of the
method's named parameters, +read_out+ and +read_err+. 
Any +Proc+ or +lambda+ form provided to these parameters 
will  be called on each line of output or error text 
that was produced by the subprocess.

Both of the named +read_out+ and +read_err+ parameters 
are optional parameters.

Any additional parameters for *Process::spawn* may be 
passed in the named +options+ parameter to the 
*OutProc::run*.

The *OutProc::run* method will return the exit status
of the external process as an integer numeric value.

== Example

Processing an external command's <em>standard output</em> 
and <em>standard error</em> output, to produce a form
of tagged output on the standard output stream within the
<b>ruby(1)</b> process, lastly printing the exit status
of the external command:

    out_fn = lambda { |txt| puts "Out: " + txt }
    err_fn = lambda { |txt| puts "Err: " + txt }

    puts IOProc::OutProc.run(
        "ls -d /etc /nonexistent",
        read_out: out_fn, read_err: err_fn
    )

Subsequent output:

    Out: /etc
    Err: ls: cannot access '/nonexistent': No such file or directory
    2


== Known Limitations

* This method does not provide any support for additional configuration
  of the <b>IO.pipe</b> and IO stream objects created for each of the
  +read_out+ and +read_err+ functions.

* This method does not provide any direct support for asynchronous
  parsing of output from the subprocess. Before any output is parsed,
  this method will block until the external process has
  exited.

* Any +read_out+ function will be called before any +read_err+
  function. Thus, output stream contents will be parsed before 
  error stream contents.

* If +read_out+ is provided, any +:out+ value provided in +options+ 
  will be overwritten. Similarly, if +read_err+ is provided, any 
  +:err+ value provided in +options+ will be overwritten.

* This method does not provide any similar <b>IO.pipe</b> support for 
  the <em>standard input</em> stream to the subprocess. If no +:in+ 
  parameter is provided in +options+, an +:in+ parameter will be added, 
  with the value +:close+

* While this method may be applied for line-oriented text parsing, 
  in any methodology generally resembling <b>awk(1)</b>, there is
  no additional parsing support provided here beyond the immediate 
  enacpsulation and stream handling for *Process::spawn*

* This method does not provide any speific support for running a
  privileged process, such as via <b>sudo(8)</b> or
  <b>su(1)</b>

=end
class IOProc::OutProc

  ## @param cmd [string|array] External command. This parameter
  ##  uses the same syntax as the +command+ parameter for 
  ##  **Process::spawn**
  ## @param read_out [lambda|Proc|nil] If true, functional form to call
  ##  for each line of text on the process <em>standard output</em>
  ##  stream
  ## @param read_err [lambda|Proc|nil] If true, functional form to call
  ##  for each line of text on the process <em>standard error</em>
  ##  stream
  ## @param options [nil|Hash] If true, a Hash value providing optional
  ##  configuration for **Process::spawn**
  ## @see https://www.rubydoc.info/stdlib/core/Process.spawn Process::spawn
  def self.run(*cmd, read_out: nil , read_err: nil, options: nil)

    if read_out
      out_read, out_write = IO.pipe
    elsif options && options.include?(:out)
      ## i.e do not set :out
      out_write = false
    else
      out_write = :close
    end

    if read_err
      err_read, err_write = IO.pipe
    elsif options && options.include?(:err)
      ## i.e do not set :err
      err_write = false
    else
      err_write = :close
    end

    options || ( options = {} )

    options.include?(:in) && options[:in] = :close

    out_write && ( options[:out] = out_write )
    err_write && ( options[:err] = err_write )

    ## spawn the process and wait for the
    ## process to exit
    subpid = Process.spawn(*cmd, options)
    subpid, status = Process.wait2(subpid)

    read_out && ( out = IO.new(out_read.to_i, "r") )
    read_err && ( err = IO.new(err_read.to_i, "r") )

    ## IF if these aren't closed before the read,
    ## the read would indefinitely
    read_out && out_write.close
    read_err && err_write.close

    read_out &&
      out.each_line do |txt|
        read_out.call(txt)
      end

    read_err &&
      err.each_line do |txt|
        read_err.call(txt)
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

puts IOProc::OutProc.run("ls -d /etc /nonexistent",
     read_out: out, read_err: err)

=end
