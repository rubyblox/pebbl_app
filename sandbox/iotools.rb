## iotools.rb (sandbox) --- catch-bin for I/O utility forms

## local utility function for e.g 'git config'
def self.sh_eval(cmd)
  ## FIXME too trivial.
  ## Catch any non-zero exit code and raise error if occurs
  out = IO.read("|#{cmd}").chomp
  if out.length.eql? 0
    return nil
  else
    return out
  end
end


def self.read_until(io, match: $/)
  chars = ""
  matchproc = case match
              when String
                ## FIXME this is a cheap parse and only works for a
                ## string of exactly one character length
                proc { |c| c == match}
              when Regexp
                proc { |c| match.match?(c) }
              when Proc
                match
              else
                raise new "Uknown match syntax; #{match.inspect}"
              end
  c = true
  while c do
    begin
      c = io.readchar
    rescue EOFError
      c = nil
    end
    if matchproc.call(c)
      c = nil
    else
      chars.concat(c)
    end
  end
  chars
end

def self.read_file_until(f, match: $/)
  File.open(f) do |io|
    return read_until(io, match: match)
  end
end
