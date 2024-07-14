require "./desktop"
require "uri"
require "./terminal"
require "./settings"
require "./preferences_dialog"

class ApplicationWindow < Adw::ApplicationWindow
  @settings : Gio::Settings
  @tab_view : Desktop::TabView

  TERMINAL_HELP_MESSAGE = "                      \e[33m✧*̥˚ 🥔 *̥˚✧\e[0m\r\n\r\n" \
                          "  \e[32mAlt+Left\e[0m         Focus this left terminal stack.\r\n" \
                          "  \e[32mAlt+Arrow\e[0m        Focus stack at that direction.\r\ngitk" \
                          "  \e[32mAlt+Shift+Arrow\e[0m  Move terminals between stacks.\r\n\r\n" \
                          "  \e[32mCtrl+Shift+N\e[0m     Spawn a new terminal to the current stack.\r\n" \
                          "  \e[32mCtrl+,\e[0m           Open preferences.\r\n" \
                          "  \e[32mCtrl+Shift+?\e[0m     See all shortcuts.\r\n" \
                          "                   \e[33m⊱ ─── ⋅ʚ♡ɞ⋅ ─── ⊰\e[0m\r\n\r\n"

  def initialize(app : Adw::Application)
    super(title: "Batata", application: app, default_width: 1280, default_height: 720)

    @settings = Settings.default
    @tab_view = Desktop::TabView.new

    setup_ui(app)
    setup_actions(app)
  end

  private def setup_ui(app)
    box = Gtk::Box.new(orientation: :vertical, vexpand: true, hexpand: true)
    tab_bar = Adw::TabBar.new(view: @tab_view.tab_view)
    box.append(tab_bar)
    box.append(@tab_view)
    self.content = box

    @tab_view.last_item_removed_signal.connect(->on_last_item_removed)
    on_new_terminal(nil)
    if @settings.boolean("show-help-terminal")
      desktop = @tab_view.current_desktop_widget
      if desktop
        desktop.add_item(Terminal.new(@settings, TERMINAL_HELP_MESSAGE))
        desktop.move(:left)
        desktop.focus(:right)
      end
    end

    notify_signal["focus-widget"].connect(->on_focus_changed(GObject::ParamSpec))

    # Always start maximized, Comand was meant to be used that way.
    self.maximized = true
  end

  private def setup_actions(app)
    actions = {
      {"about", nil, ->show_about_dialog(GLib::Variant?)},
      {"preferences", "<Ctrl>comma", ->show_preferences_dialog(GLib::Variant?)},
      {"new-terminal", "<Ctrl><Shift>N", ->on_new_terminal(GLib::Variant?)},
      {"new-tab", "<Ctrl><Shift>T", ->on_new_tab(GLib::Variant?)},
      {"zoom-in", "<Ctrl>plus", ->on_zoom_in(GLib::Variant?)},
      {"zoom-normal", "<Ctrl>0", ->on_zoom_normal(GLib::Variant?)},
      {"zoom-out", "<Ctrl>minus", ->on_zoom_out(GLib::Variant?)},
    }
    actions.each do |(action_name, shortcut, callback)|
      action = Gio::SimpleAction.new(action_name, nil)
      action.activate_signal.connect(callback)
      add_action(action)
      app.set_accels_for_action("win.#{action_name}", {shortcut}) if shortcut
    end

    action = Gio::PropertyAction.new(name: "fullscreen",
      object: self,
      property_name: "fullscreened",
      invert_boolean: true)
    add_action(action)
    app.set_accels_for_action("win.fullscreen", {"F11"})
  end

  private def on_new_terminal(_variant : GLib::Variant?) : Nil
    @tab_view.add_item(spawn_terminal)
  end

  private def on_new_tab(_variant : GLib::Variant?) : Nil
    @tab_view.add_tab(spawn_terminal)
  end

  private def spawn_terminal : Terminal
    current_terminal = @tab_view.current_item.try(&.as?(Terminal))
    if current_terminal
      uri = current_terminal.current_directory_uri
      current_dir = URI.parse(uri).path if uri
    end
    Terminal.new(@settings, nil, current_dir)
  end

  private def on_focus_changed(_pspec)
    widget = self.focus_widget
    Log.debug { "focused widget: #{widget}" }
    if widget.is_a?(Vte::Terminal)
      @tab_view.current_node_changed(Desktop::Item.cast(widget.parent))
    end
  end

  private def on_last_item_removed
    dialog = Adw::AlertDialog.new("Quit Batata?", "The last open terminal was closed.")
    dialog.add_response("quit", "Quit")
    dialog.add_response("spawn", "Spawn another terminal")
    dialog.set_response_appearance("quit", :destructive)
    dialog.default_response = "quit"
    dialog.close_response = "spawn"
    dialog.choose(self, nil) do |_dialog, result|
      case dialog.choose_finish(result)
      when "quit"  then close
      when "spawn" then on_new_terminal(nil)
      end
    end
  end

  private def on_zoom_in(_variant : GLib::Variant?)
    @tab_view.each_item(&.as(Terminal).zoom_in)
  end

  private def on_zoom_normal(_variant : GLib::Variant?)
    @tab_view.each_item(&.as(Terminal).zoom_normal)
  end

  private def on_zoom_out(_variant : GLib::Variant?)
    @tab_view.each_item(&.as(Terminal).zoom_out)
  end

  private def show_preferences_dialog(_variant : GLib::Variant?)
    PreferencesDialog.new(@settings).present(self)
  end

  private def show_about_dialog(_variant : GLib::Variant?)
    Adw.show_about_window(parent: self, application: Adw::Application.cast(application),
      copyright: "© 2024-#{Time.local.year} Hugo Parente Lima",
      version: VERSION,
      application_name: "Batata",
      application_icon: "io.github.hugopl.Batata",
      comments: "An opinionated terminal emulator",
      website: "https://github.com/hugopl/batata",
      issue_url: "https://github.com/hugopl/batata/issues",
      license: LICENSE,
      developer_name: "Hugo Parente Lima <hugo.pl@gmail.com>",
      developers: {"Hugo Parente Lima <hugo.pl@gmail.com>"})
  end
end
