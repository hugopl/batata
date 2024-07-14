require "json"

struct Gdk::RGBA
  def self.new(pull : JSON::PullParser)
    rgba = Gdk::RGBA.new
    color_string = pull.read_string
    rgba.parse(color_string) || raise ArgumentError.new("Invalid Color #{color_string}")
    rgba
  end

  def brightness : Float32
    ((red * 299) + (green * 587) + (blue * 114)) / 1000
  end
end

class Theme
  include JSON::Serializable

  getter name : String
  getter comment : String
  @[JSON::Field(key: "foreground-color")]
  getter foreground_color : Gdk::RGBA
  @[JSON::Field(key: "background-color")]
  getter background_color : Gdk::RGBA

  getter palette : Array(Gdk::RGBA)

  def dark? : Bool
    @foreground_color.brightness > 0.5
  end

  def self.from_file(path : String)
    from_json(File.read(path))
  end

  {% for color, index in %w(background red green yellow blue purple cyan
                           foreground light_background light_red light_green
                           light_yellow light_blue light_purple light_cyan
                           light_foreground) %}
    def {{color.id}} : String
      @palette[{{index}}].to_string
    end
  {% end %}
end
