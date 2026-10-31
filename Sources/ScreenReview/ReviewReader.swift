#if os(iOS)
import UIKit

/// What is under a point in one of the app's windows, read the way VoiceOver reads it: the
/// accessibility elements whose frames hold the point (a SwiftUI view gives its elements only this
/// way), else the view UIKit hit-tests; and inside the smallest, the pieces drawn there, so a
/// card that accessibility reads as one button still lets the person point at its icon or its
/// second line (`stack`). Frames are in the window's points.
@MainActor
enum ReviewReader {
    struct Found {
        var element: ReviewElement
        /// The element's frame in the window, for the outline.
        var frame: CGRect
    }

    /// Everything a comment could be about at a point, outermost first: the accessibility elements
    /// holding it, then smaller drawn pieces inside the smallest of them, with no name of their own.
    /// `start` is that smallest element, the innermost with a name.
    struct Stack {
        var found: [Found]
        var start: Int
    }

    private struct Hit {
        let object: NSObject
        let frame: CGRect
        let above: [NSObject]
    }

    /// The smallest accessibility element at the point, for the outline while the finger moves.
    static func element(at point: CGPoint, in window: UIWindow, options: ReviewOptions) -> Found? {
        hits(at: point, in: window, options: options).last.map { found($0, in: window, options: options) }
    }

    static func stack(at point: CGPoint, in window: UIWindow, options: ReviewOptions) -> Stack? {
        let held = hits(at: point, in: window, options: options)
        guard let inner = held.last else { return nil }
        let named = held.map { found($0, in: window, options: options) }
        let drawn = pieces(at: point, in: window, inside: named[named.count - 1].frame, options: options)
            .map { piece -> Found in
                var f = found(Hit(object: piece.owner, frame: window.convert(piece.frame, to: window.screen.coordinateSpace), above: inner.above + [inner.object]),
                              in: window, options: options)
                f.element.role = "piece"   // drawn, with no accessibility of its own: the picture says what it is
                return f
            }
        return Stack(found: named + drawn, start: named.count - 1)
    }

    /// Which of `stack` a tap picks, given the frame picked now: inside it, the largest thing there
    /// that is smaller and inside it (one level in); elsewhere, or with nothing picked, the
    /// smallest thing under the finger, as a browser's inspector does. At the deepest it stays.
    static func pick(in stack: Stack, at point: CGPoint, inside current: CGRect?) -> Int {
        let deepest = stack.found.count - 1
        guard let current, current.contains(point) else { return deepest }
        let around = current.insetBy(dx: -1, dy: -1)
        if let i = stack.found.firstIndex(where: { around.contains($0.frame) && area($0.frame) < area(current) - 1 }) { return i }
        return stack.found.lastIndex { same($0.frame, current) } ?? deepest
    }

    /// The accessibility elements holding the point, largest first, one per frame.
    private static func hits(at point: CGPoint, in window: UIWindow, options: ReviewOptions) -> [Hit] {
        let space = window.screen.coordinateSpace
        let target = window.convert(point, to: space)
        var held: [Hit] = [], visited = 0
        func walk(_ o: NSObject, _ above: [NSObject], _ depth: Int) {
            guard depth < options.walkDepth, visited < options.walkNodes else { return }
            visited += 1
            if let v = o as? UIView, v.isHidden || v.alpha < 0.01 { return }
            let frame = o.accessibilityFrame
            // A frame that does not hold the point rules out what is inside it; an empty one says nothing.
            if !frame.isEmpty, !frame.contains(target) { return }
            if o.isAccessibilityElement, !frame.isEmpty { held.append(Hit(object: o, frame: frame, above: above)) }
            for child in children(of: o) { walk(child, above + [o], depth + 1) }
        }
        walk(window, [], 0)
        if held.isEmpty, let v = window.hitTest(point, with: nil) {
            held = [Hit(object: v, frame: v.convert(v.bounds, to: space), above: ancestors(of: v))]
        }
        // Largest first; of two with one frame the inner one, which says more.
        var out: [Hit] = []
        for h in held.sorted(by: { area($0.frame) > area($1.frame) }) {
            if let last = out.last, same(last.frame, h.frame) { out[out.count - 1] = h } else { out.append(h) }
        }
        return out
    }

