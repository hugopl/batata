# Monkey patches not yet upstreamed goes here.
lib LibGtk
  fun gtk_widget_class_add_binding(widget_class : Void*, key_val : UInt32, mods : Int32,
                                   callback : ShortcutFunc, format_string : LibC::Char*, ...)
end

lib LibGdk
  fun gdk_clipboard_set_text(clipboard : Void*, text : LibC::Char*)
end

module Gio
  class PropertyAction
  end
end

module Adw
  class Dialog
    def self.new
      new(accessible_role: nil)
    end
  end
end

module Gdk
  class Clipboard
    def text=(text : String) : Nil
      LibGdk.gdk_clipboard_set_text(to_unsafe, text)
    end
  end
end

module Gtk
  class Widget
    # :ditto:
    def size_allocate(x : Int32, y : Int32, width : Int32, height : Int32, baseline : Int32)
      size_allocate(Gdk::Rectangle.new(x, y, width, height), baseline)
    end

    macro add_binding(key_val, mods, slot)
      def self._class_init(type_struct : Pointer(LibGObject::TypeClass), user_data : Pointer(Void)) : Nil
        previous_def
        callback = LibGtk::ShortcutFunc.new do |widget, args, user_data|
          retval = {{ @type }}.new(widget, :none).{{ slot }}
          GICrystal.to_c_bool(retval)
        end
        LibGtk.gtk_widget_class_add_binding(type_struct, {{ key_val }}, {{ mods }}, callback, nil)
      end
    end
  end

  class Popover
    def pointing_to=(rect : Gdk::Rectangle?) : Nil
      rect_ptr = if rect.nil?
                   Pointer(Void).null
                 else
                   rect.to_unsafe
                 end
      LibGtk.gtk_popover_set_pointing_to(to_unsafe, rect_ptr)
    end
  end
end
