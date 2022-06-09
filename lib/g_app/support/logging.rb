## logging.rb - log utilities used in RIView

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

require('logger')
require('forwardable')

## Extension module for adding *log_*+ delegate methods as instance
## methods within an extending class.
##
## This module will define a class method +def_logger_delegate+. This
## class method may then be called within an extending class +c+,
## as to define a set of instance methods under +c+ that will dispatch
## to all of the local instance methods except +<<+ on +Logger+.
##
## Any of those delegating instance methods may be overridden, after the
## initial call to +def_logger_delegate+ in the extending class.
##
##
## @see LogManager, providing support for initialization of logger
##  storage within a class, and support for shadowing the *Kernel.warn*
##  method with s proc dispatching to an arbitrary *Logger*
##
module GApp::Support::LoggerDelegate

  def self.extended(extclass)
    extclass.extend Forwardable

    ## FIXME needs documentation (params)
    ##
    ## TBD YARD rendering for define_method in this context,
    ## beside the methods defined when the method defined here would be
    ## evaluated in an extending class.
    ##
    ## The delegate methods would not appear in any source definition for
    ## the delegating class, outside of the usage of this module.
    ##
    ## NB application must ensure that the instance variable is
    ## initialized with a Logger before any delegate method is
    ## called - see example under GBuilderApp#initialize
    ##
    ##
    ## *Syntax*
    ##
    ## +def_logger_delegate(instvar,prefix=:log_)+
    ##
    ## The +prefix+ parameter for *def_logger_delegate* provides a
    ## prefix name for each of the delegate methods, such that each
    ## delegate method will dispatch to a matching method on the logger
    ## denoted in the instance variable named in +instvar+. +prefix+ may
    ## be provided as a string or a symbol.
    ##
    ## The +instvar+ param should be a symbol, denoting an instance
    ## variable that will be initialized to a logger in instances of the
    ## extending class.
    ##
    ## In applications, the instance logger may be provided in reusing a
    ## logger stored in the extending class, such that may be managed
    ## within a class extending the *LogManager+ module. Within
    ## instances of the extending class, the instance variable denoted
    ## to +def_logger_delegate+ may then be initialized to the value of
    ## the class logger, such as within an +initialize+ method defined
    ## in the extending class.
    ##
    define_method(:def_logger_delegate) do | instvar, prefix=:log_ |
      use_prefix = prefix.to_s
      Logger.instance_methods(false).
        select { |elt| elt != :<< }.each do |m|
          extclass.
            def_instance_delegator(instvar,m,(use_prefix + m.to_s).to_sym)
        end
    end
  end
end


