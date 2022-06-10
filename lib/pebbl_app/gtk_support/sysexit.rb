## syexit.rb - cf. FreeBSD sysexits(3)

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

module GApp::Support::SysExit
  EX_OK = 0

  EX_USAGE	= 0x40
  EX_DATAERR	= 0x41
  EX_NOINPUT	= 0x42
  EX_NOUSER	= 0x43
  EX_NOHOST	= 0x44
  EX_UNAVAILABLE= 0x45
  EX_SOFTWARE	= 0x46
  EX_OSERR	= 0x47
  EX_OSFILE	= 0x48
  EX_CANTCREAT	= 0x49
  EX_IOERR	= 0x4A
  EX_TEMPFAIL	= 0x4B
  EX_PROTOCOL	= 0x4C
  EX_NOPERM	= 0x4D
  EX_CONFIG	= 0x4E

  def self.ex_code(name)
    case name
    when Integer
      return name
    when String
      folded = name.upcase
      if folded.match?(/^EX_/)
        self.const_get(folded)
      else
        self.const_get(("EX_" + folded).to_sym)
      end
    when Symbol
      self.ex_code(name.to_s)
    else
      -1
    end
  end

  def self.exit(exclass = EX_OK)
    ## NB this would skip any interactive 'exit' e.g in IRB
    ##
    ## NB at least on Linux:
    ## - any exit code greater than 255 will cause the Ruby process to
    ##   exit with code '0'.
    ## - any exit code less than 0 will cause the Ruby process to exit
    ##   with code '255'
    ##
    Kernel.exit(self.ex_code(exclass))
  end
end
