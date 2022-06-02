## apploader_gtk.rb - something to call Gtk.init

## NB some forms under each of the Ruby-GNOME Gtk and Gdk modules
## will not become available until after calling either of the the
## Ruby-GNOME methods Gtk.init or Gdk.init
##
## After either call, some API forms will become available e.
## g Gtk.init_check,...
##
## Gdk.init can be called separately but
## - it accepts no ostensible args
## - it removes itself after the call, and
## - it calls Gtk.init, such that also removes itself after call
##
## - NB Ruby-GNOME Gdk.init also pulls in a hard dependency on X11
##   cf. "The source code"
##
## ... such that neither Gdk.init nor Gtk.init will be available
##     after either of the two is called.
##
##
## Pursuant towards minimizing any sense of ambiguity about what APIs
## are available in GTK with Ruby-GNOME ... apploader_gtk.rb

## TBD the API here
## - it could be called from a BEGIN form, e.g for the RIView app
##
## - N/A for any GLib-based service app (does not need GTK)
##   ... such that could provide args e.g to GLib...
##   ... via Gio::Application#run(...) ... in an instance method
##
## - NB 'command-line' signal for an app registered
##   with G_APPLICATION_HANDLES_COMMAND_LINE
##   ... such that would need the app to be initialized
## - ... refer to GApplication @ devhelp
##
## - NB 'open' signal when  G_APPLICATION_HANDLES_OPEN
##   x menus on the desktop ... drag and drop ... etc.
##
## - TBD how any of that factors onto using an indepdendent GLib::MainLoop

=begin TBD

# .. separately ...

Gtk.init(...)

main_loop = GLib::MainLoop.new
main_ctxt = main_loop.context
while some-condition do
  main_ctxt.iteration(true) # ?? or false ...
  ## ... other handling ... e.g let process signals propogate ...
end

... and in some other thread ...
win_ctxt = GLib::MainContext.new
win_ctxt_acquired_p = win_ctxt.acquire
prepared_info = win_ctxt.prepare ## NB second retv element, a "priority "
queried_info = win_ctxt.query(...)
checked_info = win_ctxt.check(...)
dispached_info = win_ctxt.dispatch(...)


TBD
GLib::Source.current -> ... & note assertion failures
.. nb no 'new' for GLib::Source

NB GLib::MainContext#add_poll && GLib::PollFD


NB @ three modules here ... cf. GLib "Main Event Loop" devehelp
GLib::Idle.source_new(...) || GLib::Idle.add(...)
GLib::ChildWatch.source_new(...) x spawn  and GTK
GLib::Timeout.source_new(<duration>) | GLib::Timeout.add(<d>) | GLib::Timeout.add_seconds

... each of the *add* forms presumably operates on a current context
... whereas GLib::Source#attach(context) is also available [x]

GLib::PollFD.new(...) && GLib::MainContext.add_poll && GLib::Source#add_poll
alternately
GLib::MainContext. ... no set_poll_func here

,,. TBD Gio::Pollable{Output|Input}Stream.create_source && Gio::PollalbleSource
&& pipe I/O ?? & NB blocking I/O
but NB the I/O API onto GTK


... TBD how anything goes into callbacks from any of those.

NB GLib::Source#set_callback { block ??? }

NB I/O pipes and the Vte3 widgets


=end
