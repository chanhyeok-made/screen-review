#if os(iOS)
import SwiftUI
import UIKit

/// Where named views are written: `reviewName` sets a view's accessibility identifier and notes
/// its file and line here, so a comment on it (or on something inside it) says where to look.
final class ReviewNames: @unchecked Sendable {
    static let shared = ReviewNames()
    private let lock = NSLock()
    private var places: [String: (file: String, line: Int)] = [:]

    func note(_ name: String, file: String, line: Int) { lock.withLock { places[name] = (file, line) } }
    func place(of name: String) -> (file: String, line: Int)? { lock.withLock { places[name] } }
}

extension View {
    /// Names this view for review comments: its accessibility identifier (which UI tests and
    /// agents' `find` read too) and where it is written. Costs a dictionary write per body.
    public func reviewName(_ name: String, file: String = #fileID, line: Int = #line) -> some View {
        ReviewNames.shared.note(name, file: file, line: line)
        return accessibilityIdentifier(name)
    }
}

extension UIView {
    /// The same for a UIKit view.
    public func reviewName(_ name: String, file: String = #fileID, line: Int = #line) {
        ReviewNames.shared.note(name, file: file, line: line)
        accessibilityIdentifier = name
    }
}
#endif
