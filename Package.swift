// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GPUMonitor",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GPUMonitor",
            dependencies: ["SMCBridge"],
            path: "GPUMonitor",
            exclude: ["GPUMonitor/App/Info.plist"]
        ),
        .target(
            name: "SMCBridge",
            path: "CSMCBridge",
            publicHeadersPath: "include"
        )
    ]
)
