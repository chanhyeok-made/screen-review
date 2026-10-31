#if os(iOS)
import Foundation
import UIKit

/// One comment left in the review layer: the words, where the finger was, what was there, which
/// screens were showing and a picture. Everything but the words is read from the app itself, so an
/// app gets it all with `ScreenReview.start(to:)` and nothing more. Points are the app window's.
public struct ReviewComment: Sendable, Equatable, Codable {
    public var text: String
    /// The app's bundle id and the name people see.
    public var app: String?
    public var appName: String?
    /// "iPhone 17 Pro" in the Simulator; a device's name and model ("iPhone (iPhone18,1)").
    public var device: String
    public var point: CGPoint
    public var element: ReviewElement?
    /// Where it was, as a person says it: the tab, the navigation titles, the sheets ("할 일 › 설정 › 시간대").
    public var place: String
    /// From the window's root to the one in front (ReviewContext.swift).
    public var screens: [ReviewScreen]
    /// The window and the device as the system told them: sizes, orientations, size classes, text
    /// size, appearance, a foldable's hinge and fold.
    public var window: [String: String]
    /// What the app said about itself (`ScreenReview.state`), when it says anything.
    public var appState: [String: String]
    /// PNG around the element, and JPEG of the whole window, both without the review layer.
    public var picture: Data?
    public var whole: Data?

    public init(text: String, app: String?, appName: String?, device: String, point: CGPoint, element: ReviewElement?, place: String,
                screens: [ReviewScreen], window: [String: String], appState: [String: String], picture: Data?, whole: Data?) {
        self.text = text; self.app = app; self.appName = appName; self.device = device; self.point = point; self.element = element
        self.place = place; self.screens = screens; self.window = window; self.appState = appState; self.picture = picture; self.whole = whole
    }
}

/// The element under the finger, as accessibility read it (the way VoiceOver finds one).
public struct ReviewElement: Sendable, Equatable, Codable {
    public var role: String
    public var label: String?
    public var value: String?
    public var identifier: String?
    public var frame: CGRect
    /// From the window down to the element's parent, one "type", "identifier" or "type “label”" each.
    public var path: [String]
    /// Accessibility traits ("button", "header").
    public var traits: [String]
    /// The app's own SwiftUI view types holding it, innermost first.
    public var views: [String]
    /// Where the view is written, when the code named it (`reviewName`).
    public var file: String?
    public var line: Int?

    public init(role: String, label: String? = nil, value: String? = nil, identifier: String? = nil, frame: CGRect,
                path: [String] = [], traits: [String] = [], views: [String] = [], file: String? = nil, line: Int? = nil) {
        self.role = role; self.label = label; self.value = value; self.identifier = identifier; self.frame = frame
        self.path = path; self.traits = traits; self.views = views; self.file = file; self.line = line
    }
}

/// A screen showing: what holds it ("tab “할 일” 2/5", "sheet medium · UIHostingController",
/// "nav 문서 › 설정") and the app's own SwiftUI view types in it, outermost first ("InboxScreen").
public struct ReviewScreen: Sendable, Equatable, Codable {
    public var name: String
    public var views: [String]

    public init(name: String, views: [String] = []) { self.name = name; self.views = views }

    /// "tab “할 일” 2/5 · InboxScreen, TaskRow"
    public var said: String { views.isEmpty ? name : "\(name) · " + views.joined(separator: ", ") }
}
#endif
