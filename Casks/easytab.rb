cask "easytab" do
  version "1.0.1"
  sha256 "b7acc9ed8197fd3038f0c678206a0df8fecb4db5ce46b289a21734827074fbca"

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
