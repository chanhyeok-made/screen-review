#if os(iOS)
import SwiftUI
import UIKit

/// A foldable iPhone's posture as the system tells it, kept for the next comment: the hinge (its
/// state and angle) and where the fold lies in the window. Only SwiftUI reads these (iOS 27.1
/// `onHingeChange`, a geometry's `reservedRegions(kind: .division)`), so a probe that draws nothing
/// and takes no touch sits under each window's content (ScreenReview.install). Other devices and
/// SDKs leave it empty.
@MainActor
final class ReviewPosture {
    static let shared = ReviewPosture()
    private(set) var facts: [String: String] = [:]

    func set(_ key: String, _ value: String?) { facts[key] = value }

    /// The probe for one window: a clear hosting view, hidden from accessibility and touches.
    static func probe(in window: UIWindow) {
        #if compiler(>=6.4)
        guard #available(iOS 27.1, *), !window.subviews.contains(where: { $0 is ProbeHost }) else { return }
        let host = ProbeHost(rootView: AnyView(PostureProbe()))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.accessibilityElementsHidden = true
        host.view.frame = window.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.insertSubview(host.view, at: 0)
        probes.append(host)
        #endif
    }

    private static var probes: [ProbeHost] = []
}

/// Told apart from the app's own hosting controllers.
final class ProbeHost: UIHostingController<AnyView> {}

#if compiler(>=6.4)
@available(iOS 27.1, *)
private struct PostureProbe: View {
    var body: some View {
        Color.clear.ignoresSafeArea()
            // Flat, the fold is inactive and still has a place: ask for inactive ones too.
            .onGeometryChange(for: CGRect?.self) { p in p.reservedRegions(kind: .division, options: [.includeInactive]).first?.frame } action: { fold in
                let n = { (v: CGFloat) in String(Int(v.rounded())) }
                ReviewPosture.shared.set("fold", fold.map { "\(n($0.minX)),\(n($0.minY)),\(n($0.width))x\(n($0.height))" })
            }
            .onHingeChange { _, new in
                ReviewPosture.shared.set("hinge", new.hinge.map { "\($0.status) \(Int($0.angle.degrees.rounded()))°" })
            }
    }
}
#endif
#endif
