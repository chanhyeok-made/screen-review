#if os(iOS)
import SwiftUI
import UIKit

/// Where a comment was left, read from the app itself so any app gets it with `ScreenReview.start(to:)`
/// alone (찬혁 2026-10-29: "앱별로 땜빵이 아니라 어떤 앱이든"): the screens showing, from the
/// window's root to the one in front (tab, navigation stack, split columns, sheets), the window's
/// state, and the app's own SwiftUI view types. A SwiftUI app's controllers are all hosting
/// controllers, so the view types are read by reflection from each hosting view's root view: the
/// view values the app composed, kept by the hosting view, name the code an agent opens.
@MainActor
enum ReviewContext {
    /// From the root to the one in front: each container with what it shows and the app's views in
    /// it, and where that is as a person would say it ("할 일 › 설정 › 시간대 › sheet medium"): the
    /// tab's title, the navigation titles, the sheets.
    static func read(_ window: UIWindow, options: ReviewOptions) -> (screens: [ReviewScreen], place: String) {
        var out: [ReviewScreen] = [], crumbs: [String] = [], steps = 0
        // Down the containers (tab → navigation → its top), then each controller presented over them.
        func walk(_ start: UIViewController?) {
            var vc = start
            while let here = vc, steps < options.screensDeep {   // a cycle in the app's own controllers cannot hang the layer
                steps += 1
                out.append(contentsOf: screen(here, options: options))
                crumbs.append(contentsOf: crumb(here))
                vc = shown(in: here)
            }
        }
        walk(window.rootViewController)
        var presented = window.rootViewController?.presentedViewController
        while let p = presented, !p.isBeingDismissed, steps < options.screensDeep {
            walk(p)
            presented = p.presentedViewController
        }
        var place: [String] = []
        for c in crumbs where place.last != c { place.append(c) }
        return (out, place.joined(separator: " › "))
    }

    /// What a person calls this controller's part of the way: the tab, the navigation's titles, a sheet.
    private static func crumb(_ vc: UIViewController) -> [String] {
        if let tabs = vc as? UITabBarController { return [tabTitle(tabs)] }
        if let nav = vc as? UINavigationController { return nav.viewControllers.compactMap(title(of:)) }
        let sheet = presentation(of: vc)
        return [sheet, vc.parent is UINavigationController ? nil : title(of: vc)].compactMap { $0 }
    }

    /// The child a container shows: the selected tab, the navigation's top, the last split column,
    /// else the last child on screen.
    private static func shown(in vc: UIViewController) -> UIViewController? {
        if let tabs = vc as? UITabBarController { return tabs.selectedViewController }
        if let nav = vc as? UINavigationController { return nav.topViewController }
        if let split = vc as? UISplitViewController { return split.viewControllers.last }
        return vc.children.last { $0.isViewLoaded && $0.view.window != nil && !$0.view.isHidden }
    }

    /// One controller as a screen: what kind of holder it is, its title, and the app's views it hosts.
    private static func screen(_ vc: UIViewController, options: ReviewOptions) -> [ReviewScreen] {
        var name: String
        if let tabs = vc as? UITabBarController {
            let count = tabs.viewControllers?.count ?? 0
            name = "tab " + quoted(tabTitle(tabs)) + (count > 0 ? " \(tabs.selectedIndex + 1)/\(count)" : "")
        } else if let nav = vc as? UINavigationController {
            let titles = nav.viewControllers.map { title(of: $0) ?? "·" }
            name = "nav " + titles.joined(separator: " › ")
        } else if let split = vc as? UISplitViewController {
            name = "split \(split.viewControllers.count) columns"
        } else {
            name = shortType(vc)
            if let t = title(of: vc) { name += " " + quoted(t) }
        }
        let sheet = presentation(of: vc)
        if let sheet { name = sheet + " · " + name }
        let views = ReviewViews.app(in: vc, options: options)
        let container = vc is UITabBarController || vc is UINavigationController || vc is UISplitViewController
        // A plain controller with nothing to say is not a screen worth a line.
        if views.isEmpty, !container, sheet == nil, title(of: vc) == nil { return [] }
        return [ReviewScreen(name: name, views: views)]
    }

