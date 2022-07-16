
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
  ## @see GdkKeys.key_code
  ## @see GdkKeys.modifier_mask
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
    ##                      to: send)
    ##
    ##     alt_send = Gtk::ModelButton.new()
    ##     alt_send.label = "Send Other"
    ##
    ##     map_accel_path(%i(Return mod1), "<Example>/App Input/Alt Send",
    ##                    to: alt_send, group: @accel_map_group)
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
    ## @param keys [key expresion] This parameter's syntax will need
    ## illustration (FIXME). Supported types: Key, or a Hash of Key =>
    ## Modifier values. Each key provided will be resolved to a key
    ## code, using PebblApp::GdkKeys.key_code. Each modifier provided
    ## will be resolved with PebblApp::GdkKeys.modifier_mask
    ##
    ## @param path [String] the GTK accel path for the binding. This
    ##  parameter's syntax will need illustration (FIXME)
    ##
    ## @param to [Gtk::Widget or nil] Widget to be activated for the
    ##  provided accel path. If nil, the accel path will be configured
    ##  as to activate the scoped instance of the class implementing
    ##  this method
    ##
    ## @param group [Gtk::AccelGroup or nil] Gtk::AccelGroup for binding
    ##  the accel path, or nil. If nil, a new Gtk::AccelGroup will be
    ##  created for the scoped instance of the class implementing this
    ##  method, then that new AccelGroup will be added to the scoped
    ##  instance. In this case, the implementing class should be a
    ##  subclass of Gtk::Window. If provided as a Gtk::AccelGroup, then
    ##  that AccelGroup will be used for binding the accel path, without
    ##  further modification on any existing Gtk::Window definitions. In
    ##  either instance, the Gtk::AccelGroup used for the binding will
    ##  be returned.
    ##
    ## @return [Gtk::AccelGroup] The accel group used for the binding,
    ##  whether provided as a parameter or created within this method
    def map_accel_path(keys, path, to: nil, group: nil)
      if ! String === path
        raise ArgumentError.new("Invalid accel path: #{path.inspect}")
      end
      if ! group
        group = Gtk::AccelGroup.new
        self.add_accel_group(group)
      end
      window = self if ! window
      to = self if ! to
      mod = 0
      case keys
      when Array
        key = keys[0]
        mod = keys[1...]
      when Hash
        keys.each do |key, mod|
          map_accel_path [key, mod], path, to: to, group: group
        end
      else
        key = keys
        mod = 0
      end
      key = GdkKeys.key_code(key)
      mod = GdkKeys.modifier_mask(mod)
      Gtk::AccelMap.add_entry(path, key, mod)
      to.set_accel_path(path, group)
      return group
    end


  end ## AccelMixin
end ## PebblApp namespace
