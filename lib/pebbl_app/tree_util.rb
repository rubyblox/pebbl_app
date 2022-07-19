## PebblApp::TreeUtils module

require 'pebbl_app/gtk_framework'

module PebblApp
  module TreeUtils
    class << self
      ## @param model [Gtk::ListStore, Gtk::TreeStore]
      def clear_tree_store(model)
        while data = model.first
          ## second element is a path for the first model row (unused here)
          ##
          ## FIXME not tested with recusrively nested iterators
          ##
          ## FIXME not tested for activation of the row-deleted signal on
          ## the model
          ##
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