    /// "sheet medium", "fullScreen", "popover" for a controller presented on its own.
    private static func presentation(of vc: UIViewController) -> String? {
        guard vc.presentingViewController != nil, vc.parent == nil else { return nil }
        switch vc.modalPresentationStyle {
        case .pageSheet, .formSheet:
            let detent = vc.sheetPresentationController?.selectedDetentIdentifier?.rawValue
            return "sheet" + (detent.map { " " + $0.replacingOccurrences(of: "com.apple.UIKit.", with: "") } ?? "")
        case .fullScreen, .overFullScreen: return "fullScreen"
        case .popover: return "popover"
        default: return "presented"
        }
    }

    private static func tabTitle(_ tabs: UITabBarController) -> String {
        tabs.selectedViewController?.tabBarItem.title ?? tabs.tabBar.selectedItem?.title ?? "\(tabs.selectedIndex + 1)"
    }

    private static func title(of vc: UIViewController) -> String? {
        let t = vc.navigationItem.title ?? vc.title
        return t.flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func quoted(_ s: String) -> String { "“\(s)”" }

    private static func shortType(_ o: AnyObject) -> String {
        let full = String(describing: type(of: o))
        return String(full.prefix { $0 != "<" })
    }

    /// The window as the app sees it: sizes, the interface's and the device's orientation, size
    /// classes, text size, appearance, and a foldable iPhone's hinge, fold and vertical bar
    /// (ReviewPosture.swift).
    static func state(of window: UIWindow) -> [String: String] {
        let n = { (v: CGFloat) in String(Int(v.rounded())) }
        let traits = window.traitCollection
        var s: [String: String] = [
            "window": "\(n(window.bounds.width))x\(n(window.bounds.height))",
            "screen": "\(n(window.screen.bounds.width))x\(n(window.screen.bounds.height))",
            "safe": [window.safeAreaInsets.top, window.safeAreaInsets.left, window.safeAreaInsets.bottom, window.safeAreaInsets.right].map(n).joined(separator: ","),
            "sizeClass": "\(sizeClass(traits.horizontalSizeClass)),\(sizeClass(traits.verticalSizeClass))",
            "text": traits.preferredContentSizeCategory.rawValue.replacingOccurrences(of: "UICTContentSizeCategory", with: ""),
            "style": traits.userInterfaceStyle == .dark ? "dark" : "light",
        ]
        if let scene = window.windowScene {
            s["orientation"] = orientation(scene.effectiveGeometry.interfaceOrientation)
            s["windows"] = "\(scene.windows.filter { !$0.isHidden && !($0 is ReviewWindow) }.count)"
        }
        s["device"] = deviceOrientation(UIDevice.current.orientation)
        #if compiler(>=6.4)
        if #available(iOS 27.1, *) { s["verticalBarEdge"] = "\(window.traitCollection.verticalBarEdge.rawValue)" }
        #endif
        s.merge(ReviewPosture.shared.facts) { _, posture in posture }
        return s
    }

    private static func sizeClass(_ c: UIUserInterfaceSizeClass) -> String {
        switch c { case .compact: "compact"; case .regular: "regular"; default: "-" }
    }

    private static func deviceOrientation(_ o: UIDeviceOrientation) -> String {
        switch o {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .faceUp: "faceUp"
        case .faceDown: "faceDown"
        default: "unknown"
        }
    }

    private static func orientation(_ o: UIInterfaceOrientation) -> String {
        switch o {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        default: "unknown"
        }
    }
}

/// The app's own SwiftUI view types inside a controller or a view, by reflection: from the hosting
/// view's root view down through what the app composed (modifiers, stacks, conditions, AnyView),
/// keeping the types that are not Apple's (the app's and its packages'). A view's `body` is not
/// stored, so what it builds is not seen; what it was given (its content) is. Bounded by
/// `ReviewOptions.mirrorNodes` and `mirrorDepth`.
@MainActor
enum ReviewViews {
    static func app(in vc: UIViewController, options: ReviewOptions) -> [String] {
        guard vc.isViewLoaded else { return [] }
        return app(in: [vc, vc.view], options: options)
    }

