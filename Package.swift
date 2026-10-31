// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "BridgeCore", platforms: [.macOS(.v13)], products: [.library(name: "BridgeCore", targets: ["BridgeCore"])], targets: [
    .target(name: "BridgeCore", path: "Sources/VeepooBridge", exclude: ["Assets.xcassets", "PrivacyInfo.xcprivacy", "BluetoothScanner.swift", "BridgeApp.swift", "HealthBridge.swift", "MeasurementStore.swift", "VeepooCapabilityProbe.swift", "VeepooSDKAdapter.swift"], sources: ["Measurement.swift", "VendorHistoryDecoder.swift"]),
    .testTarget(name: "BridgeCoreTests", dependencies: ["BridgeCore"])
])
