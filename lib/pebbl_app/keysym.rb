## PebblApp::Keysym module

require 'pebbl_app/gtk_framework'

module PebblApp

  require Const::GDK_FEATURE

  ## Utility methods for key codes used in Gdk
  ##
  ## @see PebblApp:;Keysym.key_code
  ## @see PebblApp::Keysym.modifier_mask
  ## @see Gdk::Keyval
  module Keysym

    class << self

      ## return an integer value for a named key code in Gdk
      ##
      ## This is a convenience method for operation on Gdk key code
      ## definitions in this module.
      ##
      ## The `key` argument may be provided as a string, symbol, or
      ## integer.
      ##
      ## If provided as a string or symbol, the string "Key_" will be
      ## added as a suiffix to the literal string representation of the
      ## provided key name. The resulting constant name must denote a
      ## constant in the module Keysym. If a matching constant is found,
      ## the integer value of that constant will be returned. Else, an
      ## ArgumentError will be raised.
      ##
      ## If provided as an integer, the value itself will be returned
      ##
      ## If provided as nil or false, the integer 0 will returned.
      ##
      ## @return [Integer] the 32-bit unsigned integer representation of
      ## the named key
      ##
      ## @see modifier_mask for computing the key modifier mask for a
      ## GTK accelerator definition, using a method of a similar syntax
      ## and semantics
      ##
      ## @see Gtk::Widget.add_accelerator
      ##
      ## @see PebblApp::AccelMixin
      def key_code(key)
        case key
        when String, Symbol
          name = ("KEY_" + key.to_s).to_sym
          if Gdk::Keyval.const_defined?(name)
            return Gdk::Keyval.const_get(name)
          else
            raise ArgumentError.new("Key not found: #{key}")
          end
        when Integer
          return key
        else
          raise ArgumentError.new("Unable to parse key name: #{key}")
        end
      end

      ## return an integer value for a named key modifier mask
      ##
      ## This is a convenience method for operation on Gdk::ModifierType
      ## values, producing an integer return value.
      ##
      ## The `mask` argument may be provided as a string, symbol,
      ## Gdk::ModifierType, integer, an array of any value of the
      ## previous types, or either of the literal values nil or false.
      ##
      ## If an array, the integer return value will provide a bitwise
      ## 'or' mask for the set of modifier keys named in the array.
      ##
      ## If provided as a string or symbol, the string "_MASK" will be
      ## added as a suffix to the uppcased string representation of the
      ## provided mask. The resulting name must denote a constant in the
      ## module Gdk::ModifierType. If a matching constant is found, the
      ## integer value of that constant will be returned. Else, an
      ## ArgumentError will be raised.
      ##
      ## If provided as a Gdk::ModifierType, the integer value of that
      ## modifier type will be returned.
      ##
      ## If provided as an integer, the value itself will be returned.
      ##
      ## If provided as nil or false, the integer 0 will returned.
      ##
      ## Examples
      ## ~~~~
      ## PebblApp::Keysym.modifier_mask([:mod1, :control])
      ## => 12
      ##
      ## PebblApp::Keysym.modifier_mask("MOD1")
      ## => 8
      ##
      ## PebblApp::Keysym.modifier_mask(:control)
      ## => 4
      ##
      ## PebblApp::Keysym.modifier_mask(false)
      ## => 0
      ##
      ## PebblApp::Keysym.modifier_mask(12)
      ## => 12
      ## ~~~~
      ##
      ## @return [Integer] the bitwise numeric representation of the
      ##  modifier mask
      ##
      ## @see key_code for computing a numeric key code of a named key
      def modifier_mask(mask)
        case mask
        when NilClass, FalseClass
          return 0
        when String, Symbol
          name = mask.to_s.upcase + "_MASK"
          if Gdk::ModifierType.const_defined?(name)
            return Gdk::ModifierType.const_get(name).to_i
          else
            raise ArgumentError.new("Modifier not found: #{name}")
          end
        when Gdk::ModifierType
          return mask.to_i
        when Integer
          return mask
        when Array
          value = 0
          mask.each do |key|
            value = modifier_mask(key) | value
          end
          return value
        else
          raise ArgumentError.new("Unable to parse modifier name: #{mask}")
        end
      end

      ## Return a string label for a key accelerator, using the
      ## provided key and modifier values.
      ##
      ## The return value will be in a syntax similar to the value
      ## returned by **Gtk.accelerator_get_label**.
      ##
      ## With PebblApp::Keysym::key_label the label for the provided
      ## key will be returned in a case appropriate for the actual
      ## key, e.g "n" rather than "N"  for Gdk::Keyval::KEY_n, as
      ## distinct to "N" for Gdk::Keyval::KEY_N. This may be distinct to
      ## the common menu representation of accelerators in GTK.
      ##
      ## The key code and any modifier names provided to this method may
      ## each be provided in a syntax as accepted respectively by the
      ## PebblApp::Keysym::key_code and PebblApp::Keysym::modifier_mask
      ## methods. These methods will each accept an integer, string, or
      ## symbolic representation of a key code or a modifier name,
      ## respectively.
      ##
      ## @param key [Object] Key name in a syntax accepted by key_code
      ##
      ## @param modifiers [Array] Modifier names, each in a syntax
      ##  accepted by modifier_mask
      ##
      ## @return [String] a key accelerator label
      def key_label(key, *modifiers)
        code = key_code(key)
        key_name = Gtk.accelerator_name(code, 0)
        ## ^ FIXME opposite to Gtk.accelerator_get_label, accelerator_name
        ##   simply returns the downcase representation of the key code
        if modifiers.empty?
          return key_name
        else
          name_uc = key_name.upcase
          mask = modifier_mask(modifiers)
          g_label = Gtk.accelerator_get_label(code, mask)
          g_label.split("+".freeze).map { |label|
            if label == name_uc
              key_name
            else
              label
            end
          }.join ("+".freeze)
        end
      end

    end ## class << Keysym
  end ## Keysym
end ## PebblApp
