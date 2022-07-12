

require 'pebbl_app/gtk_app'

module PebblApp

  module Util
    class << self
      def freeze_array(ary)
        ary.tap { |elt| elt.freeze }.freeze
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
    ##
    ## Not represented in Gtk::CellRendererText
    ## - pixels above, below, in wrap
    ## - indent, left margin, right margin
    ## - letter spacing, background full height
    ##
    ## Text Tag Properties not used on the font config UI:
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

    ## Properties for text tags that do not have a <name>-set property
    ##
    ## Not represented in Gtk::CellRendererText: name, accumulative-margin
    ##
    ## Not mapped here (no widget) : name, label-string (added)
    TAG_OTHER_PROPS ||=
      Util.freeze_array %w(accumulative-margin)

    ## Color property mapping for text tags
    ##
    ## Each of these correspondds to an <name>-rgba property and a
    ##<name>-set property  in text tags
    ##
    ## Not represented in Gtk::CellRendererText
    ##  - underline color
    ##  - paragraph-background color
    ##  - strikethrough color
    ##
    TAG_RGBA ||=
      Util.freeze_array %w(background foreground strikethrough
                           underline paragraph-background
                          ).map { |name| name + "-rgba" }

    ## Property name mapping for TAG_SET_PROPS, TAG_OTHER_PROPS, TAG_RGBA
    TAG_ALL ||=
      TAG_OTHER_PROPS.dup.concat(TAG_SET_PROPS.dup.concat(TAG_RGBA.dup))

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

      FontConst::TAG_ALL.map do |prop|
        ## FIXME this "just works" for the widget/action mapping.
        ##
        ## For any single font, the initial state of each widget for the
        ## properties of that font would be beyond the scope of here (TO DO)
        suffix = "_" + prop.gsub("-","_")
        chk_id = "enabled" + suffix
        if ! chk = self.get_internal_child(bld, chk_id)
          raise "enabled checkbox not found: #{prop}"
        end
        lbl_id = "map" + suffix
        if ! lbl = self.get_internal_child(bld, lbl_id)
          raise "label widget not found: #{prop} => #{lbl_id}"
        end
        wdgt_id = "font" + suffix
        ## wdgt may be null for two of the properties,
        ## each of which has no value widget
        wdgt = self.get_internal_child(bld, wdgt_id)
        act = self.map_simple_action(prop, prefix: "font".freeze) do |*args|
          ## activated after a change in state in the checkbox widget
          if chk.active?
            lbl.sensitive = true
            wdgt.sensitive = true if wdgt
          else
            lbl.sensitive = false
            wdgt.sensitive = false if wdgt
          end
        end
        ## disables the checkbox :
        # act.enabled = false
        ## activates the checkbox, setting the initial state :
        act.activate
      end

    end

    def to_s
      "#<%s 0x%06x>" % [self.class, __id__]
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
