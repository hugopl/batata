require "./spec_helper"
require "../src/theme"

describe Theme do
  it "can load all schemes" do
    schemes = Dir["#{__DIR__}/../data/themes/*.json"]
    schemes.size.should_not eq(0)
    schemes.each do |scheme_file|
      Theme.from_file(scheme_file)
    end
  end

  it "can identify dark schemes" do
    scheme = Theme.from_file("#{__DIR__}/../data/themes/adwaita-dark.json")
    scheme.dark?.should eq(true)
    scheme = Theme.from_file("#{__DIR__}/../data/themes/adwaita-light.json")
    scheme.dark?.should eq(false)
  end
end
