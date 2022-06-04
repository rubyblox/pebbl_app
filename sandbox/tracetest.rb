## tracetest.rb - testing for a TracePoint onto :raise

require 'rdoc'

$TRACE = TracePoint.new(:raise) do |pt|

  ## debug for most fields of the 'raise' tracepoint pt here
  mtds  = [:event, :method_id, :callee_id, :defined_class,
                   :raised_exception, :binding, :path, :lineno];
  fields = {}
  mtds.map { |m|
    fields[m] = pt.send(m)
  };

  ## TBD how to make use of the defined_class field on a TracePoint.
  ##
  ## a #<Class:RubyVM::InstructionSequence> ...
  ## - is apparently a Class
  ## - may commonly have a name of 'nil'

  $DBG = fields

  pt_exc = pt.raised_exception
  pt_path = pt.path
  ign_exc = [RDoc::Store::MissingFileError,
             RubyLex::TerminateLineInput,
             SyntaxError]
  unless (ign_exc.member?(pt_exc.class))
    puts("[debug] %s %s [%s] @ %s:%s" %
         [pt.event, pt_exc.class,
          pt_exc.message,
          pt_path, pt.lineno])
  end

end

$TRACE.enable