    /// Layers drawn at the point inside `inside` (window points), smaller than it, largest first,
    /// one per frame: what a SwiftUI view draws inside one accessibility element (its texts,
    /// images, shapes), which accessibility does not split.
    private static func pieces(at point: CGPoint, in window: UIWindow, inside: CGRect, options: ReviewOptions) -> [(owner: NSObject, frame: CGRect)] {
        var out: [(owner: NSObject, frame: CGRect)] = [], visited = 0
        func walk(_ l: CALayer, _ depth: Int) {
            guard depth < options.walkDepth, visited < options.walkNodes else { return }
            visited += 1
            if l.isHidden || l.opacity < 0.01 { return }
            let f = l.convert(l.bounds, to: window.layer)
            if !f.isEmpty, !f.contains(point) { return }
            if !f.isEmpty, paints(l), f.width >= options.pieceMin, f.height >= options.pieceMin,
               area(f) < area(inside) * 0.9, inside.insetBy(dx: -1, dy: -1).contains(f) {
                out.append((l.delegate as? UIView ?? l, f))
            }
            for s in l.sublayers ?? [] { walk(s, depth + 1) }
        }
        walk(window.layer, 0)
        var kept: [(owner: NSObject, frame: CGRect)] = []
        for p in out.sorted(by: { area($0.frame) > area($1.frame) }) {
            if let last = kept.last, same(last.frame, p.frame) { kept[kept.count - 1] = p } else { kept.append(p) }
        }
        return Array(kept.prefix(options.piecesShown))
    }

    /// A layer that puts something on screen: drawn contents, a fill, a border, a shape or text.
    private static func paints(_ l: CALayer) -> Bool {
        if l.contents != nil || l is CAShapeLayer || l is CATextLayer || l.borderWidth > 0 { return true }
        guard let fill = l.backgroundColor else { return false }
        return fill.alpha > 0.01
    }

    private static func found(_ hit: Hit, in window: UIWindow, options: ReviewOptions) -> Found {
        let frame = window.convert(hit.frame, from: window.screen.coordinateSpace)
        return Found(element: describe(hit, frame: frame, options: options), frame: frame)
    }

    private static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < 1 && abs(a.minY - b.minY) < 1 && abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
    }

    /// `region` of the window as a PNG, without the review layer (it is another window).
    static func picture(of window: UIWindow, region: CGRect) -> Data? {
        let rect = region.intersection(window.bounds)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return nil }
        return UIGraphicsImageRenderer(bounds: rect).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }.pngData()
    }

    /// The whole window as a JPEG, its longest side at most `longest` pixels: the layout around the comment.
    static func whole(of window: UIWindow, longest: CGFloat) -> Data? {
        let side = max(window.bounds.width, window.bounds.height)
        guard side >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(window.screen.scale, longest / side)
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }.jpegData(compressionQuality: 0.7)
    }

    private static func children(of o: NSObject) -> [NSObject] {
        if let elements = o.accessibilityElements as? [NSObject], !elements.isEmpty { return elements }
        let count = o.accessibilityElementCount()
        if count != NSNotFound, count > 0 { return (0..<count).compactMap { o.accessibilityElement(at: $0) as? NSObject } }
        return (o as? UIView)?.subviews ?? []
    }

    private static func ancestors(of view: UIView) -> [NSObject] {
        var out: [NSObject] = [], v = view.superview
        while let up = v { out.insert(up, at: 0); v = up.superview }
        return out
    }

    private static func describe(_ hit: Hit, frame: CGRect, options: ReviewOptions) -> ReviewElement {
        let o = hit.object
        let traits = traitNames(o.accessibilityTraits)
        var e = ReviewElement(role: traits.first ?? shortType(o), label: nonEmpty(o.accessibilityLabel), value: nonEmpty(o.accessibilityValue),
                              identifier: identifier(o), frame: frame, path: hit.above.suffix(options.pathDepth).map(name), traits: traits,
                              views: ReviewViews.around([o] + hit.above, options: options))
        // The nearest named view at or above the element says where it is written.
        for named in ([o] + Array(hit.above.reversed())).compactMap(identifier) {
            if let place = ReviewNames.shared.place(of: named) { e.file = place.file; e.line = place.line; break }
        }
        return e
    }

    private static func name(_ o: NSObject) -> String {
        if let id = identifier(o) { return id }
        if let label = nonEmpty(o.accessibilityLabel) { return "\(shortType(o)) \"\(label)\"" }
        return shortType(o)
    }

    private static func identifier(_ o: NSObject) -> String? {
        nonEmpty((o as? UIAccessibilityIdentification)?.accessibilityIdentifier)
    }

    private static func shortType(_ o: NSObject) -> String {
        let full = String(describing: type(of: o))
        return String(full.prefix { $0 != "<" }.split(separator: ".").last ?? Substring(full))
    }

    private static func nonEmpty(_ s: String?) -> String? { s.flatMap { $0.isEmpty ? nil : $0 } }

    private static func area(_ r: CGRect) -> CGFloat { r.width * r.height }

    private static let traitWords: [(UIAccessibilityTraits, String)] = [
        (.button, "button"), (.toggleButton, "toggle"), (.link, "link"), (.header, "header"), (.searchField, "searchField"),
        (.image, "image"), (.staticText, "staticText"), (.adjustable, "adjustable"), (.tabBar, "tabBar"),
        (.keyboardKey, "keyboardKey"), (.selected, "selected"), (.notEnabled, "notEnabled"),
    ]

    private static func traitNames(_ t: UIAccessibilityTraits) -> [String] {
        traitWords.filter { t.contains($0.0) }.map(\.1)
    }
}
#endif
