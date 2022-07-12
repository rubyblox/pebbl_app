

require 'pebbl_app/gtk_app'

require 'pango'

module PebblApp

  module Util
    class << self
      def freeze_array(ary)
        ary.tap { |elt| elt.freeze }.freeze
      end
      ## nb Gdk::RGBA.parse(parse)

      def inspect_property(property, widget, &block)
        value = widget.get_property(property)
        block.yield(value, property, widget)
      end


      def inspect_properties(widget, &block)
        widget.class.properties.each do |p|
          param = widget.class.property(p)
          if param.readable?
            inspect_property(p, widget, &block)
          end
        end
      end
    end
  end


  module StringLabelMixin
    def self.included(whence)
      whence.extend GUserObject
      whence.register_type
      whence.install_property(GLib::Param::String.new(
        "label-string".freeze, ## param name
        "Label String".freeze, ## param nick
        "String label for an object".freeze, ## param blurb
        "(Unknown)".freeze, ## param default
        ## flags:
        GLib::Param::READABLE | GLib::Param::WRITABLE))

      def label_string()
        @label_string
      end

      def label_string=(value)
        @label_string = value
        notify("label-string".freeze)
      end
    end
  end


  ## Contsants for properties used in this UI
  module FontConst
    ## Properties for text tags
    ##
    ## Each of these has a value property of the provided name and a
    ## boolean <name>-set property in GtkTextTag
    #
    ## The following properties are not known to be represented in
    ## Gtk::CellRendererText, though implemented in Gtk::TextTag
    ## - `pixels-above-lines`, `pixels-below-lines`, `pixels-inside-wrap`
    ## - `indent`, `left-margin`, `right-margin`
    ## - `letter-spacing`, `background-full-height`
    ##
    ## The following properties of Gtk::TextTag have not been
    ## implemented in this release of the font configuration UI:
    ## - editable
    ## - scale
    TAG_SET_PROPS ||=
      Util.freeze_array %w(background-full-height
                           family indent justification left-margin
                           letter-spacing pixels-above-lines
                           pixels-below-lines pixels-inside-wrap
                           right-margin rise size stretch
                           strikethrough style underline variant
                           weight wrap-mode)

    ## Color properties for text tags
    ##
    ## The following properties are not known to be represented in
    ## Gtk::CellRendererText, though implemented in Gtk::TextTag
    ##  - `underlinne-rgba`
    ##  - `paragraph-background-rgba`
    ##  - `strikethrough-rgba
    ##
    TAG_RGBA_PROPS ||=
      Util.freeze_array %w(background foreground strikethrough
                           underline paragraph-background
                          ).map { |name| name + "-rgba" }

    ## Properties for text tags that do not have a <name>-set property
    ##
    ## The `accumulative-margin` property it not known to be represented
    ## in Gtk::CellRendererText, though implemented in Gtk::TextTag
    ##
    ## The following properties of Gtk::TextTag and PebblApp::FontDef
    ## have not been implemented in this release of the font
    ## configuration UI:
    ## - `name` as in the programatic name of a Gtk::TexTag or FontDef
    ## - `label-string` as for a user-visible label of a FontDef
    ##
    TAG_OTHER_PROPS ||=
      Util.freeze_array %w(accumulative-margin)


    ## Cumulative mapping (TAG_SET_PROPS, TAG_OTHER_PROPS, TAG_RGBA_PROPS)
    ##
    ## This constant is used as an array of configuration properties in
    ## the TextableFontPrefs implementation.
    TAG_ALL ||=
      TAG_SET_PROPS.dup.concat(
        TAG_RGBA_PROPS.dup.concat(TAG_OTHER_PROPS.dup)
      ).freeze

  end

  ## Font definition for a GTK text view, defined after a style of Emacs
  ## custom faces.
  ##
  ## As extending Gtk::TexTag, FontDef is generally compatible with
  ## Pango font definitions.
  ##
  ## @see FontScheme
  class FontDef < Gtk::TextTag
    self.include StringLabelMixin

    ## a user-visible name for this FontDef
    #alias :name :label_string ## ???

    ## inheritance information for this FontDef
    attr_accessor :inherits

    class << self
      def properties_intersect(a, b)
        a.class.properies.intersection(b.class.properties)
      end

      def from_text_tag(tag)
        ## stub method
        ##
        ## copy properties from the tag to a new FontDef
      end

      def from_yaml_map(map)
        ##stub method
        ##
        ## initialize a new FontDef object from data previous
        ## deserialized from a YAML stream or YAML file
      end

    end



    ## return a new hash value for a YAML a encoding of a FontDef
    def to_yaml_map(defn, props = self.class.properties)
      ## stub method
      ##
    end

    ## initialize a new/provided TextTag from this FontDef, for an array
    ## of properties
    ##
    ## If a block is provided, two arguments will be yielded to the
    ## block for each property transferred to the receiving object:
    ## The value for that property in this object, and the name of the
    ## property being transferred. The return value from the block will
    ## then be stored as that property's value for the receiving object.
    ##
    ## The block may ensure that any transformation is performed, e.g
    ## duplication, for any value in the the originating FontDef.
    def copy(to = new, props = FontDef.properties_intersect(to, self), &block)
      props.each do |prop|
        val = self.get_property(prop)
        if block_given?
          recv = block.yield(val, prop)
        else
          recv = val
        end
        to.set_property(prop, recv)
      end
    end

  end ## FontDef

  ## Font map for a GTK text view, after a style of Emacs custom groups
  ##
  ## @see FontDef
  class FontScheme < Gtk::TextTagTable
    self.extend StringLabelMixin

    class << self
      ## encoding, decoding, import, export ...
    end ## class << FontScheme
  end

  module TreeUtils
    class << self
      ## @param model [Gtk::ListStore, Gtk::TreeStore]
      def clear_tree_store(model)
        while data = model.first
          ## second element is a path for the first model row (unused here)
          store = data[0]
          iter = data[2]
          store.remove(iter)
        end
        return model
      end
      ## remove all cell renderers from a Gtk::TreeView
      ##
      ## @param view [Gtk::TreeView}
      ##
      ## @param capture_p [boolean] if true, return an array of cell
      ##  renderers removed
      ##
      ## @return [Array<Gtk::CellRenderer>, boolean] if capture_p, the cell
      ##  renderers removed. Else, true if cell renderers were removed.
      ##  In either case, false if no cell renderers were removed.
      def clear_tree_renderers(view, capture_p = false)
        n = view.n_columns - 1
        ret = capture_p ? [] : false
        until (n == -1)
          if col = view.get_column(n)
            if capture_p
              ret.push(col)
            else
              ret = true
            end
            view.remove_column(col)
            n = n - 1
          end
        end
        if (capture_p ? ret.empty? : !ret)
          return false
        else
          return ret
        end
      end

    end ## class << TreeUtils

  end ## TreeUtils


  class TextableFontPrefs < Gtk::Dialog
    extend PebblApp::FileCompositeWidget
    use_template(File.expand_path("../ui/textable.font.ui", __dir__),
                 ## ... map template elements ...
                 %w(fonts_store fonts_tree inherit_store inherit_tree
                    fonts_menu
                    preview_buffer tag_sample
                   ))

    ## bind property widgets (acessed directly, no method binding)
    FontConst::TAG_ALL.each do |prop|
      field = prop.gsub("-", "_")
      model = "map_" + field ## model button
      chk = "enabled_" + field ## check box
      bind_template_child_full(model, true, 0)
      bind_template_child_full(chk, true, 0)


      if ! (prop == "accumulative-margin".freeze ||
            prop == "background-full-height".freeze)
        ## ^ no widget for these properties, outside of the model button
        wdgt = "font_" + field
        bind_template_child_full(wdgt, true, 0)
      end
    end

    include PebblApp::DialogMixin


    attr_reader :font_scheme

    def initialize
      super
      ## clear table views and cell renderers inherited from the template
      TreeUtils.clear_tree_store(fonts_store)
      TreeUtils.clear_tree_renderers(fonts_tree)
      TreeUtils.clear_tree_store(inherit_store)
      TreeUtils.clear_tree_renderers(inherit_tree)


      bld = self.class.composite_builder

      checkboxes = Hash.new
      ## ^ lexically scoped storage, used in two callbacks defined
      ## with the following block

      FontConst::TAG_ALL.map do |prop|
        ## configure an action to toggle widget states for the property
        ## and set the sample's property when active. The action will be
        ## in effect activated on a checkbox widget for the property's
        ## configuration
        suffix = "_" + prop.gsub("-","_")
        checkbox_id = "enabled" + suffix
        if checkbox = self.get_internal_child(bld, checkbox_id)
          checkboxes[prop] = checkbox
        else
          raise "checkbox widget not found: #{prop} => #{checkbox_id}"
        end
        lbl_id = "map" + suffix
        if ! lbl = self.get_internal_child(bld, lbl_id)
          raise "label widget not found: #{prop} => #{lbl_id}"
        end

        widget_id = "font" + suffix
        ## 'widget' here may be null for two of the properties, each of
        ## which has no value widget - a boolean property
        if widget = self.get_internal_child(bld, widget_id)
          if (prop == "strikethrough-rgba".freeze) ||
              (prop == "underline-rgba".freeze)
            idx = (prop =~ /-rgba$/)
            related = prop[...idx]
          else
            related = false
          end
          callback = proc {
            ## activated after a change in state in the checkbox widget
            if checkbox.active?
              if related
                ## this will activate the checkcbox for e.g "underline"
                ## when the checkbox for "underline-rgba" is activated
                related_chk = checkboxes[related]
                related_chk.active = true
              end
              handle_widget_property_active(prop, widget, lbl)
            else
              handle_widget_property_inactive(prop, widget, lbl)
            end
          }
          value_signal = widget_value_signal(widget)
          widget.signal_connect_after(value_signal) do |*args|
            sample_activate_from_widget(prop, widget)
          end
        else
          callback = proc {
            if checkbox.active?
              handle_boolean_property_active(prop, lbl)
            else
              handle_boolean_property_inactive(prop, lbl)
            end
          }
        end
        ## freezing the callback to prevent it from disappearing in gc (FIXME)
        callback.freeze
        act = self.map_simple_action(prop, prefix: "font".freeze, &callback)
        ## disables the checkbox :
        # act.enabled = false
        ## sets the checkbox and model button to initial state ...
        act.activate()
      end

      initialize_sample
    end

    def handle_widget_property_active(prop, widget, label)
      widget.sensitive = true
      handle_property_active(prop, label)
      sample_activate_from_widget(prop, widget)
    end

    def handle_boolean_property_active(prop, label)
      handle_property_active(prop, label)
      sample_activate(prop)
    end

    def handle_property_active(prop, label)
      label.sensitive = true
    end

    def handle_widget_property_inactive(prop, widget, label)
      widget.sensitive = false
      handle_property_inactive(prop, label)
    end

    def handle_boolean_property_inactive(prop, label)
      handle_property_inactive(prop, label)
    end

    def handle_property_inactive(prop, label)
      label.sensitive = false
      sample_deactivate(prop)
    end

    def widget_value_signal(widget)
      case widget
      when Gtk::ComboBox
        "changed".freeze
      when Gtk::SpinButton
        "value-changed".freeze
      when Gtk::FontButton
        "font-set".freeze
      when Gtk::ColorButton
        "color-set".freeze
      else
        raise ArgumentError.new("Unsupported widget kind: #{widget.class}")
      end
    end

    def to_s
      "#<%s 0x%06x>" % [self.class, __id__]
    end

    def initialize_sample
      buff = preview_buffer
      tag = tag_sample
      start_iter = buff.start_iter
      end_iter = buff.end_iter
      buff.apply_tag(tag, start_iter, end_iter)
    end

    def sample_activate(prop)
      tag_sample.set_property(prop, true)
    end

    ## @return [String or false]
    def property_set_p_name(prop)
      if prop == "accumulative-margin".freeze
        ## there is no "-set" property for this value property
        return false
      elsif idx = (prop =~ /-rgba$/.freeze)
        ## e.g "background-rgba" [in] => "background-set" [out]
        set_p_name = (prop[...idx] + "-set").freeze
      else
        set_p_name = (prop + "-set").freeze
      end
      return set_p_name
    end

    def value_for_widget(widget)
      case widget
      when Gtk::ColorButton
        return widget.rgba
      when Gtk::ComboBox
        model = widget.model
        iter = widget.active_iter
        ## always using index 1 for the value field, in the UI definition
        return model.get_value(iter, 1)
      when Gtk::FontChooser
        desc = widget.font_desc
        return desc.family
      else
        ## Gtk::SpinButton generally
        return widget.value
      end
    end

    def sample_activate_from_widget(prop, widget)
      val = value_for_widget(widget)
      if prop == "size".freeze
        ## The text tag "size" property is one property in this
        ## configuration dialog where the value for that property's
        ## configuration widget must be translated before application to
        ## the sample object.
        ##
        ## This does not in in itself provide support for unparsing/parsing
        ## the value onto any string representation during serialziation
        ## or desererialization of a FontDef or FontScheme.
        ##
        ## This value will also have to be set with a reciprocal
        ## transformation, when initializing the dialog for any single
        ## text tag or font definition.
        val = val * Pango::SCALE
      end
      tag_sample.set_property(prop, val)
      set_p = property_set_p_name(prop)
      tag_sample.set_property(set_p, true)
    end

    def sample_deactivate(prop)
      prop.freeze
      if set_p_name = property_set_p_name(prop)
        ## TBD this does not clear any existing value for the property,
        tag_sample.set_property(set_p_name, false)
      else
        ## there is no "-set" property for "accumulative-margin",
        ## thus property_set_p_name returns false for that property.
        ##
        ## the behavior here is to only set the property's value to
        ## false
        tag_sample.set_property(prop, false)
      end
    end

  end


  class TextableTest < PebblApp::GtkApp # is-a Gtk::Application
    include PebblApp::ActionableMixin


    def initialize(id = "space.thinkum.test.textable")
      super(id)

      signal_connect "startup" do |gapp|
        self.map_simple_action("app.quit") do |obj|
          self.quit
          true
        end
      end

      signal_connect "activate" do |gapp|
        wdw = self.create_app_window
        self.add_window(wdw)
        wdw.signal_connect_after "destroy" do
          self.quit
          true
        end
        wdw.show
      end
    end

    def create_app_window()
      TextableFontPrefs.new()
    end

    def quit()
      super()
      self.windows.each do |wdw|
        PebblApp::AppLog.debug("Closing #{wdw}")
        wdw.close
      end
      if @gmain.running
        @gmain.running = false
      end
    end

  end ## TextableTest

end
