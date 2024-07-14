require "./theme"

class ThemeProvider
  @themes : Hash(String, NamedTuple(light: Theme, dark: Theme))

  def initialize
    super

    @themes = load_themes
  end

  def self.default
    @@default ||= ThemeProvider.new
  end

  private def load_themes
    themes = Hash(String, NamedTuple(light: Theme, dark: Theme)).new
    themes_lookup_dirs.each do |dir|
      next unless Dir.exists?(dir)

      grouped_themes = Dir["#{dir}/*.json"].group_by(&.gsub(/-(dark|light)\.json/, ""))
      grouped_themes.each_value do |(theme_file1, theme_file2)|
        theme1 = Theme.from_file(theme_file1)
        theme2 = Theme.from_file(theme_file2)
        theme1, theme2 = theme2, theme1 if theme1.dark?
        themes[theme1.name] = {light: theme1, dark: theme2}
      end
    end
    raise "No themes found, tried on #{themes_lookup_dirs}" if themes.empty?

    themes
  end

  def theme(name : String) : Theme
    theme?(name) || theme?("Adwaita").not_nil!
  end

  def theme?(name : String) : Theme?
    style_manager = Adw::StyleManager.default
    themes = @themes[name]?
    if themes.nil?
      Log.warn { "Theme #{name} not found." }
      return
    end

    style_manager.dark? ? themes[:dark] : themes[:light]
  end

  def theme_names : Array(String)
    @themes.keys
  end

  private def themes_lookup_dirs : Array(Path)
    exe_path = Process.executable_path || raise "Cannot find executable path"
    paths = [Path[exe_path, "../../share/batata/themes/"].expand]
    {% unless flag?(:release) %}
      paths << Path[__DIR__, "/../data/themes/"].expand
    {% end %}
    paths
  end
end
