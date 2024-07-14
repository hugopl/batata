require "./theme_provider"

enum ExitAction
  Close
  Restart
  Hold
end

class Terminal < Desktop::Item
  @term = Vte::Terminal.new(allow_hyperlink: true, audible_bell: false, vexpand: true, hexpand: true)
  @copy_action = Gio::SimpleAction.new("copy", nil)
  @copy_html_action = Gio::SimpleAction.new("copy_html", nil)
  @context_menu : Gtk::PopoverMenu?
  @settings : Gio::Settings

  def initialize(@settings : Gio::Settings, message : String? = nil, current_working_directory : String? = nil)
    super()

    setup_ui
    setup_term(current_working_directory)
    setup_actions
    setup_controllers

    @term.feed(message) if message
  end

  private def setup_ui
    hbox = Gtk::Box.new(spacing: 3)
    hbox.add_css_class("header")
    label = Gtk::Label.new(hexpand: true)
    @term.bind_property("window-title", label, "label", :default)
    @term.bind_property("window-title", self, "title", :default)

    stack_icon = Gtk::Image.new_from_icon_name("batata-stack-symbolic")
    stack_size_label = Gtk::Label.new
    bind_property("stack-size", stack_size_label, "label", :default)
    hbox.append(stack_icon)
    hbox.append(stack_size_label)

    maximize_icon = Gtk::Image.new_from_icon_name("view-fullscreen-symbolic")
    maximize_icon.visible = false
    bind_property("maximized", maximize_icon, "visible", :default)
    hbox.append(maximize_icon)

    hbox.append(label)
    append(hbox)

    apply_themming
  end

  private def setup_term(current_working_directory : String?)
    load_settings

    @term.child_exited_signal.connect(->(_code : Int32) { on_close })
    @term.hyperlink_hover_uri_changed_signal.connect(->on_hyperlink_hover_uri_changed(String?, Gdk::Rectangle?))
    @term.selection_changed_signal.connect(->on_selection_changed)
    @term.parent = self

    spawn_shell(current_working_directory)

    @settings.changed_signal.connect { load_settings }
    Adw::StyleManager.default.notify_signal["dark"].connect { apply_themming }
  end

  private def load_settings
    @term.scrollback_lines = @settings.int("scrollback-lines")
    @term.bold_is_bright = @settings.boolean("bright-colors-for-bold")
    @term.font_desc = Pango::FontDescription.from_string(@settings.string("font")) if @settings.boolean("custom-font")
    apply_themming
  end

  private def setup_actions
    group = Gio::SimpleActionGroup.new

    @copy_action.activate_signal.connect(->on_copy(GLib::Variant?))
    @copy_action.enabled = false
    group.add_action(@copy_action)
    @copy_html_action.activate_signal.connect(->on_copy_html(GLib::Variant?))
    @copy_html_action.enabled = false
    group.add_action(@copy_html_action)

    action = Gio::PropertyAction.new(name: "readonly", object: @term, property_name: "input-enabled", invert_boolean: true)
    group.add_action(action)

    actions = { {"paste", nil, ->on_paste(GLib::Variant)},
               {"select_all", nil, ->on_select_all(GLib::Variant)},
               {"open_uri", "s", ->on_open_uri(GLib::Variant)},
               {"copy_uri", "s", ->on_copy_uri(GLib::Variant)} }
    actions.each do |(name, param_type, closure)|
      variant_type = GLib::VariantType.new(param_type) if param_type
      action = Gio::SimpleAction.new(name, variant_type)
      action.activate_signal.connect(closure)
      group.add_action(action)
    end

    insert_action_group("terminal", group)
  end

  private def setup_controllers
    shortcuts = {"terminal.copy":  "<Ctrl><Shift>c",
                 "terminal.paste": "<Ctrl><Shift>v"}

    controller = Gtk::ShortcutController.new(propagation_phase: :capture)
    shortcuts.each do |action, accel|
      action = Gtk::ShortcutAction.parse_string("action(#{action})")
      trigger = Gtk::ShortcutTrigger.parse_string(accel)
      shortcut = Gtk::Shortcut.new(action: action, trigger: trigger)
      controller.add_shortcut(shortcut)
    end
    add_controller(controller)

    controller = Gtk::GestureClick.new(button: Gdk::BUTTON_SECONDARY.to_u32, propagation_phase: :capture)
    controller.pressed_signal.connect(->on_context_menu(Gtk::GestureClick, Int32, Float64, Float64))
    @term.add_controller(controller)

    controller = Gtk::GestureClick.new(button: Gdk::BUTTON_PRIMARY.to_u32, propagation_phase: :capture)
    controller.pressed_signal.connect(->on_left_click(Gtk::GestureClick, Int32, Float64, Float64))
    @term.add_controller(controller)
  end

  private def spawn_shell(working_directory : String?)
    shell = Vte.user_shell.to_s
    argv0 = @settings.boolean("login-shell") ? "-#{shell}" : shell

    @term.spawn_async(
      pty_flags: :default,
      working_directory: working_directory,
      argv: [shell, argv0],
      envv: nil,
      spawn_flags: :file_and_argv_zero,
      child_setup: nil,
      child_setup_data: nil,
      child_setup_data_destroy: nil,
      timeout: -1,
      cancellable: nil,
      callback: nil,
      user_data: nil
    )
  end

  def current_directory_uri : String
    @term.termprop_string(Vte::TERMPROP_CURRENT_DIRECTORY_URI) || "?"
  end

  private def on_hyperlink_hover_uri_changed(uri : String?, _bbox : Gdk::Rectangle?)
    return unless @term.realized

    uri = "💥 Invalid UTF-8 URI 💥" if uri && !uri.valid_encoding?
    @term.tooltip_text = uri
  end

  def on_close : Bool
    case ExitAction.from_value(@settings.int("exit-action"))
    in .close?
      activate_action("desktop.close_view", nil)
    in .restart?
      spawn_shell(nil)
    in .hold?
      nil
    end
    true
  end

  def on_copy(_variant : GLib::Variant?) : Bool
    @term.copy_clipboard_format(:text)
    true
  end

  def on_copy_html(_variant : GLib::Variant?) : Bool
    @term.copy_clipboard_format(:html)
    true
  end

  def on_paste(_variant : GLib::Variant) : Bool
    Gdk::Display.default!.clipboard.read_text_async(nil) do |clipboard, result|
      text = Gdk::Clipboard.cast(clipboard).read_text_finish(result)
      @term.paste_text(text) if text
    end
    true
  end

  def on_selection_changed
    has_selection = @term.has_selection
    @copy_action.enabled = has_selection
    @copy_html_action.enabled = has_selection
  end

  def on_select_all(_variant : GLib::Variant) : Bool
    @term.select_all
    true
  end

  def on_open_uri(variant : GLib::Variant) : Bool
    open_uri(variant.as_s)
  end

  def on_copy_uri(variant : GLib::Variant) : Bool
    Gdk::Display.default!.clipboard.text = variant.as_s
    true
  end

  def on_context_menu(gesture : Gtk::GestureClick, _n : Int32, x : Float64, y : Float64) : Bool
    popover = context_menu(x, y)
    popover.pointing_to = Gdk::Rectangle.new(x.to_i32, y.to_i32, 0, 0)
    popover.popup
    gesture.state = :claimed
    true
  end

  def context_menu(x : Float64, y : Float64) : Gtk::PopoverMenu
    uri = @term.check_hyperlink_at(x, y)
    menu = Gio::Menu.new
    if uri
      uri_menu = Gio::Menu.new
      uri_menu.append("Open Hyperlink", "terminal.open_uri('#{uri}')")
      uri_menu.append("Copy Hyperlink", "terminal.copy_uri('#{uri}')")
      menu.append_section(nil, uri_menu)
    end

    copy_paste_menu = Gio::Menu.new
    copy_paste_menu.append("Copy", "terminal.copy")
    copy_paste_menu.append("Copy HTML", "terminal.copy_html")
    copy_paste_menu.append("Paste", "terminal.paste")
    copy_paste_menu.append("Select All", "terminal.select_all")
    menu.append_section(nil, copy_paste_menu)

    other = Gio::Menu.new
    other.append("Readonly", "terminal.readonly")
    other.append("Preferences", "win.preferences")
    menu.append_section(nil, other)

    about = Gio::Menu.new
    about.append("About", "win.about")
    menu.append_section(nil, about)

    popover = Gtk::PopoverMenu.new(menu_model: menu, has_arrow: false, position: :bottom, halign: :start)
    popover.parent = self
    popover
  end

  def on_left_click(gesture : Gtk::GestureClick, _n : Int32, x : Float64, y : Float64) : Bool
    modifier = gesture.current_event_state
    return false unless modifier.control_mask?

    uri = @term.check_hyperlink_at(x, y)
    return false if uri.nil?

    open_uri(uri)
  end

  private def on_readonly_changed(variant : GLib::Variant) : Bool
    readonly = variant.as_bool
    @term.input_enabled = !readonly
    true
  end

  private def apply_themming
    theme_name = @settings.string("theme")
    theme = ThemeProvider.default.theme(theme_name)

    @term.set_colors(
      theme.foreground_color,
      theme.background_color,
      theme.palette
    )
  end

  def zoom_in
    @term.font_scale += 0.1
  end

  def zoom_normal
    @term.font_scale = 1.0
  end

  def zoom_out
    @term.font_scale -= 0.1
  end

  private def open_uri(uri : String) : Bool
    file = Gio::File.new_for_uri(uri)
    Gtk::FileLauncher.new(file).launch(Gtk::Window.cast(root.not_nil!), nil) do |launcher, result|
      launcher.as(Gtk::FileLauncher).launch_finish(result)
    rescue e
      nil
    end
    true
  end

  @[GObject::Virtual]
  def grab_focus
    @term.grab_focus
  end
end
