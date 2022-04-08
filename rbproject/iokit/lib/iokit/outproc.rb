## ioproc.rb

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}


## TBD outproc_privileged.rb
## - sudo and askpass/tty
## - deferred call after early uid change

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

    puts IOKit::OutProc.run(
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
class IOKit::OutProc
  ## Run a command with *Process.spawn*, calling a provided proc
  ## on each line of standard output and/or standard error stream
  ## text.
  ##
  ## This method returns the numeric process exit code of the
  ## spawned process. If this value is non-zero, it may be
  ## commonly assumed that the process exited with error.
  ##
  ## @param cmd [String|Array of String] External command. This
  ##  parameter  uses the same syntax as the +command+ parameter
  ##  for *Process::spawn*
  ##
  ## @param read_out [Proc|nil] If non-nil, a functional form to
  ##  call for each line of text on the <em>standard output</em>
  ##  stream. If provided, +options+ must not include an +:out+
  ##  option
  ##
  ## @param read_err [Proc|nil] If non-nil, a functional form to
  ##  call for each line of text on the <em>standard error</em>
  ##  stream. If provided, +options+ must not include an +:err+
  ##  option
  ##
  ## @param encoding [Encoding|array] an Encoding value to use
  ##  for the external encoding in each *IO.pipe* call, or an
  ##  array of [external, internal] encoding values for each
  ##  call
  ##
  ## @param options additional options for the call to
  ##  *Process::spawn*
  ##
  ## @see Process::spawn
  def self.run(*cmd, read_out: nil,
               read_err: nil,
               encoding: Encoding.default_external,
               timeout: nil, **options)

    ## TBD implementing run_async + (poll fd ...) (use timeout)
    ## and async stream I/O
    ## - needs usage case @ condition variables instead of poll,
    ##   for async I/O across threads within the same process
    if encoding.is_a?(Array)
      ## here, the value of the encoding option should be
      ## an array of [external, internal] encoding values
      use_enc = encoding
    else
      use_enc = [encoding]
    end

    if read_out
      if options.include?(:out)
         raise ArgumentError.new("Both :out and :read_out provided")
       else
         out_read, out_write = IO.pipe(*use_enc)
       end
    elsif options.include?(:out)
      ## NB will not set :out here
      out_read = false
      out_write = false
    else
      ## no output stream used for the spawn call
      out_read = false
      out_write = :close
    end

    if read_err
       if options.include?(:err)
         raise ArgumentError.new("Both :err and :read_err provided")
       else
         err_read, err_write = IO.pipe(*use_enc)
       end
    elsif options.include?(:err)
      ## NB will not set :err here
      err_read = false
      err_write = false
    else
      ## no error stream used for the spawn call
      err_read = false
      err_write = :close
    end

    options.include?(:in) || ( options[:in] = :close )

    ## set out, err options if none provided
    out_write && ( options[:out] = out_write )
    err_write && ( options[:err] = err_write )

    st = nil

    ## spawn the process and wait for the
    ## process to exit
    Timeout.timeout(timeout, Timeout::Error,
                    "Process timed out @ #{timeout} seconds: #{cmd.inspect}") {
      pid = Process.spawn(*cmd, options)
      pid, st = Process.wait2(pid)
    }

    if read_out ## the form to call on each stdout line
      out_write.close ## close before pipe read
      out_write = nil ## prevent later close
      out_read.each_line do |txt|
        read_out.call(txt)
      end
      out_read.close
      out_read = nil
    end

    if read_err ## the form to call on each stderr line
      err_write.close ## close before pipe read
      err_write = nil ## prevent later close
      err_read.each_line do |txt|
        read_err.call(txt)
      end
      err_read.close
      err_read = nil
    end

    return st.exitstatus

  ensure
    out_read && out_read.close
    out_write if out_write.is_a?(IO)
    err_read && err_read.close
    err_write.close if err_write.is_a?(IO)
  end
end


=begin

## Test - this block should show normal method
## behaviors for OutProc.run when evaluated

out = lambda { |txt| puts "Out: " + txt }
err = lambda { |txt| puts "Err: " + txt }

st = IOKit::OutProc.run("ls -d /etc /nonexistent",
     read_out: out, read_err: err)

=end

# Local Variables:
# fill-column: 65
# End:
