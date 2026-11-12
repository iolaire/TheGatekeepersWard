// swift-tools-version: 5.9
import Foundation
import PackageDescription

// The Command Line Tools toolchain bundles swift-testing's macro plugin but
// SwiftPM does not auto-load it, so tests need it passed explicitly. Full Xcode
// finds the plugin on its own, so only pass the flag where the file exists.
let commandLineToolsTestingMacros =
    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
let testingPluginFlags: [String] = FileManager.default.fileExists(atPath: commandLineToolsTestingMacros)
    ? ["-load-plugin-library", commandLineToolsTestingMacros]
    : []

let package = Package(
    name: "GatekeepersWard",
    platforms: [.macOS(.v13)],
    targets: [
        // Main library: Core/, Permissions/, HUD/, MenuBar/ sources.
        .target(
            name: "GatekeepersWard",
            path: "GatekeepersWard",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency=complete")]
        ),
        // The menu bar app. A thin launcher; wrapped into an .app bundle by
        // scripts/run_ward.sh.
        .executableTarget(
            name: "GatekeepersWardApp",
            dependencies: ["GatekeepersWard"],
            path: "GatekeepersWardApp",
            exclude: ["Info.plist"]
        ),
        // Standalone TCC trigger CLI with an embedded bundle identifier so
        // `tccutil reset` can scope decisions to com.gatekeepersward.ward-trigger.
        .executableTarget(
            name: "WardTrigger",
            dependencies: ["GatekeepersWard"],
            path: "WardTrigger",
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
                    "-Xlinker", "WardTrigger/Info.plist",
                ])
            ]
        ),
        .testTarget(
            name: "GatekeepersWardTests",
            dependencies: ["GatekeepersWard", "WardTrigger"],
            path: "GatekeepersWardTests",
            exclude: ["WardTrigger/README.md"],
            swiftSettings: testingPluginFlags.isEmpty ? [] : [.unsafeFlags(testingPluginFlags)]
        ),
    ],
    // Tools version 5.9 has no `.v6` shorthand; `.version("6")` is the same mode.
    swiftLanguageVersions: [.version("6")]
)
