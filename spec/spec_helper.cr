require "spec"
require "libadwaita"

require "../src/monkey_patches"
require "../src/desktop"
require "../src/log"
require "../src/version"

module Gtk
  class Widget
    def <=>(other)
      @pointer <=> other.@pointer
    end
  end
end

def create_n_views(desktop, n)
  start = desktop.get_n_items + 1
  Array.new(n) do |i|
    item = Desktop::Item.new
    label = Gtk::Label.new((start + i).to_s)
    item.title = label.label
    item.append(label)
    desktop.add_item(item)
    item
  end
end

Spec.before_each do
  setup_logger(ENV.fetch("LOG_LEVEL", "debug"))
end

Adw.init
Gtk::Settings.for_display(Gdk::Display.default!).gtk_enable_animations = false
