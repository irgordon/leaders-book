// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LeadersBookCore",
    platforms: [.macOS(.v14), .iOS(.v26)],
    products: [.library(name: "LeadersBookCore", targets: ["LeadersBookCore"])],
    targets: [
        .target(name: "LeadersBookCore", path: "LeadersBook", exclude: ["App", "Views"],
                sources: ["Core"], resources: [.process("Resources")]),
        .testTarget(name: "LeadersBookCoreTests", dependencies: ["LeadersBookCore"],
                    path: "Tests/LeadersBookCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
