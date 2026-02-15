// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Watchdog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Watchdog", targets: ["Watchdog"])
    ],
    targets: [
        .executableTarget(
            name: "Watchdog",
            path: "Watchdog",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("StoreKit"),
                .linkedFramework("AVKit")
            ]
        )
    ]
)
