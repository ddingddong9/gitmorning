cask "gitmorning" do
  version "0.4.0,4"
  sha256 "aecc64fa095cd8f47895dabe3eae201dd164fdbc01aa5c27ca0d3903f0fd99e1"

  url "https://github.com/ddingddong9/gitmorning/releases/download/v#{version.csv.first}/GitMorning-#{version.csv.first}-arm64.zip"
  name "GitMorning"
  desc "Explore GitHub Trending and read original descriptions"
  homepage "https://github.com/ddingddong9/gitmorning"

  livecheck do
    url "https://github.com/ddingddong9/gitmorning/releases/latest/download/appcast.xml"
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
