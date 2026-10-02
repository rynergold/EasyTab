cask "easytab" do
  version "1.1.0"
  sha256 "52e13ce559a6bcf5504e5fd69be3cc6557e9c74219cf2dab3ad538b5f8e3ebbb"

  url "https://github.com/rynergold/EasyTab/releases/download/v#{version}/EasyTab.zip"
  name "EasyTab"
  desc "Fast, lightweight Command+Tab window switcher for macOS"
  homepage "https://github.com/rynergold/EasyTab"

  depends_on macos: ">= :ventura"

  app "EasyTab.app"

  zap trash: [
    "~/Library/Preferences/com.open.easytab.plist",
  ]
end
