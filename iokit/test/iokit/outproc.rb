
require('iokit/outproc') ## the library to test

describe IOKit::OutProc do
  ## NB this assumes that an 'echo' command is available on the host
  ## and is in the PATH for the rspec environment

  it "runs echo" do
    echo_cmd = %w{echo true}
    str = ""
    parse_out = lambda { |line| str = line }
    st_exit = IOKit::OutProc.run(*echo_cmd, read_out: parse_out)
    expect(st_exit).to be == 0
    expect(str.length). to be >= 4
    expect(str[0...4]).to be == "true"
  end
end


# Local Variables:
# fill-column: 65
# End:

