// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartwinnrCapacitorDaily",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "SmartwinnrCapacitorDaily",
            targets: ["SmartWinnrDailyPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", branch: "main"),
        .package(url: "https://github.com/daily-co/daily-client-ios.git", from: "0.21.0")
    ],
    targets: [
        .target(
            name: "SmartWinnrDailyPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/SmartWinnrDailyPlugin"),
        .testTarget(
            name: "SmartWinnrDailyPluginTests",
            dependencies: ["SmartWinnrDailyPlugin"],
            path: "ios/Tests/SmartWinnrDailyPluginTests")
    ]
)