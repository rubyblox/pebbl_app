## dataproxy.rb - prototype for user data handling in GTK

BEGIN {
  ## When loaded from a gem, this file may be autoloaded

  ## Ensure that the module is defined when loaded individually
  require(__dir__ + ".rb")
}


class DataProxy < GLib::Object # < GLib::Boxed
  extend GAppKit::GTypeExt
  self.register ## register the type, exactly once

  ## FIXME this does not create or use any data_changed property
  ## but should, or this may only be suitable for read-only data access
  ## in a Ruby application (FIXME not yet tested with Ruby GTK bindings)

  ## TBD
  # install_property(GLib::Param::Object.new("data_changed","DataChanged","user data changed",???,???))

  attr_accessor :data
  def initialize(data)
    super()
    @data = data
  end
end

# Local Variables:
# fill-column: 65
# End:
