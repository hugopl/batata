# The drop down terminal needs the Batata GNOME Shell extension, this asks the user to enable it when it's
# installed but disabled.
module ShellExtension
  UUID = "batata@hugopl.github.io"

  private SHELL_BUS_NAME  = "org.gnome.Shell"
  private SHELL_PATH      = "/org/gnome/Shell"
  private SHELL_INTERFACE = "org.gnome.Shell.Extensions"
  private TIMEOUT_MS      = 5000

  def self.ask_to_enable(window : Gtk::Window, settings : Gio::Settings) : Nil
    return unless settings.boolean("ask-to-enable-extension")

    connection = window.application.try(&.dbus_connection)
    return if connection.nil?

    params = GLib::Variant.parse("('#{UUID}',)")
    reply_type = GLib::VariantType.new("(a{sv})")
    connection.call(SHELL_BUS_NAME, SHELL_PATH, SHELL_INTERFACE, "GetExtensionInfo", params, reply_type,
      :none, TIMEOUT_MS, nil) do |_obj, result|
      info = connection.call_finish(result).child_value(0)
      # The Shell returns no uuid for unknown extensions, i.e. not installed or installed after the Shell started.
      next if info.lookup_value("uuid", "s").nil?

      enabled = info.lookup_value("enabled", "b").try(&.as_bool)
      show_dialog(window, settings, connection) if enabled == false
    rescue ex
      # Not running on GNOME Shell.
      Log.debug { "Can't get GNOME Shell extension info: #{ex.message}" }
    end
  end

  private def self.show_dialog(window : Gtk::Window, settings : Gio::Settings, connection : Gio::DBusConnection) : Nil
    dialog = Adw::AlertDialog.new("Enable Drop Down Terminal?",
      "The Batata GNOME Shell extension is installed but disabled, enable it to show Batata as a " \
      "drop down terminal using F12.")
    dialog.add_response("never", "Don't Ask Again")
    dialog.add_response("later", "Not Now")
    dialog.add_response("enable", "Enable")
    dialog.set_response_appearance("enable", :suggested)
    dialog.default_response = "enable"
    dialog.close_response = "later"
    dialog.choose(window, nil) do |_dialog, result|
      case dialog.choose_finish(result)
      when "enable" then enable(connection)
      when "never"  then settings.set_boolean("ask-to-enable-extension", false)
      end
    end
  end

  private def self.enable(connection : Gio::DBusConnection) : Nil
    params = GLib::Variant.parse("('#{UUID}',)")
    connection.call(SHELL_BUS_NAME, SHELL_PATH, SHELL_INTERFACE, "EnableExtension", params,
      GLib::VariantType.new("(b)"), :none, TIMEOUT_MS, nil) do |_obj, result|
      enabled = connection.call_finish(result).child_value(0).as_bool
      Log.error { "GNOME Shell refused to enable the #{UUID} extension." } unless enabled
    rescue ex
      Log.error(exception: ex) { "Failed to enable the #{UUID} GNOME Shell extension: #{ex.message}" }
    end
  end
end
