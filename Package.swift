// swift-tools-version:5.9
import PackageDescription

// This package only exists so the platform-independent logic in VehicleCare/Core can be
// tested from the command line with `swift test`. The app itself is built by VehicleCare.xcodeproj.
// There are no external dependencies.
let package = Package(
    name: "VehicleCareCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "Core", targets: ["Core"])],
    targets: [
        .target(name: "Core", path: "VehicleCare/Core"),
        .testTarget(name: "CoreTests", dependencies: ["Core"], path: "Tests/CoreTests"),
    ]
)
