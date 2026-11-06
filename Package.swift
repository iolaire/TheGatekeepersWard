// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GatekeepersWard",
    platforms: [.macOS(.v13)],
    targets: [
        // Main library: Core/, Permissions/, HUD/, MenuBar/ sources.
        .target(name: "GatekeepersWard", path: "GatekeepersWard"),
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
            swiftSettings: [
                // The CommandLineTools toolchain bundles swift-testing's macro
                // plugin but SPM does not auto-load it; load it explicitly.
                .unsafeFlags([
                    "-load-plugin-library",
                    "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib",
                ])
            ]
        ),
    ]
)
