## girtests.rb - TBD extending git_ffi-gtk3


require 'gir_ffi-gtk3'
## ^ NB also Pango, Cairo, ... **all Vte (vte3) deps**

## ^ NB the initial 'require' call does define ...
## - Gtk::Buildable
## ^ FIXME the initial 'require' call does not define ...
## - Gtk::WidgetClass (a struct, per devhelp)
##   & e.g gtk_widget_class_set_template ()

## NB using GIR typelib /usr/lib/girepository-1.0/Vte-2.91.typelib
## or any e.g /usr/lib/girepository-1.0/Vte-*.typelib
# GirFFI.setup(:Vte)
## ^ TBD see devehlp. Meanwhile ...

## TBD @ local GLib2/GTK src
## https://github.com/gtk-rs/gir-files/blob/master/GObject-2.0.gir
## - does not define a GtkWidgetClass struct
## - does reference GtkWidgetClass in a source example for a macro [G_]DECLARE_DERIVABLE_TYPE
## ! NB note the docs for G_DECLARE_DERIVABLE_TYPE
## - TBD g_autoptr(TypeName) (macro)
##   > "pointers to types with cleanup functions"
##   - "see also" (macros)
##     g_auto()
##     g_autofree() @ attribute decls in a GLib C scope
##     g_steal_pointer() @ pointer ownership (in a C language scope)


## NB
## /usr/local/src/ruby_wk/gir-ffi-wk/gir_ffi_devsrc/test/integration/generated_gtk_source_test.rb
## > generators - not insonmuch using direct calls for e.g interface definition

## NB
## GirFFI.setup :Gtk, "3.0"
## in
## gir_ffi-gtk:lib/gir_ffi-gtk3.rb
## w/ subsq. overrides


=begin TBD

TBD type_register_static - availabilability

irb(main):013:0> GObject.method(:type_register_static)
=> #<Method: GObject.type_register_static(*)>

... but sometimes (??!!) as ...

irb(main):045:0> GObject.singleton_method(:type_register_static)
=> #<Method: GObject.type_register_static(parent_type, type_name, info, flags) /home/gimbal/.local/share/gem/ruby/3.0.0/gems/gir_ffi-0.15.9/lib/gir_ffi/builders/module_builder.rb:29> 

NB <class>.object_class

irb(main):048:0> Gtk::ApplicationWindow.object_class
=> #<Gtk::ApplicationWindowClass:0x000056196c268758 @struct=#<Gtk::ApplicationWindowClass::Struct:0x000056196c268690>>


TBD GLib.load_class :<name>
e.g Gtk.load_class :Widget @ gir_ffi-gtk:lib/gir_ffi-gtk/widget.rb

TBD GTypeInfo for any type_register_static call
-  can this value be derived from any class under gir_ffi in Ruby?
- NB GObject::TypeInfo
- ! for g_type_register_static via gir_ffi*

TBD ...

class Frob < Gtk::ApplicationWindow
end

gt = GObject::TypeInfo.new
typ_ptr = gt.class_data=Frob.object_class.to_ptr ## not before the class is registered
gt.class_data = typ_ptr

.. gir_ffi@0.15.9:lib/gir_ffi/builders/user_defined_builder.rb:
   @gtype = GObject.type_register_static(...)

=end
