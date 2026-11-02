cask "gitmorning" do
  version "0.3.0,3"
  sha256 "26a44181ffafd7f96fa4d4c0696981abf360137ebffe32ab45d41791bbf6a1e9"

  url "https://github.com/ddingddong9/homebrew-gitmorning/releases/download/v#{version.csv.first}/GitMorning-#{version.csv.first}-arm64.zip"
  name "GitMorning"
  desc "Read GitHub Trending with free on-device Korean summaries"
  homepage "https://github.com/ddingddong9/homebrew-gitmorning"

  livecheck do
    url "https://github.com/ddingddong9/homebrew-gitmorning/releases/latest/download/appcast.xml"
    strategy :sparkle
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "GitMorning.app"
  uninstall quit: "dev.gitmorning.prototype"

  caveats <<~EOS
    On-device summaries require macOS 26+ and enabled Apple Intelligence.
    Free preview builds are ad-hoc signed and may require macOS approval at first launch.
  EOS
end
