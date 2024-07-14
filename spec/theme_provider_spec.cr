require "./spec_helper"
require "../src/theme_provider"

describe ThemeProvider do
  it "can group dark/light themes" do
    provider = ThemeProvider.new
    provider.theme?("Adwaita").should_not eq(nil)
  end
end
