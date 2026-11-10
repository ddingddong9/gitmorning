cask "gitmorning" do
  version "0.5.7,12"
  sha256 "2c5e597d64436ae9504bb587395d5657485a43cd85608f79441aca0616f12f11"

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

  # GitMorning is ad-hoc signed, not notarized, so macOS would block the first launch of the
  # downloaded app. The archive was already checked against sha256 above. -dr is recursive so
  # Sparkle's nested helpers (Updater.app, Installer.xpc, Downloader.xpc) can start too.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/GitMorning.app"]
  end

  uninstall quit: "dev.gitmorning.prototype"

  caveats <<~EOS
    On-device summaries require macOS 26+ and enabled Apple Intelligence.
    GitMorning is not notarized by Apple; this cask clears the download quarantine after install.
  EOS
end
