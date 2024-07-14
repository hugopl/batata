module Desktop
  class Layout < Gtk::LayoutManager
    getter animation_position = 1.0
    property desktop : Desktop::Widget?
    @width = 0
    @height = 0
    @switcher_width = 0
    @switcher_height = 0
    @old_positions = Hash(Item, Rectangle).new

    def initialize
      super()
    end

    def save_old_positions
      desktop = @desktop
      return if desktop.nil?

      @old_positions.clear
      root = desktop.root
      return if root.nil?

      root.size_allocate(0, 0, @width, @height) do |item, rect|
        if desktop.maximized? && item == desktop.current_item
          @old_positions[item] = Rectangle.new(0, 0, @width, @height)
        else
          @old_positions[item] = rect
        end
      end
    end

    def animation_position=(value)
      @animation_position = value
      layout_changed
    end

    @[GObject::Virtual]
    def allocate(desktop : Desktop::Widget, @width : Int32, @height : Int32, base_line : Int32) : Nil
      @desktop ||= desktop

      switcher = desktop.switcher
      if switcher.should_layout
        x = (width - @switcher_width) // 2
        y = (height - @switcher_height) // 2
        switcher.size_allocate(x, y, @switcher_width, @switcher_height, -1)
      end

      place_holder = desktop.place_holder
      if place_holder && place_holder.should_layout
        place_holder.size_allocate(0, 0, width, height, -1)
      else
        root = desktop.root
        if root
          root.size_allocate(0, 0, width, height) do |item, new_pos|
            next unless item.should_layout

            if desktop.maximized? && desktop.current_item == item
              new_pos = Rectangle.new(0, 0, @width, @height)
            end

            if @animation_position < 1.0
              old_pos = @old_positions[item]?
              new_pos = old_pos.interpolate(new_pos, @animation_position) unless old_pos.nil?
            end
            item.size_allocate(new_pos.x, new_pos.y, new_pos.width, new_pos.height, -1)
          end
        end
      end
    end

    private def self._vfunc_measure(this : Pointer(Void), lib_widget : Pointer(Void), lib_orientation : UInt32,
                                    lib_for_size : Int32, lib_minimum : Pointer(Int32), lib_natural : Pointer(Int32),
                                    lib_minimum_baseline : Pointer(Int32), lib_natural_baseline : Pointer(Int32)) : Void
      layout = Layout.new(this, :none)
      desktop = Desktop::Widget.new(lib_widget, :none)

      place_holder = desktop.place_holder
      if place_holder && desktop.empty?
        LibGtk.gtk_widget_measure(place_holder, lib_orientation, -1, lib_minimum, lib_natural, nil, nil)
      else
        nullptr = Pointer(Int32).null
        if lib_orientation == 0
          LibGtk.gtk_widget_measure(desktop.switcher, 0, -1, nullptr, pointerof(layout.@switcher_width), nullptr, nullptr)
        else
          LibGtk.gtk_widget_measure(desktop.switcher, 1, -1, nullptr, pointerof(layout.@switcher_height), nullptr, nullptr)
        end
      end

      lib_minimum_baseline.value = -1
      lib_natural_baseline.value = -1
    end

    def self._class_init(type_struct : Pointer(LibGObject::TypeClass), user_data : Pointer(Void)) : Nil
      vfunc_ptr = (type_struct.as(Pointer(Void)) + 144).as(Pointer(Pointer(Void)))
      vfunc_ptr.value = (->_vfunc_measure(Pointer(Void), Pointer(Void), UInt32, Int32, Pointer(Int32), Pointer(Int32), Pointer(Int32), Pointer(Int32))).pointer
      previous_def
    end
  end
end
