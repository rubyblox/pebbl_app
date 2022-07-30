

require 'pebbl_app/gtk_app'

require 'pango'

module PebblApp

  module GtkUtil
    class << self
      ## @param widget [Gtk::Widget]
      def properties_map(widget, mask = GLib::Param::READWRITE,
                        &callback)
        ## FIXME move to a GtkUtil module
        wdgt_class = widget.classs
        wdgt_class.properties.each do |property|
          param = wdgt_class.property(property)
          if param.readable?
            value = widget.get_property(property)
            callback.yield(value, property, widget)
          end
        end
      end

    end
  end


  module StringLabelMixin
    module Const
      PROP_LABEL_STRING ||= "label-string".freeze
    end
    def self.included(whence)
      whence.extend GUserObject
      whence.register_type
      whence.install_property(
        GLib::Param::String.new(
          Const::PROP_LABEL_STRING, ## param name
          "Label String".freeze, ## param nick
          "String label for an object".freeze, ## param blurb
          "(Unknown)", ## param default
          ## flags:
          GLib::Param::READWRITE |
            GLib::Param::STATIC_NAME |
            GLib::Param::STATIC_NICK |
            GLib::Param::STATIC_BLURB))

      def label_string()
        @label_string
      end

      def label_string=(value)
        @label_string = value
        notify(Const::PROP_LABEL_STRING)
      end
    end
  end

  ## Constants for properties used in the TextableFontPrefs dialog
  module FontConst
    SET_RE = /-set$/.freeze
    RGBA_RE = /-rgba$/.freeze

    ## Properties for text tags (non-RGBA, non-boolean)
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
      FreezeUtil.freeze_array %w(background-full-height
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
      FreezeUtil.freeze_array %w(background foreground strikethrough
                                 underline paragraph-background
                                ).map { |name| name + "-rgba" } ## convenience here

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
      FreezeUtil.freeze_array %w(accumulative-margin)


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
    class << self

      ## @return [Pango::FontDescription]
      def font_default()
        sc = Gtk::StyleContext.new
        sc.get_property("font", Gtk::StateFlags::NORMAL).value
      end

      ## @return [Gtk::TextTag]
      def text_tag_default(name = nil)
        fdesc = font_default
        tag = Gtk::TextTag.new(name)
        tag.set_property("font-desc", fdesc)
        return tag
      end

      def font_def_default(name = nil)
        fdesc = font_default
        fdef = new("name" => name)
        fdef.set_property("font-desc", fdesc)
        return fdef
      end
    end

    ## ordered list of inherited font definitions
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

    def initialize(**properties)
      name_str = "name"
      ## TBD constructor args - accepting all properties here
      ##
      ## This dispatches to the constructor in Gtk::Object scope
      super(name_str => properties[name_str]) ## constructor only
      properties.delete("name".freeze)
      properties.each do |name, val|
        set_property(name, val)
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



  ## A font configuration dialogue with a layout inspired by Emacs
  ## customization faces
  ##
  class TextableFontPrefs < Gtk::Dialog

    module Const
      ## offset for configurable properties in internal array mappings
      CONFIG_OFFSET = 2
    end

    extend PebblApp::FileCompositeWidget
    use_template(File.expand_path("../ui/textable.font.ui", __dir__),
                 ## ... map template elements ...
                 %w(header_font_label fonts_tree inherit_tree
                    fonts_menu preview_buffer tag_sample font_size
                    font_new_dialog font_new_name
                    font_new_label font_new_grid
                    font_delete_dialog font_delete_label
                   ))

    include PebblApp::ActionableMixin

    ## to be initilized in constructor:
    ## fonts_store
    ## inherit_store

    ## bind property widgets (template children)
    ##
    ## These will be accessed without a  method binding,
    ## thus not passed to use_template
    ##
    ## Two general categories of configuration widget initialized here:
    ## - configuration widget having a value property
    ## - configuration widget for a boolean property
    ##
    ## The first category of configuration widget corresponds generally
    ## to the <name>/<name>-set semantics for most of the configuration
    ## attributes of a Gtk::TextTag. In these instances, the <name>
    ## property holds the value for the configuration attribute, while
    ## the <name>-set property holds a boolean flag indicating whether
    ## that attribute is set for the TextTag, In application, each
    ## property in this category will have a value widget of some kind.
    ##
    ## There is at least one boolean valued property of Gtk::TextTag,
    ## such that has been defined without a <name>-set property. In
    ## application here, this will be rendered as a special instance of
    ## a boolean valued property.
    ##
    ## In all instances, each configuration attribute will have a
    ## checkbox and a model button, in the configuration UI.
    ##
    ## Callbacks for these widgets will be initialized in the
    ## consturctor. This section simply ensures that the widgets form
    ## the Glade UI definition are available as template child objects.
    ##
    ## Each of these elements from the UI definition will be accessed
    ## without a direct method binding, mainly via get_internal_child
    ## in the constructor
    ##
    FontConst::TAG_ALL.each do |prop|
      field = prop.gsub("-", "_")
      ## bind the model button and checkbox
      ## for each configuration attribute
      model = "map_" + field ## model button
      chk = "enabled_" + field ## check box
      bind_template_child_full(model, true, 0)
      bind_template_child_full(chk, true, 0)

      ## bind the value widget for each value property
      if ! (prop == "accumulative-margin".freeze ||
            prop == "background-full-height".freeze)
        wdgt = "font_" + field
        if ! template_children.include?(wdgt)
          bind_template_child_full(wdgt, true, 0)
          template_children << wdgt
        end
      end
    end

    include DialogMixin

    include AccelMixin


    attr_reader :font_scheme, :fonts_store, :inherit_store

    def initialize
      super
      ## clear table views and cell renderers inherited from the template
      # TreeUtil.clear_tree_store(inherit_store) ## see fonts_store
      TreeUtil.clear_tree_renderers(inherit_tree)

      ## right-click context menu handler for fonts_tree
      ## - activate the fonts_menu on right click
      ## - FIXME only if this dialog was initialized in "Developer Mode"
      fonts_tree.signal_connect("button-press-event") do |wdgt, evt|
        ## NB Gdk::EventButton === evt
        case evt.button
        when 3
          fonts_menu.popup_at_pointer(evt)
        end
      end

      @default_tag = Gtk::TextTag.new
      Gtk::TextTag.properties.each do |p|
        ## unset any <attr>-set flags
        ##
        ## Ih side effects: For each <attr>-set property of Gtk::TextTag
        ## this will generally set the <attr> to its "Null state" value.
        if p.match?(FontConst::SET_RE)
          @default_tag.set_property(p, false)
        end
      end
      ##
      ## Setting the sample tag's initial values before any signal bindings
      ##
      ## a default indicated in the GNOME devhelp docs for this property:
      @default_tag.set_property("accumulative-margin", true)
      ## using a non-zero Pango font size for the default tag
      @default_tag.size = sz = FontDef.font_default.size / Pango::SCALE
      font_size.value = sz


      ## initialize the sample tag
      ##
      ## calling this before any further UI elements are configured
      initialize_sample

      ## initialize the font label for the header bar
      header_font_label.text = ""

      ##
      ## initialize all actions and local caching for checkbox, label,
      ## and value widgets for each configuration attribute
      ##

      bld = self.class.composite_builder

      @property_callbacks = Hash.new
      @set_p_widgets = Hash.new

      FontConst::TAG_ALL.map do |prop|
        ## configure an action to toggle widget states for the property
        ## and set the sample's property when active. The action will be
        ## in effect activated on a checkbox widget for the property's
        ## configuration
        suffix = "_" + prop.gsub("-","_")
        checkbox_id = "enabled" + suffix

        if ! checkbox = self.get_internal_child(bld, checkbox_id)
          raise "checkbox widget not found: #{prop} => #{checkbox_id}"
        end

        lbl_id = "map" + suffix
        if ! lbl = self.get_internal_child(bld, lbl_id)
          raise "label widget not found: #{prop} => #{lbl_id}"
        end

        ## configure an action/callback for each propety
        ##
        ## the prefix and name for each of these action definitions
        ## will correspond to a configuration value in the UI template
        ## for this class

        widget_id = "font" + suffix

        ## binding a set_p checkbox for every property mapped here.
        ##
        ## for the one configurable property without a corresponding
        ## "<name>-set" property, the key for the set_p checkbox will
        ## be the property name itself
        set_p_name = property_set_p_name(prop)
        @set_p_widgets[set_p_name] = checkbox


        checkbox.signal_connect("notify::active".freeze) do |chk|
          ## activated after the checkbox is checked/unchecked
          if iter = fonts_store_active_iter
            AppLog.warn("State @ #{set_p_name} = #{chk.active?}") if $DEBUG
            set_p_idx = @fonts_store_indices[set_p_name]
            fonts_tree.model.set_value(iter, set_p_idx, chk.active?)
          end
        end


        AppLog.info("#{prop} set-p => #{set_p_name}") if $DEBUG

        ## 'widget' here may be null for a property that has no value
        ## widget, i.e a boolean property.
        if widget = self.get_internal_child(bld, widget_id)
          ##
          ## For all value properites
          ##

          @property_callbacks[prop] = widget_setter_proc(widget, prop)

          if (prop == "strikethrough-rgba".freeze) ||
              (prop == "underline-rgba".freeze)
            ## activation for ensuring that a related/dependent
            ## widget will be activated for each property having an
            ## effective dependency relation in the configuration.
            ##
            ## e.g for activating the 'strikethrough' checkbox when the
            ## 'strikethrough-rgba' checkbox is activated
            if idx = (prop =~ FontConst::RGBA_RE)
              related = property_set_p_name(prop[...idx])
              AppLog.info("#{prop} related => #{prop[...idx]} => #{related}")
            else
              AppLog.error("Wrong mapping for #{prop} related => #{prop[...idx]}}")
            end
          else
            related = false
          end

          callback = proc {
            ## activated after a change of state in the checkbox widget
            if checkbox.active?
              if related
                ## this will activate the checkcbox for e.g "underline"
                ## when the checkbox for "underline-rgba" is activated
                related_chk = @set_p_widgets[related]
                AppLog.warn(
                  "Related chk @ #{prop} (#{checkbox}) => #{related} : #{related_chk}"
                ) if $DEBUG
                related_chk.active = true
              end
              handle_widget_property_active(prop, widget, lbl)
            else
              handle_widget_property_inactive(prop, widget, lbl)
            end
          }
          value_signal = widget_value_signal(widget)
          ##
          ## propagate changes when any value widget's value is set
          ##
          widget.signal_connect_after(value_signal) do |widget, * _|
            ## update the sample tag (FIXME not working out for colors now)
            sample_activate_from_widget(prop, widget)
            value = value_for_widget(widget)
            if prop == "size".freeze
              value = value * Pango::SCALE
            elsif value.respond_to?(:to_i)
              value = value.to_i
            end
            AppLog.info(
              "[#{widget.class} #{value_signal}] Setting #{prop} => #{value.inspect}"
            ) if $DEBUG
            fonts_model_cursor_activate(prop, value)
          end
        else
          ## boolean configuration attributes
          ##
          ## boolean sample and model attributes will be
          ## managed in each handle_boolean_* method
          ##
          @set_p_widgets[prop] = checkbox
          callback = proc {
            active = checkbox.active?
            if active
              handle_boolean_property_active(prop, lbl)
            else
              handle_boolean_property_inactive(prop, lbl)
            end
            fonts_model_cursor_activate(prop, active)
          }
        end
        ## freezing each callback to prevent it from disappearing in gc (FIXME)
        callback.freeze
        act = self.map_simple_action(prop, prefix: "font".freeze, &callback)
        ## disables the checkbox :
        # act.enabled = false
        ## sets the checkbox and model button to initial state ...
        act.activate()
      end ## FontConst::TAG_ALL => checkbox & widget iterator


      ## fonts_menu
      ##
      ## Actions in the fonts_menu:
      ## - win.font-new
      ## - win.font-delete
      ##
      ## Callbacks in both actions will operate on the fonts_tree

      ## font_new_dialog activation
      ##
      ## freezing at least the action name and prefix, to try to prevent
      ## this from being GC'd
      ##
      ## The prefix will be bound for an action group in the fonts_menu
      map_simple_action("font-new", #.freeze, ## also the prefix ...
                        prefix: "win", receiver: fonts_menu) do
        ## activate the "New Font" dialogue (FIXME only if editable)
        font_new_dialog.show
      end

      ## resuable menu - hide instead of delete/destroy
      fonts_menu.signal_connect("delete-event") do |menu|
        menu.hide_on_delete
      end

      ##
      ## fonts_tree, fonts_store
      ##

      ## clear any cell renderers inherited from the template
      TreeUtil.clear_tree_renderers(fonts_tree)

      ## all properties %s with a corresponding %s-set property
      value_props = FontConst::TAG_SET_PROPS.dup.concat(
        FontConst::TAG_RGBA_PROPS.dup)

      ## using two columns in addition to the columns for properties
      ## listed in constants here
      ## - font name (i.e Gtk::TextTag#name)
      ## - font label (i.e Font#label_string)
      n_cols = Const::CONFIG_OFFSET +
        (value_props.length * 2) + FontConst::TAG_OTHER_PROPS.length
      col_types = Array.new(n_cols)
      col_names = Array.new(n_cols)
      col_types[0] = FontDef.property("name".freeze).value_type
      col_names[0] = "name".freeze
      col_types[1] = FontDef.property("label-string".freeze).value_type
      col_names[1] = "label-string".freeze
      n = Const::CONFIG_OFFSET
      value_props.each do |vprop|
        ## value properties with a corresponding %-set property
        ## e.g propertes on a FontDef or general Gtk::TextTag
        vprop.freeze
        col_types[n] = FontDef.property(vprop).value_type
        col_names[n] = vprop
        n = n + 1
        set_p_name = property_set_p_name(vprop)
        col_types[n] = FontDef.property(set_p_name).value_type
        col_names[n] = set_p_name
        n = n + 1
      end

      FontConst::TAG_OTHER_PROPS.each do |bprop|
        ## boolean properties (no %-set property)
        bprop.freeze
        col_types[n] = FontDef.property(bprop).value_type
        col_names[n] = bprop
        n = n + 1
      end

      ## store the array of types and properties for access in callbacks
      @fonts_store_types = col_types.freeze
      @fonts_store_props = col_names.freeze
      @fonts_config_props = col_names[2..].freeze
      @fonts_store_indices = indices = Hash.new
      col_names.each_index do |idx|
        prop = col_names[idx]
        indices[prop] = idx
      end
      @fonts_store_indices.freeze

      ## initialize the model, i.e list store for the fonts_tree
      ## using the column types interpolated in the previous
      @fonts_store = store = Gtk::ListStore.new(* col_types)
      fonts_tree.model = store

      ## initialize a single display column for the fonts_tree,
      ## using a text cell renderer for that column
      ## - FIXME us a Gtk::Label & update all font propeties of it
      ##  (less visually confusing)
      rdr = Gtk::CellRendererText.new
      @fonts_tree_font_col = col = Gtk::TreeViewColumn.new("Font", rdr)
      fonts_tree.insert_column(col, -1)

      ## given the list store (model) for the fonts_tree and the visual
      ## column initialized here, column 0 from the list store will
      ## provide the text attribute for the cell renderer to that visual
      ## column
      col.add_attribute(rdr, "text", 0)
      render_attrs = {} if $DEBUG ## debugging for tree cell renering
      ## initialize all intersectional properties of the cell renderer
      Gtk::CellRendererText.properties.each do |prop|
        if idx = col_names.index(prop)
          AppLog.debug(
            "Adding renderer attribute: #{prop} @ #{idx} [#{col_types[idx]}]"
          ) if $DEBUG
          render_attrs[prop] = idx if $DEBUG
          col.add_attribute(rdr, prop, idx)
        end
      end

      ##
      ## callback for activation of a fow in fonts_tree
      ##
      ## Overview: retrieve an iterator for the tree path from the
      ## event, then operate on values of the model (list store) using
      ## the iteroator for that tree path
      ##
      ## A tree iterator for the active row will be available asynchronously
      ## via the method #fonts_store_active_iter
      fonts_tree.signal_connect_after("row-activated") do |view, path, _|
        model = fonts_tree.model
        iter = model.get_iter(path)

        ## update the font label in the header bar
        label =  model.get_value(iter, 1)
        if label.empty?
          label = "(No label)".freeze
        end
        name =  model.get_value(iter, 0)
        if name.empty?
          name = "(anonymous)".freeze
        end
        if label == name
          header_font_label.text = label
        else
          header_font_label.text = "%s (%s)" % [label, name]
        end
        ##
        ## update the configuration UI for the now-active now
        ##
        n = Const::CONFIG_OFFSET
        @fonts_config_props.each do |prop|
          prop.freeze
          val = model.get_value(iter, n)
          AppLog.debug("[Active Row] #{prop} => #{val.inspect}") if $DEBUG

          if prop.match?(FontConst::SET_RE) ||
              prop == "accumulative-margin".freeze
            ## This is a <prop>-set column - transfer the value directly
            ## if any checkbox widget is found for the value
            if chk = @set_p_widgets[prop]
              chk.active = val
            elsif $DEBUG
              AppLog.warn(
                "[Active Row] No set-p widget found for #{prop.inspect}"
              )
            end
          elsif (set_p_name = property_set_p_name(prop)) &&
              (set_p_idx = @fonts_store_indices[set_p_name])
            if model.get_value(iter, set_p_idx)
              ## ^ Set the value only if it's set-p in this row
              if (cb = @property_callbacks[prop])
                cb.yield(val)
              else
                ## reached for boolean properties
                #AppLog.error("No value callback fround for #{prop}")
              end
            else
              ## reached for the actual -set properties
              # AppLog.warn("TBD set_p_idx @ #{set_p_name}")
            end
          elsif $DEBUG
           AppLog.warn(
              "[Active Row] No active mapping found for  #{prop.inspect}"
            )
          end
          ## and continue iteration ...
          n = n + 1
        end
      end ## row-activated handler on fonts_tree

      map_simple_action("win.fonts-select-none") do
        if iter = fonts_store_active_iter
          sel = fonts_tree.selection
          sel.unselect_path(iter.path)
        end
      end

      ##
      ## Event handlers for font_new_dialog
      ##

      font_new_dialog.signal_connect_after("key-press-event") do |window, evt|
        if evt.keyval.eql?(PebblApp::Keysym::Key_Escape)
          window.hide
        end
      end

      font_new_dialog.signal_connect("delete-event") do |window|
        ## The font_new_dialog is defined in the same UI file as
        ## the template for this dialog window.
        ##
        ## This "leaf dialog" window has not been defined with a
        ## composite class
        ##
        ## As a reuable dialog window, the window will be hidden instead
        ## of destroyed on delete-event (e.g when closed)
        window.hide_on_delete
      end

      ## clear entry fields when hidden (reusable dialog)
      font_new_dialog.signal_connect_after("hide") do |_|
        font_new_name.text = ""
        font_new_label.text = ""
      end

      ## reset focus when shown
      font_new_dialog.signal_connect_after("show") do |window|
        window.set_focus(font_new_label)
      end

      ## auto-fill the font_new_name field with a downcased
      ## representation of font_new_label
      font_new_name.signal_connect("focus") do |widget|
        if widget.text.empty?
          widget.text = font_new_label.text.downcase
        end
        ## ensure that other focus handlers will activate
        false
      end

      map_simple_action("font-new.accept", receiver: font_new_dialog) do
        ## add a new item to the fonts_store, then select in the fonts_tree
        name = font_new_name.text
        name = format("font_%x", Time.now.strftime("%s").to_i) if name.empty?
        label = font_new_label.text
        label = name if label.empty?
        ## hide the widget, clearing any entered values
        font_new_dialog.hide
        AppLog.warn(
          "New font @ name: #{name.inspect}, label: #{label.inspect}"
        ) if $DEBUG
        ## set initial values
        ary = Array.new(@fonts_store_props.length)
        ary[0] = name
        ary[1] = label
        n = Const::CONFIG_OFFSET
        @fonts_config_props.each do |prop|
          val = font_property_default(prop)
          AppLog.debug(
            "(#{n}) Default #{prop} => #{val.inspect} [#{@fonts_store_types[n]}]"
          ) if $DEBUG
          if render_idx = render_attrs[prop]
            ## if $DEBUG
            AppLog.debug("@ render: #{render_idx}")
          else
            ## properties not presented in the cell renderer
            AppLog.debug("not rendered: #{prop}") if $DEBUB
          end if $DEBUG
          ary[n] = val
          n = n + 1
        end
        ## appennd the item to the fonts_store
        iter = fonts_store.insert(-1, ary) ## with values

        ## focus and select the active item ...
        fonts_tree.set_cursor(iter.path, @fonts_tree_font_col, false)
        ## Lastly, set the new row as active.
        ##
        ## The row-activated handler should then update the sample
        ## to reflect the item's properties
        fonts_tree.row_activated(iter.path, @fonts_tree_font_col)
      end ## font-new.accept action on font_new_dialog

      map_simple_action("font-new.cancel", receiver: font_new_dialog) do
        font_new_dialog.hide
      end

      ## Event handlers for font_delete_dialog
      ##
      map_simple_action("font-delete",
                        prefix: "win", receiver: fonts_menu) do
        ## populate some values to the font_delete_dialog content widgets
        if iter = fonts_store_active_iter
          name = fonts_tree.model.get_value(iter, 0)
          label = fonts_tree.model.get_value(iter, 1)
          if name == label
            font_delete_label.text = "Delete font #{label}?"
          else
            font_delete_label.text = "Delete font #{label} (#{name})?"
          end
        else
          font_delete_label.text = "No active font"
        end
        font_delete_dialog.show
      end

      font_delete_dialog.signal_connect_after("key-press-event") do |window, evt|
        if evt.keyval.eql?(PebblApp::Keysym::Key_Escape)
          window.hide
        end
      end

      font_delete_dialog.signal_connect("delete-event") do |window|
        window.hide_on_delete
      end

      map_simple_action("font-delete.accept", receiver: font_delete_dialog) do
        if iter = fonts_store_active_iter
          fonts_tree.model.remove(iter)
        end
        font_delete_dialog.hide
      end

      map_simple_action("font-delete.cancel", receiver: font_delete_dialog) do
        font_delete_dialog.hide
      end

    end ## #initailize

    def property_set_p_name(prop)
      ## moving some hard-coding into a separate method
      if prop.match?(FontConst::SET_RE)
        ## a debug catch of a kind
        raise ArgumentError.new("Set-p property: #{prop}")
      elsif prop == "accumulative-margin".freeze
        ## this boolean value property has no additional "-set" property
        ##
        ## reached under the row-activated signal for fonts_tree
        return prop
      elsif (prop == "underline-rgba".freeze) ||
        (prop == "strikethrough-rgba".freeze)
        ## ^ handling the two exceptions to the general mapping of
        ## <name>-rgba and <name>-set for a color attr <name>
        set_prefix = prop
      elsif idx = (prop =~ FontConst::RGBA_RE)
        set_prefix = prop[...idx]
      else
        set_prefix = prop
      end
      return (set_prefix + "-set").freeze
    end

    def fonts_store_active_iter
      cursor_path, _ = fonts_tree.cursor()
      if cursor_path
        fonts_tree.model.get_iter(cursor_path)
      else
        false
      end
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

    def widget_setter_proc(widget, prop)
      case widget
      when Gtk::ComboBox
        ## always using column 1 to store the referencable value
        ## in a combo box
        proc { |val|
          if val
            mdl = widget.model
            ## iterate on the model until finding a matching value
            ## in column 1
            n = 0
            if (iter = mdl.iter_first)
              combo_val = mdl.get_value(iter, 1)
              catch(:found) do |tag|
                if combo_val == val
                  widget.set_active(n)
                  throw tag, n
                else
                  n = n + 1
                end
              end
            else
              AppLog.warn("No entries found in model for #{widget}")
            end
          end
        }
      when Gtk::SpinButton
        if prop == "size"
          proc {
            |val| widget.value = val / Pango::SCALE
          }
        else
          proc {
            |val| widget.value = val
          }
        end
      when Gtk::FontButton
        ## value should be a font family here
        proc { |val|
          widget.set_property("font", val)  if val
        }
      when Gtk::ColorButton
        ## value should be a Gtk RGBA here
        proc { |val|
          widget.set_rgba(val) if val
        }
      end
    end
    def to_s
      "#<%s 0x%06x>" % [self.class, __id__]
    end

    def font_property_default(name)
      val = @default_tag.get_property(name)
      if name == "size".freeze
        ## FIXME factor this out of the API here
        return val * Pango::SCALE
      else
        return val
      end
    end

    def initialize_sample
      ## the sample tag is initialized as a template child.
      ##
      ## This initializes the tag to use a set of font properties
      ## initialized for a default <<TBD instance>>
      #tag_default = FontDef.new()
      #tag_default.size = @default_font.size
      Gtk::TextTag.properties do |p|
        param = Gtk::TextTag.property(p)
        if param.readable? && param.writable? &&
            p.match?(FontConst::SET_RE)
          # val = font_property_default(p) #tag_default.get_property(p)
          # tag_sample.set_property(p, val)
          tag_sample.set_property(p, false)
        end
      end
      ## apply the sample tag to the preview buffer
      buff = preview_buffer
      tag = tag_sample
      start_iter = buff.start_iter
      end_iter = buff.end_iter
      buff.apply_tag(tag, start_iter, end_iter)
    end

    def sample_activate(prop)
      tag_sample.set_property(prop, true)
    end

    def fonts_model_cursor_activate(prop, value)
      if iter = fonts_store_active_iter
        ## ^ else no active row - no fonts, or no font previously
        ##  in the fonts_tree
        idx = @fonts_store_indices[prop]
        model = fonts_tree.model
        model.set_value(iter, idx, value)
        set_p_name = property_set_p_name(prop)
        ## also update any set-p field in the list store
        if set_p_name
          if set_idx = @fonts_store_indices[set_p_name]
            if set_p_name != prop
              ## avoid unconditinally setting the accumulative-margin
              ## field to true
              model.set_value(iter, set_idx, true)
            end
          else
            AppLog.error("no set-p property found for value property #{prop}")
          end
        else
          AppLog.error("?? set-p property ?? #{prop}")
        end
      end
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
        AppLog.debug("Closing #{wdw}")
        wdw.close
      end
      if @gmain.running
        @gmain.running = false
      end
    end

  end ## TextableTest

end
