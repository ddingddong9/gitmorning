cask "gitmorning" do
  version "0.5.5,10"
  sha256 "339bb185a830a42ac28376b55401b7b0357bb621ddfae66a49f8ae09b7d84f61"

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
  depends_on macos: :sonoma

  app "GitMorning.app"
  uninstall quit: "dev.gitmorning.prototype"

  caveats <<~EOS
    On-device summaries require macOS 26+ and enabled Apple Intelligence.
    Free preview builds are ad-hoc signed and may require macOS approval at first launch.
  EOS
end
