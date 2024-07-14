require "log"

module Desktop
  Log = ::Log.for(self)

  alias Orientation = Gtk::Orientation

  enum Direction
    Right
    Left
    Top
    Bottom

    def orientation : Gtk::Orientation
      case self
      in .right?, .left? then Gtk::Orientation::Horizontal
      in .top?, .bottom? then Gtk::Orientation::Vertical
      end
    end
  end

  # Gdk:Retangle binding is buggy.
  # alias Rectangle = Gdk::Rectangle
  struct Rectangle
    property x : Int32
    property y : Int32
    property width : Int32
    property height : Int32

    def initialize(@x = 0, @y = 0, @width = 0, @height = 0)
    end

    def interpolate(other : Rectangle, t : Float64)
      rect = Rectangle.new
      {% for i in %w(x y width height) %}
        rect.{{ i.id }} = @{{ i.id }} + ((other.{{ i.id }} - @{{ i.id }}) * t).to_i64
      {% end %}
      rect
    end

    def to_tuple
      {@x, @y, @width, @height}
    end

    def to_s(io : IO)
      io << @x << ',' << @y << ' ' << @width << 'x' << @height
    end
  end
end

require "./desktop/tab_view"
