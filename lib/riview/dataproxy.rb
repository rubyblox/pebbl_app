## dataproxy.rb - prototype for user data handling in GTK

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}

## Storage for arbitrary user data
##
## This class defines a GLib property, +data-id+ and a
## corresponding GLib signal, +data_changed. During object
## initialization and in the method +data=+, the +data_changed+
## signal will be emitted on the affected object. The signal will
## result in a call to the method +signal_do_data_changed+, on
## the same object.
##
## The method +signal_do_data_changed+ may be overridden
## in subclasses. For effective integration with GTK, any
## subclass overriding that method should call the method
## +type_register+ on the class, during class definition.
##
## The method *+signal_do_data_changed+* will be called in the
## instance, before any callbacks bound via +signal_connect+ on
## the +data_changed+ signal for the instance.
##
## In a glib or GTK application, the +data_changed+ signal should
## be emitted on any object of this class, subsequent of any call
## that has modified the value of the 'data-id' property on the
## object.
##
## In this class' default implementation, the +data-id+ property
## will be updated during a call to the *+data=+* method defined
## in this class, such that the updated +data-id+ value value
## will store the value of +object.object_id+ for the +object+
## provided to the *+data=+* call. The +data_changed+ signal will
## then be emitted on the object, after both the stored object
## reference and object ID have been updated.
##
## For purposes of state monitoring in applications, the
## +data_changed+ signal may be bound to a signal callback
## defined on an instance of this class.
##
## Applications may call +signal_connect+ on an instance of this
## class, providing the signal name +"data_changed"+. The block
## provided in the callback will then be evaluated when the
## +data_changed+ signal is emitted on the object. The initial
## object stored via *+data=+*  may then be retrieved either with
## the *+data+* reader method on the instance, or with the
## following call:
## +ObjectSpace._id2ref(instance.get_property("data-id"))+
##
## *Known Limitations*
##
## - This class provides no internal locking for read or write
##   access to the +data-id+ property or +data+ value from threads
##   external to the thread in which the instance has been
##   initialized.
##
## - Though type-compatible with GLib property and signal
##   definitions, the +data_id+ attribute may appear redundant for
##   internal access to the +data+ value.
##
class DataProxy < GLib::Object # < GLib::Boxed
  extend PebblApp::GtkFramework::GObjType
  self.register_type ## register the type, exactly once

  ## NB - documentation
  ## - example @ Ruby-GNOME glib2:test/test-signal.rb
  ## - the define_signal method signature is described in
  ##   Ruby-GNOME glib2:sample/type-register2.rb

  ## NB defined only once
  ## using a 'void' return type
  ## and no parameters for the data_changed signal
  @data_changed_signal ||=
    define_signal("data_changed", GLib::Signal::RUN_FIRST, nil,
                  GLib::Type["void"])

  if ! @data_property
    ## Define a property for object_id value storage,
    ## such that this form will be evaluated exactly once
    ##
    ## NB documentation
    ## - GParamSpec devhelp
    ## - Ruby-GNOME glib2:sample/type-register2.rb
    install_property(GLib::Param::Int64.
                       new("data-id", "Data ID", "ID of user data",
                           ## minimum value
                           GLib::MININT64,
                           ## maximum value
                           GLib::MAXINT64,
                           ## initial value => false, as a ref
                           0,
                           ## property flags
                           (GLib::Param::READABLE | GLib::Param::WRITABLE)))
    @data_property = true
  end

  def initialize(data = false)
    ## NB false.object_id => 0
    super()
    self.data = data
  end

  def signal_do_data_changed()
    ## NB has to be defined for Ruby-GNOME self.signal_emit("data_changed")
    ##
    ## FIXME this method should be defined at most once, in the
    ## calling process - this method's definition appears to
    ## correspond to a call into the glib API
    ##
    ## NB this method's signature should match the signal
    ## parameters specified to define_signal("data_changed", ...)
  end

  def data=(value)
    ## NB this instance should hold a ref to the latest value
    ## object, to prevent GC of the object
    @data = value
    self.set_property("data-id", value.object_id)
    self.signal_emit("data-changed")
  end

  def data()
    ## NB this could ...
    # ObjectSpace._id2ref(self.get_property("data-id"))
    ##
    ## Alternately, while a reference to the data object is
    ## already stored in this object, this method can return the
    ## object directly
    @data
  end

  protected

  def data_id=(id)
    ## NB a method with this name has to be defined in the
    ## implementation, onto Ruby-GNOME set_property("data-id",..)
    @data_id = id
  end

  def data_id
    ## NB a method with this name has to be defined in the
    ## implementation, onto Ruby-GNOME get_property("data-id")
    @data_id
  end

end

=begin Example

class OtherProxy < DataProxy
  extend PebblApp::GtkFramework::GObjType
  self.register_type

  def signal_do_data_changed()
    puts "Data Changed to #{data}"
  end
end

prx = OtherProxy.new("Initial Data")

prx.signal_connect("data_changed") {
 puts "Handling data change"
}

prx.data="New data"


=end

# Local Variables:
# fill-column: 65
# End:
