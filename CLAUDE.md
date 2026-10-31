# Working on ScreenReview

- The module imports UIKit and SwiftUI only (`scripts/check-layers.sh`); no service's code. A service plugs in as a `ReviewDestination` in its own package (worp's is `WorpReview` in chanhyeok-made/swdid-worp).
- Everything a comment says is read from the app with no code in it; `ScreenReview.state` and `reviewName` stay optional.
- Every number that is a choice goes in `ReviewOptions`, with a line on why.
- Tests run on an iOS Simulator (`xcodebuild test -scheme ScreenReview`); CI runs them and the layer check.
- Tag a version (semver) after each merged change that apps should take; apps pin it with SwiftPM.
