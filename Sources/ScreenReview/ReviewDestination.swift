#if os(iOS)
import UIKit

/// Where comments go. The review layer reads and asks; a destination only delivers: to the share
/// sheet (`ShareDestination`), to a service (worp's WorpReview), or anywhere an app plugs in.
@MainActor
public protocol ReviewDestination: AnyObject {
    /// Delivers one comment and returns the line the layer shows ("MacBook에 남겼어요").
    /// It may ask first from `from` (pairing, a share sheet). A thrown error's
    /// `localizedDescription` is shown as it is, so say it in the person's words.
    func send(_ comment: ReviewComment, from: UIViewController) async throws -> String
}

/// The plain destination: the share sheet, with the comment as text (and JSON) and its picture,
/// so a comment can go to a message, a note or a tracker with no service behind it.
@MainActor
public final class ShareDestination: ReviewDestination {
    public init() {}

    public func send(_ comment: ReviewComment, from: UIViewController) async throws -> String {
        var items: [Any] = [Self.text(comment)]
        for data in [comment.picture, comment.whole].compactMap({ $0 }) { if let image = UIImage(data: data) { items.append(image) } }
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = from.view
        sheet.popoverPresentationController?.sourceRect = CGRect(origin: comment.point, size: .zero)
        let done = await withCheckedContinuation { (go: CheckedContinuation<Bool, Never>) in
            sheet.completionWithItemsHandler = { _, completed, _, _ in go.resume(returning: completed) }
            from.present(sheet, animated: true)
        }
        if !done { throw ReviewWords.Failure(said: ReviewWords.now.notShared) }
        return ReviewWords.now.shared
    }

    /// The comment for a person to read, with the JSON under it for a tool.
    static func text(_ c: ReviewComment) -> String {
        var lines = [c.text, ""]
        if let e = c.element { lines.append("\(e.role)" + (e.label.map { " “\($0)”" } ?? "") + (e.views.first.map { " · \($0)" } ?? "")) }
        lines.append(c.place)
        lines += c.screens.map(\.said)
        lines.append("\(c.appName ?? c.app ?? "") · \(c.device)")
        var plain = c
        plain.picture = nil
        plain.whole = nil
        if let json = try? JSONEncoder().encode(plain), let s = String(data: json, encoding: .utf8) { lines += ["", s] }
        return lines.joined(separator: "\n")
    }
}
#endif
