

require 'pebbl_app/gtk_app'

module PebblApp

  class TextableTagPrefs < Gtk::Dialog
    extend PebblApp::FileCompositeWidget
    use_template(File.expand_path("../ui/textable.font.ui", __dir__),
                 ## ... map template elements ...
                 %w(
                   ))

    include PebblApp::DialogMixin
  end


  class TextableTest < PebblApp::GtkApp # is-a Gtk::Application
    include PebblApp::ActionableMixin

    # extend PebblApp::GUserObject
    # self.register_type ## cannot here & in GtkApp, or the constructor tree falls apart
    ## TBD
    ## - cannot call type_register here without calling it in GtkApp
    ## - the constructor chain falls apart when calling type_register here and in GtkApp
    ## - it may not be enough to dispatch to Gtk::Object.initialize under
    ##   that peculiar configuraton

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
      TextableTagPrefs.new()
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
