# ScreenReview

A review mode for iOS apps. Add it to a debug or TestFlight build and anyone reviewing the app can point at any part of a screen and leave a one-line comment. The comment carries what someone fixing it needs: which screen it was on, which code draws it, the device's state and pictures. All of that is read from the app itself, so the app needs no code beyond one line.

Where comments go is up to you. They can go to the share sheet (the default), to a service such as [worp](https://worp.sh) (its `WorpReview` destination hands them to an agent on a Mac), or to your own tracker.

## Add it

```swift
// Package.swift
.package(url: "https://github.com/chanhyeok-made/screen-review", from: "0.1.0")
// target: .product(name: "ScreenReview", package: "screen-review")
```

```swift
import ScreenReview

// in the app delegate's didFinishLaunching, or the App's init
#if DEBUG
ScreenReview.start(to: ShareDestination())
#endif
```

iOS 17 or later. The foldable's posture is read when the app is built with the iOS 27.1 SDK.

## Use it

- **Open:** hold two fingers still for 0.6 s. In the Simulator, hold ⌥ and press and hold. The hold runs beside the app's own gestures, so a pinch or a two-finger scroll works as before. If two fingers are taken, set `ReviewOptions.fingers`.
- **Pick:** a tap picks the smallest thing under the finger. The chips at the bottom show the way out from it, for example `카드 › 버튼 › 회의 준비`. Slide a finger along the chips and the outline follows; lift to pick that one. Tap inside what is picked to go one level in, as in Figma.
- **Comment:** press **코멘트**, write a line, then press **남기기**. The layer stays open for the next comment until you press **닫기**.

## What a comment carries

`ReviewComment`, all read without code in the app:

| field | what |
|---|---|
| `text` | the reviewer's line |
| `element` | role, traits, label, value, identifier, frame, its parents, and the app's own SwiftUI view types holding it (`Ikie.InboxScreen`). A part with no accessibility of its own, such as one text line inside a card read as a single button, comes as `role: "piece"` |
| `place` | the screen the way a person names it, from tab, navigation and sheet titles: `할 일 › 설정 › 시간대` |
| `screens` | every controller showing, from the window's root: `tab “할 일” 2/5`, `sheet medium`, each with its SwiftUI view types |
| `window` | window and screen size, safe area, size classes, text size, appearance, orientations, window count; on a foldable, whether it is folded, the hinge angle and the fold |
| `picture`, `whole` | a PNG around the picked part and a JPEG of the whole window, without the review layer |
| `appState` | what the app says about itself, if it sets `ScreenReview.state` (optional) |

Two optional extras:

- `view.reviewName("settings.save")` sets the accessibility identifier and records the file and line where it is written. A comment on that view, or on anything inside it, then carries `file` and `line`.
- `ScreenReview.state = { ["layout": "two pages"] }` adds facts only the app knows.

## Your own destination

```swift
@MainActor final class TrackerDestination: ReviewDestination {
    func send(_ comment: ReviewComment, from: UIViewController) async throws -> String {
        try await Tracker.post(comment)   // it is Codable
        return "Filed"                    // shown in the layer's bar
    }
}
```

A thrown error's `localizedDescription` is shown as it is, so phrase it for the reviewer.

## Privacy

The pictures are the app's own drawing, and secure fields draw as dots. Nothing leaves the device except through the destination you choose.

## Develop

- `scripts/check-layers.sh` checks that the module imports UIKit and SwiftUI only.
- Run the tests on an iOS Simulator: `xcodebuild test -scheme ScreenReview -destination 'platform=iOS Simulator,name=iPhone 16'`.

## License

MIT, see [LICENSE](LICENSE).
