require "libadwaita"
require "vte"
require "./log"
require "./monkey_patches"

require "./application_window"
require "./version"

APPLICATION_ID = "io.github.hugopl.Batata"
LICENSE        = {{ run("./macros/license.cr").stringify }}

{% if compare_versions("#{Adw::MAJOR_VERSION}.#{Adw::MINOR_VERSION}.0", "1.6.0") < 0 %}
{% raise "Adwaita version >=1.6.0 required" %}
{% end %}

macro not_implemented!
  puts {{ "#{@type.name}.#{@def.name} method not implemented!" }}
end

private def on_activate(app : Adw::Application)
  window = ApplicationWindow.new(app)
  window.present
end

private def on_handle_local_options(options : GLib::VariantDict) : Int32
  if options.remove("version")
    puts "Batata version #{VERSION} built with Crystal #{Crystal::VERSION}."
    return 0
  elsif options.remove("license")
    puts LICENSE.gsub(/<\/?(big|tt)>/, "")
    return 0
  end

  log_level = options.lookup_value("log-level", GLib::VariantType.new("s")).try(&.as_s?)
  setup_logger(log_level)

  -1
rescue e : ArgumentError
  STDERR.puts(e.message)
  0
end

def main : Int32
  Gio.register_resource("data/resources.xml", source_dir: "data")

  flags = Gio::ApplicationFlags::None
  {% unless flag?(:release) %}
    flags |= Gio::ApplicationFlags::NonUnique
  {% end %}

  app = Adw::Application.new(application_id: APPLICATION_ID, flags: flags)
  app.add_main_option("version", 0, :none, :none, "Show version information and exit", nil)
  app.add_main_option("license", 0, :none, :none, "Show license information and exit", nil)
  app.add_main_option("log-level", 0, :none, :string, "Log level to be used", nil)

  app.activate_signal.connect(->on_activate(Adw::Application))
  app.handle_local_options_signal.connect(->on_handle_local_options(GLib::VariantDict))
  app.run
rescue ex
  Log.error(exception: ex) { ex.message }
  Log.info { "Batata quiting due to #{ex.class.name} exception." }
  abort
end

exit(main)
