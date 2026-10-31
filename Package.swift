// swift-tools-version:5.9
import PackageDescription

// ScreenReview: a review mode any iOS app links. Fingers held open a layer over the app; a tap
// picks a part of a screen and a line goes, with what the app itself shows, to a destination.
// UIKit and SwiftUI only (scripts/check-layers.sh).
let package = Package(
    name: "ScreenReview",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ScreenReview", targets: ["ScreenReview"]),
    ],
    targets: [
        .target(name: "ScreenReview"),
        .testTarget(name: "ScreenReviewTests", dependencies: ["ScreenReview"]),
    ]
)
