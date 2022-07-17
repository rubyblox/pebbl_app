module PebblApp

  ## Mixin module for convenient key accelerator definition
  ##
  ## This mixin module may be used by way of `include`.
  ##
  ## When included, the following methods will be defined within an
  ## instance scope in the including class:
  ##
  ## - map_accel_path: Define a GTK accel path for one or more
  ##   key/modifier combinations, activating a widget on input of the
  ##   corresponding keyes.
  ##
  ## @see Keysym.key_code
  ## @see Keysym.modifier_mask
  module AccelMixin

    ## Define a GTK accel path for one or more key/modifier
    ## combinations, activating a widget on input of the
    ## corresponding keys.
    ##
    ## Example:
    ##
    ## ~~~~
    ## class Example < Gtk::Window
    ##   type_register
    ##
    ##   include PebblApp::AccelMixin
    ##
    ##   def initialize()
    ##
    ##     ## Creating new model buttons locally, for illustration.
    ##     ##
    ##     ## In a more comprehensive example, if this class was
    ##     ## defined instead as a composite widget class for some UI
    ##     ## template file, then each of these model buttons could be
    ##     ## initialized automatically as a template child object
    ##     ## within the implementation of the template.
    ##     ##
    ##     ## See also: PebblApp::FileCompositeMixin
    ##     send = Gtk::ModelButton.new()
    ##     send.label = "Send"
    ##
    ##     @accel_map_group =
    ##       map_accel_path(:Return, "<Example>/App Input/Send",
    ##                      receiver: send)
    ##
    ##     alt_send = Gtk::ModelButton.new()
    ##     alt_send.label = "Send Other"
    ##
    ##     map_accel_path(%i(Return mod1), "<Example>/App Input/Alt Send",
    ##                    receiver: alt_send, group: @accel_map_group)
    ##
    ##     ## Beyond the scope of this illustration:
    ##     ## - binding an action name, action, and action callback for
    ##     ##   each model button
    ##     ## - adding each model button to the widget tree for the window
    ##   end    ## end
    ## ~~~~
    ##
    ## @see Gtk::AccelMap.save
    ##
    ## @see Gtk::AccelMap.load
    ##
    ## @param keys [key expresion] Supported syntax: `Key`, or an array
    ##  providing one set of `[Key, Modifier]` values, or a Hash of `Key
    ##  => Modifier` values such that the `path` will be bound for every
    ##  Key/Modifier group in the provided hash.  Each `Key` provided
    ##  will be resolved to a key code, using PebblApp::Keysym.key_code.
    ##  Each `Modifier` provided will be resolved to an integer value,
    ##  using PebblApp::Keysym.modifier_mask. To omit a modifier in
    ##  either of the Array or Hash syntaxes, the `Modifier` value may
    ##  be provided as any one of the values `nil`, `false`, or `0` i.e
    ##  the integer zero.
    ##
    ## @param path [String] The GTK accel path for the binding. This
    ##  parameter's syntax is illustrated in the GTK reference manual,
    ##  under the heading, _Accelerator Maps_
    ##
    ## @param scope [Gtk:::Window or nil] The window to receive any new
    ##  Gtk::AccelGroup when `group` is nil. If nil, the scoped instance
    ##  of the implementing class will be used. This paramter is unused
    ## if a `group` is provided,
    ##
    ## @param receiver [Gtk::Widget or nil] Widget to be activated for the
    ##  provided accel path and keys. If nil, the accel path will be
    ##  configured to activate the scoped instance of the class
    ##  implementing this method. The receiver's class must implement a
    ##  Gtk `activate` signal.
    ##
    ## @param group [Gtk::AccelGroup or nil] Gtk::AccelGroup for binding
    ##  the accel path, or nil. If nil, a new Gtk::AccelGroup will be
    ##  created for the inferred scope, then that new AccelGroup will be
    ##  added to the scope. If provided as a Gtk::AccelGroup, then
    ##  that AccelGroup will be used for binding the accel path. In
    ##  either instance, the Gtk::AccelGroup used for the binding will
    ##  be returned.
    ##
    ## @param locked [boolean] If a truthy value, the accel path will be
    ## locked after creation. Once the accel path is locked, the key
    ## binding for the accel path cannot be modified during runtime
    ## until the path is unlocked an equivalent number of times. See
    ## Gtk::AccelMap.unlock_path and in the GTK reference documentation,
    ## gtk_accel_map_lock_path
    ##
    ## @return [Gtk::AccelGroup] The accel group used for the binding,
    ##  whether provided as a parameter or created and bound to a scope
    ##  within this method
    ##
    ## @see Description of _Accelerator Maps_ in the GTK+ 3 Reference Manual,
    ##  also avaialble in GNOME Devhelp
    ##  https://developer-old.gnome.org/gtk3/3.24/gtk3-Accelerator-Maps.html#gtk3-Accelerator-Maps.description
    ##
    def map_accel_path(keys, path, scope: nil, receiver: nil,
                       group: nil, locked: false)
      if ! String === path
        raise ArgumentError.new("Invalid accel path: #{path.inspect}")
      end
      if ! group
        scope = self if ! scope
        group = Gtk::AccelGroup.new
        scope.add_accel_group(group)
      end
      receiver = self if ! receiver
      if ! Gtk::Widget === receiver
        raise ArgumentError.new("Receiver is not a Gtk::Widget: #{receiver.inspect}")
      elsif ! receiver.class.signals.include?("activate".freeze)
        ## this will fail early, while Gtk may emit a critical message
        ## later, then discarding the key event that activated the accel
        raise ArgumentError.new(
          "Class of receiving widget does not implement an activate signal: #{receiver.inspect}"
        )
      end
      key = false
      mod = -1
      case keys
      when Array
        key = keys[0]
        mod = keys[1...]
      when Hash
        keys.each do |key, mod|
          map_accel_path [key, mod], path, scope: scope,
            receiver: receiver, group: group, locked: locked
        end
      else
        key = keys
        mod = 0
      end
      ## parse the provided key, modifier symbols
      key = Keysym.key_code(key)
      mod = Keysym.modifier_mask(mod)
      ## define the accel path
      Gtk::AccelMap.add_entry(path, key, mod)
      ## bind the accel path
      receiver.set_accel_path(path, group)
      ## lock the accel path, if locked
      Gtk::AccelMap.lock_path(path) if locked
      return group
    end
  end ## AccelMixin
end ## PebblApp namespace
