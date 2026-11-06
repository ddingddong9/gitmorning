// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Explicitly restricted to local development when dependency downloads are unavailable.
let coreOnly = ProcessInfo.processInfo.environment["GITMORNING_CORE_ONLY"] == "1"
let localSparkle = ProcessInfo.processInfo.environment["GITMORNING_SPARKLE_XCFRAMEWORK"]
let sparkle: Target = localSparkle.map { .binaryTarget(name: "Sparkle", path: $0) }
    ?? .binaryTarget(name: "Sparkle", url: "https://github.com/sparkle-project/Sparkle/releases/download/2.10.1/Sparkle-for-Swift-Package-Manager.zip", checksum: "4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a")

let package = Package(
    name: "GitMorning",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "GitMorning", targets: ["GitMorning"])],
    targets: [
        .target(name: "GitMorningCore"),
        .executableTarget(name: "GitMorning", dependencies: coreOnly ? ["GitMorningCore"] : ["GitMorningCore", "Sparkle"], resources: [.copy("Resources/Snapshots"), .copy("Resources/Korean.json")], swiftSettings: coreOnly ? [] : [.define("GITMORNING_WITH_SPARKLE")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "GitMorningCoreTests", dependencies: ["GitMorningCore"])
    ] + (coreOnly ? [] : [sparkle])
)
