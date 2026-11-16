// swift-tools-version:5.9
import PackageDescription

// ZoeKit: tutto ciò che l'app e i widget di ZOE condividono.
//  - ZoeCore:   logica pura (parser dei comandi, formati, modelli). Si testa anche da Terminale con `swift test`.
//  - ZoeUI:     la mascotte disegnata in SwiftUI.
//  - ZoeShared: dati condivisi tramite App Group, notifiche locali, Live Activity.
let package = Package(
    name: "ZoeKit",
    defaultLocalization: "it",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ZoeCore", targets: ["ZoeCore"]),
        .library(name: "ZoeUI", targets: ["ZoeUI"]),
        .library(name: "ZoeShared", targets: ["ZoeShared"]),
    ],
    targets: [
        .target(name: "ZoeCore"),
        .target(name: "ZoeUI", dependencies: ["ZoeCore"]),
        .target(name: "ZoeShared", dependencies: ["ZoeCore"]),
        .testTarget(name: "ZoeCoreTests", dependencies: ["ZoeCore"]),
    ]
)
