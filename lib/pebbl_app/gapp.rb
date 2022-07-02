
require 'pebbl_app/gtk_framework'

require 'gio2'

module PebblApp
  class GApp < Gio::Application
    include GAppMixin
  end
end
