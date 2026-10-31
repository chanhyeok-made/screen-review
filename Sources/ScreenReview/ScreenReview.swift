#if os(iOS)
import UIKit

/// Comments pinned to an app's own views, for whoever fixes them. An app starts it once, in the
/// builds people review:
///
///     #if DEBUG
///     ScreenReview.start(to: ShareDestination())
///     #endif
///
/// Fingers held still (`ReviewOptions.fingers`, `hold`) open the review layer over the app
/// (ReviewLayer.swift). A tap picks the smallest thing under the finger, the chips below widen it,
/// 코멘트 asks for a line, and the comment goes to the destination with what the app itself shows: the element, the
/// screens (tab, navigation, sheets), the window's state, the app's own SwiftUI view types and a
/// picture (ReviewReader.swift, ReviewContext.swift). Nothing else in the app is needed. Where it
/// goes is the destination's: the share sheet, a service such as worp (WorpReview), or the app's own.
///
/// It imports UIKit and SwiftUI only (scripts/check-layers.sh), so any app can link it.
@MainActor
public enum ScreenReview {
    private static var watch: NSObjectProtocol?
    static var options = ReviewOptions()
    static var destination: ReviewDestination?

    /// The app's own word on its state when a comment is left (its layout, a mode, what is open),
    /// asked once per comment. Optional: everything else is read without it.
    public static var state: (@MainActor () -> [String: String])?

    public static func start(to destination: ReviewDestination, options: ReviewOptions = ReviewOptions()) {
        self.destination = destination
        self.options = options
        guard watch == nil else { return }
        watch = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated { if let window = note.object as? UIWindow { install(window) } }
        }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.windows.forEach(install)
        }
    }

    /// The hold on one of the app's windows, once each.
    static func install(_ window: UIWindow) {
        guard !(window is ReviewWindow), !(window.gestureRecognizers ?? []).contains(where: { $0 is ReviewHold }) else { return }
        let hold = ReviewHold(target: ReviewOpener.shared, action: #selector(ReviewOpener.held(_:)))
        hold.numberOfTouchesRequired = options.fingers
        hold.minimumPressDuration = options.hold
        hold.cancelsTouchesInView = false
        hold.delegate = ReviewOpener.shared
        window.addGestureRecognizer(hold)
        ReviewPosture.probe(in: window)
    }
}

/// The hold that opens the layer, told apart from the app's own recognizers.
final class ReviewHold: UILongPressGestureRecognizer {}

/// Opens the layer over the window held. The hold runs beside the app's own gestures and takes
/// no touch from them, so a pinch or a two-finger scroll works as before; only the fingers kept
/// still for `hold` open it.
@MainActor
final class ReviewOpener: NSObject, UIGestureRecognizerDelegate {
    static let shared = ReviewOpener()

    @objc func held(_ hold: UILongPressGestureRecognizer) {
        guard hold.state == .began, let window = hold.view as? UIWindow, let destination = ScreenReview.destination else { return }
        ReviewLayer.open(over: window, to: destination, options: ScreenReview.options)
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
#endif
