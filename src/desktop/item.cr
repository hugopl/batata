require "./color_provider"

module Desktop
  class Item < Gtk::Box
    @@next_id : Int32 = 0

    @id : Int32

    @[GObject::Property]
    property? maximized : Bool = false
    @[GObject::Property]
    property? selected : Bool = false
    @[GObject::Property]
    property title : String = ""
    @[GObject::Property]
    property stack_size = 1
    getter color : String = ""

    def initialize
      @id = @@next_id += 1
      super(hexpand: true, vexpand: true, orientation: :vertical, css_name: "item")
    end

    def self.reset_item_ids
      @@next_id = 0
    end

    def color=(color : String)
      remove_css_class(@color) unless @color.empty?
      add_css_class(color)
      @color = color
    end

    def maximized=(value : Bool)
      if value
        self.visible = true
        add_maximized_css
      else
        self.visible = false
        remove_maximized_css
      end
      previous_def
    end

    def selected=(value : Bool)
      if value
        add_selected_css
      else
        remove_selected_css
      end
      previous_def
    end

    {% for css_class in %w(selected maximized) %}
      private def add_{{ css_class.id }}_css
        add_css_class({{ css_class }})
      end

      private def remove_{{ css_class.id }}_css
        remove_css_class({{ css_class }})
      end
    {% end %}

    def to_s(io : IO)
      io << "Item" << @id
    end

    def inspect(io : IO)
      to_s(io)
    end
  end
end
