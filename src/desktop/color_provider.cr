module Desktop
  class ColorProvider
    COLORS = {"var(--accent-blue)",
              "var(--accent-green)",
              "var(--accent-orange)",
              "var(--accent-pink)",
              "var(--accent-purple)",
              "var(--accent-red)",
              "var(--accent-slate)",
              "var(--accent-teal)",
              "var(--accent-yellow)"}
    N_COLORS = COLORS.size
    @next_color = 0

    def self.default
      @@default ||= ColorProvider.new
    end

    def initialize
      install_css
    end

    def aquire : String
      color = @next_color % N_COLORS
      @next_color += 1
      "color#{color}"
    end

    private def install_css
      css_provider = Gtk::CssProvider.new
      css_provider.load_from_string(generate_colors_css)
      Gtk::StyleContext.add_provider_for_display(Gdk::Display.default!,
        css_provider,
        Gtk::STYLE_PROVIDER_PRIORITY_USER.to_u32)
    end

    private def generate_colors_css : String
      String.build do |str|
        COLORS.each.with_index do |color, i|
          str << <<-CSS
            desktop item.selected.color#{i} vte-terminal {
              border-left: 1px solid #{color};
              border-right: 1px solid #{color};
              border-bottom: 1px solid #{color};
              padding: 0px;
            }

            desktop item.selected.color#{i} .header {
              background-color: #{color};
              color: @accent_fg_color;
            }

            desktop widget_switcher row .color#{i} {
              background-color: #{color};
            }

            CSS
        end
      end
    end
  end
end
