// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "device_health",
    platforms: [.iOS("15.0")],
    products: [.library(name: "device-health", targets: ["device_health"])],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "device_health",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
            linkerSettings: [.linkedFramework("HealthKit")]
        )
    ]
)
