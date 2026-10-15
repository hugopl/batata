@[Gtk::UiTemplate(file: "#{__DIR__}/preferences_dialog.ui", children: %w(custom-font theme scrollback-lines login-shell exit-action bright-colors select-custom-font show-help-terminal dropdown-monitor dropdown-shortcut))]
class PreferencesDialog < Adw::PreferencesDialog
  include Gtk::WidgetTemplate

  @settings : Gio::Settings
  @custom_font_row : Adw::ActionRow

  def initialize(@settings)
    super()

    @custom_font_row = Adw::ActionRow.cast(template_child("select-custom-font"))
    @custom_font_row.activated_signal.connect(->on_select_custom_font(Adw::ActionRow))

    bind_properties_to_settings
  end

  private def bind_properties_to_settings
    # Text
    widget = Adw::ExpanderRow.cast(template_child("custom-font"))
    @settings.bind("custom-font", widget, "enable-expansion", :default)
    @settings.bind("font", @custom_font_row, "title", :default)

    theme_widget = Adw::ComboRow.cast(template_child("theme"))
    themes = ThemeProvider.default.theme_names
    theme_widget.model = Gtk::StringList.new(strings: ThemeProvider.default.theme_names)
    theme_widget.selected = (themes.index(@settings.string("theme")) || 0).to_u32
    theme_widget.notify_signal["selected"].connect do
      @settings.set_string("theme", themes[theme_widget.selected])
    end

    widget = Adw::SwitchRow.cast(template_child("bright-colors"))
    @settings.bind("bright-colors-for-bold", widget, "active", :default)

    # Scrolling
    widget = Adw::SpinRow.cast(template_child("scrollback-lines"))
    @settings.bind("scrollback-lines", widget, "value", :default)

    # Command
    widget = Adw::SwitchRow.cast(template_child("login-shell"))
    @settings.bind("login-shell", widget, "active", :default)
    widget = Adw::ComboRow.cast(template_child("exit-action"))
    @settings.bind("exit-action", widget, "selected", :default)

    # Startup
    widget = Adw::SwitchRow.cast(template_child("show-help-terminal"))
    @settings.bind("show-help-terminal", widget, "active", :default)

    # Drop down terminal
    setup_dropdown_monitor_row
    setup_dropdown_shortcut_row
  end

  private def setup_dropdown_monitor_row
    labels = ["Primary monitor", "Monitor under the mouse pointer"]
    values = ["primary", "pointer"]
    if display = Gdk::Display.default
      monitors = display.monitors
      monitors.n_items.times do |i|
        monitor = Gdk::Monitor.cast(monitors.item(i))
        connector = monitor.connector
        next if connector.nil?

        name = monitor.description || monitor.model
        labels << (name ? "#{name} (#{connector})" : connector)
        values << connector
      end
    end

    # Keep a monitor that isn't plugged right now selected.
    current = @settings.string("dropdown-monitor")
    unless values.includes?(current)
      labels << "#{current} (disconnected)"
      values << current
    end

    row = Adw::ComboRow.cast(template_child("dropdown-monitor"))
    row.model = Gtk::StringList.new(strings: labels)
    row.selected = values.index!(current).to_u32
    row.notify_signal["selected"].connect do
      @settings.set_string("dropdown-monitor", values[row.selected])
    end
  end

  private def setup_dropdown_shortcut_row
    row = Adw::EntryRow.cast(template_child("dropdown-shortcut"))
    row.text = @settings.strv("dropdown-shortcut").first? || ""
    row.apply_signal.connect do
      accel = row.text.strip
      if accel.empty?
        row.remove_css_class("error")
        @settings.set_strv("dropdown-shortcut", [] of String)
      elsif Gtk.accelerator_parse(accel)
        row.remove_css_class("error")
        @settings.set_strv("dropdown-shortcut", [accel])
      else
        row.add_css_class("error")
      end
    end
  end

  private def on_select_custom_font(row)
    current_font = Pango::FontDescription.from_string(@custom_font_row.title)
    # TODO: Only show monospace fonts.
    Gtk::FontDialog.new.choose_font(Gtk::Window.cast(root.not_nil!), current_font, nil) do |dialog, result|
      font_desc = dialog.as(Gtk::FontDialog).choose_font_finish(result)
      @custom_font_row.title = font_desc.to_string if font_desc
    rescue ex
      Log.error(exception: ex) { ex.message }
    end
  end
end
