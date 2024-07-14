@[Gtk::UiTemplate(file: "#{__DIR__}/preferences_dialog.ui", children: %w(custom-font theme scrollback-lines login-shell exit-action bright-colors select-custom-font show-help-terminal))]
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