    /// The hosting views among `objects` (a hit element's parents), innermost first.
    static func around(_ objects: [NSObject], options: ReviewOptions) -> [String] {
        let hosts = objects.reversed().filter { $0 is UIView && String(reflecting: type(of: $0)).hasPrefix("SwiftUI.") }
        return app(in: Array(hosts.prefix(2)), options: options)
    }

    private static func app(in roots: [Any], options: ReviewOptions) -> [String] {
        var out: [String] = [], seen = Set<String>(), objects = Set<ObjectIdentifier>(), nodes = 0
        func walk(_ value: Any, _ depth: Int) {
            guard depth < options.mirrorDepth, nodes < options.mirrorNodes, out.count < options.viewsShown else { return }
            nodes += 1
            let type = Swift.type(of: value)
            let reflected = String(reflecting: type)
            if value is any View, !isApple(type, reflected), let name = appName(reflected), seen.insert(name).inserted { out.append(name) }
            let mirror = Mirror(reflecting: value)
            if mirror.displayStyle == .class {
                // SwiftUI's own boxes (a hosting view, AnyView's storage) hold the views; the app's
                // objects (models) are not followed.
                guard depth == 0 || reflected.hasPrefix("SwiftUI."), objects.insert(ObjectIdentifier(value as AnyObject)).inserted else { return }
            }
            // A hosting controller or view is followed only to its hosting view and its root view,
            // not into its view graph, which reaches every other screen.
            let host = value is UIView || value is UIViewController
            var m: Mirror? = mirror
            while let level = m {
                for child in level.children where !host || child.value is any View || (value is UIViewController && child.value is UIView) {
                    walk(child.value, depth + 1)
                }
                m = level.superclassMirror
            }
        }
        for root in roots { walk(root, 0) }
        return out
    }

    /// Whether a type is Apple's: its code is in the system's frameworks. A generic type made at run
    /// time has no image to ask, so its module's name decides.
    static func isApple(_ type: Any.Type, _ reflected: String) -> Bool {
        if reflected.hasPrefix("ScreenReview.") { return true }   // the layer's own, as good as the system's here
        var info = Dl_info()
        if dladdr(unsafeBitCast(type, to: UnsafeRawPointer.self), &info) != 0, let file = info.dli_fname {
            let path = String(cString: file)
            return path.contains("/System/Library/") || path.contains("/usr/lib/")
        }
        let module = reflected.prefix { $0 != "." }
        return module.hasPrefix("Swift") || module.hasPrefix("_") || module.hasPrefix("UIKit") || module.hasPrefix("Core") || module == "ScreenReview"
            || ["Foundation", "Combine", "Observation", "ObjectiveC", "Dispatch", "MapKit", "PhotosUI", "WebKit", "StoreKit", "Charts", "TipKit",
                "AppIntents", "WidgetKit", "AVKit", "PencilKit", "QuickLook", "AuthenticationServices", "RealityKit", "SceneKit", "SpriteKit"].contains(String(module))
    }

    /// "Ikie.InboxScreen" from "Ikie.InboxScreen<…>" or "Ikie.(unknown context at $10a3c).Row"
    /// (as "Ikie.Row"); nil for an empty name.
    static func appName(_ reflected: String) -> String? {
        let bare = reflected.prefix { $0 != "<" }
        let parts = bare.split(separator: ".").filter { !$0.hasPrefix("(") && !$0.hasPrefix("$") && !$0.contains(" ") }
        return parts.count < 2 ? nil : parts.joined(separator: ".")
    }
}
#endif