## Extension module providing internal storage for class-based logging
## and override of the method *Kernel.warn*
##
## This module defines the following methods, in an extending
## module or class +c+:
##
## - *+c.logger=+*
## - *+c.logger+*
##
## For purposes of generally class-focused log management, the methods
## +logger=+ and +logger+ will be defined in the extending class or
## extending method, as to access a logger that would be stored within
## the class definition. The class logger may or may not be equivalent
## to the logger provided to +manage_warnings+
##
## In an extending module +c+ the following methods are defined
## additionally:
## - *+c.make_warning_proc+*
## - *+c.manage_warnings+*
## - *+c.with_system_warn+*_warnings+*
## - *+c.use_logger+*, *+use_logger=+*
##
## The +manage_warnings+ method will define a method overriding the
## default *Kernel.warn* method, such that a top level call to +warn+
## will call the overriding method.
##
## This will not remove the definition of the orignial *Kernel.warn*
## method, such that be called directly as *Kernel.warn*
##
## The method +make_warning_proc+ will provide the *Proc* object to use
## for the overriding +warn+ method, such that will be defined in
## +manage_warnings+. By default, +make_warning_proc+ will return a
## +Lambda+ proc with a parameter signature equivalent to the the
## original +Kernel.warn+ in Ruby 3.0.0.
##
## If +make_warning_proc+ is overriden in the extending class before
## +manage_warnings+ is called, then the overriding method will be used
## in +manage_warnings+
##
## The method +with_system_warn+ accepts a block, such that the
## dispatching logger will not be called within that block. This method
## is provided as a utility towards ensuring that the dispatching logger
## will not be called within any ection of code that would not permit
## logging to an external logger, such as within a signal trap handler
## defined after a call to +manage_warnings+
##
## The methods +use_logger+ and +use_logger=+ may be used as to
## determine or to set the value of a state variable in the extending
## module, such that the proc form returned by +make_warning_proc+ will
## not use the provided logger when +use_logger+ returns a false
## value. This +proc+ would provide the implementation of the +warn+
## method implemented under +manage_warnings+
##
## * Known Limitations *
##
## In the behaviors of the call to +Warning.extend+, the method
## +manage_warnings+ may in effect override the initial +Kernel.warn+
## method, such that the initial +Kernel.warn+ method will not be called
## from within +with_system_warn+. Some system +warn+ method will be
## used for any +warn+ call within the block provided to
## +with_system_warn+, but the +warn+ method in use within that block
## may differ in its method signature and implementation, compared to
## the initial +Kernel.warn+ method.
##
## While it is known that an external logger should not be used within
## the block provided to a signal trap handler - thus towards a
## rationale for the definition of +with_system_warn+ - this may not be
## the only instance in which a block of code should be evaluated as to
## not use an external logger.
##
## The logger provided to +manage_warnings+ will not be stored
## internally, beyond how the logger is referenced within the proc
## returned by +make_warning_proc+_. It's assumed that the logger
## provided to +manage_warnings+ would be stored within some value
## in the extending class.
##
## @see *GBuilderApp*, providing an example of this module's application,
##  under instance-level integration with *LoggerDelegate* in a
##  class
##
## @see *LoggerDelegate*, providing instance methods via method
##  delegation, for logger access within application objects
##
## @see *Logger*, providing an API for arbitrary message logging in Ruby
##
## @see *LogModule*, which provides an extension of this module via
##  a module, such that may be suitable for extension onto the Ruby
##  *Warning* module
module GApp::Support::LogManager
  def self.extended(extender)

    def extender.logger=(logger)
      if @logger
        warn("@logger already bound to #{@logger} in #{self} " +
             "- ignoring #{logger.inspect}", uplevel: 0) unless @logger.eql?(logger)
        @logger
      else
        @logger = logger
      end
    end

    def extender.logger
      @logger # || warn("No logger defined in #{self.class} #{self}", uplevel: 0)
    end

    if extender.is_a?(Module)

      def extender.with_system_warn(&block)
        initial_state = self.use_logger
        begin
          self.use_logger = false
          block.call
        ensure
          self.use_logger = initial_state
        end
      end

      def use_logger()
        @use_logger
      end

      def use_logger=(p)
        @use_logger = !!p
      end

      def extender.make_warning_proc(logger)
        whence = self
        lambda { |*data, uplevel: 0, category: nil, **restargs|
          ## NB unlike with the standard Kernel.warn method ...
          ## - this proc will use a default uplevel = 0, as to ensure that some
          ##   caller info will generally be presented in the warning message
          ## - this proc will accept any warning category
          ## - this proc's behaviors will not differ based on the warning category
          ## - this proc will ensure that #to_s will be called directly on
          ##   every provided message datum
          if whence.use_logger
            ## NB during 'warn' this proc will be called in a scope where
            ## self == the Warning module, not the module to which the
            ## make_warning_proc method is applied in extension. Thus,
            ## the providing module may be referenced here as 'whence'
            nmsgs = data.length
            nomsg = nmsgs.zero?

            if category
              catpfx = '[' + category.to_s + '] '
            else
              catpfx = ''
            end

            if uplevel
              callerinfo = caller[uplevel]
              if nomsg
                firstmsg = catpfx + callerinfo
              else
                firstmsg = catpfx + callerinfo + ': '
              end
            else
              firstmsg = catpfx
            end

            unless nomsg
              firstmsg = firstmsg + data[0].to_s
            end

            whence.logger.warn(firstmsg)

            unless( nomsg || nmsgs == 1 )
              data[1...nmsgs].each { |datum|
                whence.logger.warn(catpfx + datum.to_s)
              }
            end
          else
            ## NB The 'super' method accessed from here may not have the
            ## same signature as the original Kernel.warn method, such
            ## that would accept an 'uplevel' arg not vailable to the
            ## 'super' method accessed from here
            super(*data, category: category, **restargs)
          end
          return nil
        }
      end

      def extender.manage_warnings(logger = self.logger)
        proc = make_warning_proc(logger)
        self.define_method(:warn, &proc)
        self.use_logger = true
        Warning.extend(self)
      end
    end # extender.is_a?(Module)
  end # self.extended
end # LogManager module


module GApp::Support::LogModule
  ## for Warning.extend(..) which will not accept a class as an arg
  ##
  ## e.g
  ## LogModule.logger = Logger.new(STDERR, level: Logger::DEBUG, progname: "some_app")
  ## LogModule.manage_warnings
  ## warn "PING"
  ##
  ## ... albeit it seems that something in either the Logger or Warning
  ## modules may be adding additional data to the message text, e.g
  ## "<internal:warning>:51:in `warn': "
  ##
  ## NB however: In some contexts when 'warn' may be called, it would
  ## not be valid to try to warn to a logger - e.g within signal trap blocks,
  ## in which context any warning may then loop in trying to emit a warning
  ## about the warning

  ## TBD @ <app>
  # GApp::Support::LogModule.logger ||= @logger
  # GApp::Support::LogModule.manage_warnings

  extend(GApp::Support::LogManager)

end

# Local Variables:
# fill-column: 65
# End:
