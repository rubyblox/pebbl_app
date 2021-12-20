## zcmdproto

require('./ioproc')

## TBD usage w/i ./zmulti-cmd.rb

class CmdFailed < RuntimeError
  attr_reader :cmd ## string
  attr_reader :exit_code ## unsigned integer
  attr_reader :error_text ## string or nil
  attr_reader :output ## nil or array or ... (FIXME limited onto SimpleDataCmd::run call/return syntax)

  def initialize(cmd,exit_code,error_text,output = nil,
                 message = "Shell command failed (#{exit_code}): #{cmd} => [#{error_text}]")
    super(message)
    @cmd = cmd
    @exit_code = exit_code
    @error_text = error_text
    @output = output ## NB discarded from the message text. typically nil
  end
end

class SimpleDataCmd < IOKit::OutProc

    def self.parse_stdout_form(whence)
      lambda { |line| whence.append line.split }
    end

    def self.parse_stderr_form(whence)
      lambda { |line| whence.append line}
    end

    def self.run(*cmd, ignore_errors: false, ignore_output: false, options: nil)
      out_data = ignore_output ? nil : []
      err_data = ignore_errors ? nil : []

      exit_code = IOKit::OutProc.run(*cmd,
                                      read_out: ignore_output ? nil : self.parse_stdout_form(out_data),
                                      read_err: ignore_errors ? nil : self.parse_stderr_form(err_data),
                                      options: options)

      if ( exit_code == 0 )
        ## really straightforward, and maybe more portable than shell scripts ...
        if ignore_output
          return true ## true when ignore_output
        else
          return out_data.length == 0 ? nil : out_data ## nil (output requested, none found) or array of tokenized lines
        end
      elsif ignore_errors
        return exit_code ## non-zero unsigned int
      else
        ## amd this branch does not return locally
        err_str = err_data.length == 0 ? nil : err_data.join("\n").chomp
        raise CmdFailed.new(cmd, exit_code, err_str,
                            ( ignore_output || out_data.length == 0 ) ? nil : out_data)
      end

    end

end

=begin

cmd =  %w{zpool list -pH -o name,health}
data = SimpleDataCmd.run(*cmd)

## alternately ..
health0 = SimpleDataCmd.run('zpool list -pH -o name,health')[0][1]

## or ...

pool = 'test-rpool'
data = SimpleDataCmd.run "zpool list -pH -o name,health #{pool}"

## and for a fail test .. ignoring errors momentarily ..

pool = 'not-pool'
data = SimpleDataCmd.run("zpool list -pH -o name,health #{pool}", true)
## whence data == 1

## NB *will* need to parse the "health" part of that output, in the API ..

## TBD

data = SimpleDataCmd.run([["ls" "ls] "-d" "/etc"])

=end


class FrobCmd < IOKit::OutProc
  def self.runsudo(cmd)
    run "/bin/TBD"
  end
end

# Local Variables:
# fill-column: 65
# End:
