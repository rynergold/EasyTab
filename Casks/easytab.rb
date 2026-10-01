cask "easytab" do
  version "1.0.0"
  sha256 "9c08141c8604ece1a278f7bf0862e2131d61db88d39b8982cad2146b199cd742"

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
