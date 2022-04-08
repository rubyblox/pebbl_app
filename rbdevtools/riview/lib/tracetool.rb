## tracetool.rb - utility forms for TracePoint utilization

require 'rdoc' ## ...

class TraceTool
  DEFAULT_IGNORE_EXCEPTIONS=[RDoc::Store::MissingFileError,
                             ## ^ FIXME why this file will require 'rdoc'
                             RubyLex::TerminateLineInput,
                             SyntaxError]

  def self.make_raise_tracepoint(ignore_exceptions = DEFAULT_IGNORE_EXCEPTIONS)
    ign_exc = ignore_exceptions.dup
    block = lambda { |pt|
      pt_exc = pt.raised_exception
      unless (ign_exc.member?(pt_exc.class))
        ## FIXME this is crudely parameterized
        ## FIXME define an alternate lambda calling any provided block on pt,
        puts("[debug] %s %s [%s] @ %s:%s" %
             [pt.event, pt_exc.inspect,
              pt_exc.message, pt.path, pt.lineno])
      end
    }
    TracePoint.new(:raise, &block)
  end
end
