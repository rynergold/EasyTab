cask "easytab" do
  version "1.2.0"
  sha256 "e3592ee80a7dbde0be311694e4eae79d9667e1c2dbfec619fb0e3d283f7e761e"

  url "https://github.com/rynergold/homebrew-easytab/releases/download/v#{version}/EasyTab.zip"
  name "EasyTab"
  desc "Fast, lightweight Command+Tab window switcher for macOS"
  homepage "https://github.com/rynergold/homebrew-easytab"

  depends_on macos: :ventura

  app "EasyTab.app"

  zap trash: [
    "~/Library/Preferences/com.open.easytab.plist",
  ]
end
