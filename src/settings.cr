class Settings
  def self.default : Gio::Settings
    @@settings ||= Gio::Settings.new(APPLICATION_ID)
  end
end
