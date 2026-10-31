#if os(iOS)
import UIKit

/// The review layer's own window, kept apart so the hold is never put on it.
final class ReviewWindow: UIWindow {}

/// The review layer over the app (ScreenReview.swift): a touch outlines the element under it,
/// lifting the finger asks for a line, and the comment goes to the destination. It stays open for
/// the next comment until the bar's close.
@MainActor
enum ReviewLayer {
    private static var shown: ReviewWindow?
    private static weak var under: UIWindow?

    static func open(over app: UIWindow, to destination: ReviewDestination, options: ReviewOptions) {
        guard shown == nil, let scene = app.windowScene else { return }
        let w = ReviewWindow(windowScene: scene)
        w.windowLevel = .alert + 1
        w.backgroundColor = .clear
        w.rootViewController = ReviewController(app: app, destination: destination, options: options) { close() }
        w.makeKeyAndVisible()   // the line's text field types only in the key window
        shown = w
        under = app
    }

    static func close() {
        shown?.isHidden = true
        shown = nil
        under?.makeKey()
    }
}

@MainActor
final class ReviewController: UIViewController {
    private weak var app: UIWindow?
    private let destination: ReviewDestination
    private let options: ReviewOptions
    private let close: () -> Void
    private let words = ReviewWords.now
    private let outline = UIView()
    private let status = UILabel()
    private lazy var comment = button(words.comment) { [weak self] in self?.ask() }
    private lazy var crumbs = ReviewCrumbs(tint: options.tint)
    private let bar = UIStackView()
    /// What is picked: everything at the tapped point (`ReviewReader.Stack`) and which of it.
    private var picked: (stack: ReviewReader.Stack, index: Int, point: CGPoint)?

    init(app: UIWindow, destination: ReviewDestination, options: ReviewOptions, close: @escaping () -> Void) {
        self.app = app; self.destination = destination; self.options = options; self.close = close
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        outline.isUserInteractionEnabled = false
        outline.isHidden = true
        outline.layer.borderColor = options.tint.cgColor
        outline.layer.borderWidth = 2
        outline.backgroundColor = options.tint.withAlphaComponent(0.12)
        view.addSubview(outline)

        status.text = words.bar
        status.font = .preferredFont(forTextStyle: .footnote)
        status.textColor = .label
        status.numberOfLines = 2
        comment.configuration = .borderedProminent()
        comment.configuration?.title = words.comment
        let done = button(words.close) { [weak self] in self?.close() }
        [status, comment, done].forEach(bar.addArrangedSubview)
        bar.spacing = 12
        bar.alignment = .center
        bar.isLayoutMarginsRelativeArrangement = true
        bar.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        bar.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.94)
        bar.layer.cornerRadius = 18
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bar.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
        ])
        crumbs.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(crumbs)
        NSLayoutConstraint.activate([
            crumbs.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            crumbs.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            crumbs.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
        crumbs.onPreview = { [weak self] i in
            guard let self, let p = self.picked else { return }
            self.show(p.stack.found[i])
            self.status.text = Self.said(p.stack.found[i].element)
        }
        crumbs.onPick = { [weak self] i in
            guard let self, let p = self.picked else { return }
            self.pick((p.stack, i, p.point))
        }
        pick(nil)
    }

    private func button(_ title: String, _ act: @escaping () -> Void) -> UIButton {
        let b = UIButton(type: .system, primaryAction: UIAction(title: title) { _ in act() })
        b.tintColor = options.tint
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        return b
    }

    // A tap picks the smallest thing under the finger; the chips below show the way out from it,
    // and sliding along them moves the pick; a tap inside what is picked goes one level in there
    // ("tap, then pick inside it"); 코멘트 asks for the line. While the finger is
    // down the outline shows what lifting it would pick.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { preview(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { preview(touches) }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        pick(next(touches) ?? picked)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { pick(picked) }

    private func preview(_ touches: Set<UITouch>) {
        show(next(touches).map { $0.stack.found[$0.index] })
    }

    /// What lifting the finger here would pick.
    private func next(_ touches: Set<UITouch>) -> (stack: ReviewReader.Stack, index: Int, point: CGPoint)? {
        guard let app, let touch = touches.first, !bar.frame.contains(touch.location(in: view)) else { return nil }
        let point = view.convert(touch.location(in: view), to: app)
        guard let stack = ReviewReader.stack(at: point, in: app, options: options) else { return nil }
        let current = picked.map { $0.stack.found[$0.index].frame }
        return (stack, ReviewReader.pick(in: stack, at: point, inside: current), point)
    }

    private func pick(_ p: (stack: ReviewReader.Stack, index: Int, point: CGPoint)?) {
        picked = p
        let found = p.map { $0.stack.found[$0.index] }
        show(found)
        status.text = found.map { Self.said($0.element) } ?? words.bar
        comment.isHidden = p == nil
        crumbs.isHidden = p == nil
        if let p { crumbs.set(p.stack.found.map { Self.chip($0.element) }, selected: p.index) }
    }

    /// A chip's few words: the element's label, else what it is (a drawn piece, its view type).
    static func chip(_ e: ReviewElement) -> String {
        if let label = e.label { return label }
        if e.role == "piece" { return ReviewWords.now.piece }   // its views are its element's, said by that chip
        if let view = e.views.first?.split(separator: ".").last { return String(view) }
        return e.role
    }

    private func show(_ found: ReviewReader.Found?) {
        guard let app else { return }
        outline.isHidden = found == nil
        if let found { outline.frame = view.convert(found.frame, from: app) }
    }

    /// "button “설정” · SettingsScreen File.swift:42"
    static func said(_ e: ReviewElement) -> String {
        var what = [e.role]
        if let label = e.label { what.append("“\(label)”") }
        if let view = e.views.first { what.append("· \(view)") }
        if let file = e.file { what.append(e.line.map { "\(file):\($0)" } ?? file) }
        return what.joined(separator: " ")
    }

    /// The line for what is picked; the comment carries the window as it is now.
    private func ask() {
        guard let app, let p = picked else { return }
        let found = p.stack.found[p.index]
        let read = ReviewContext.read(app, options: options)
        var c = ReviewComment(text: "", app: Bundle.main.bundleIdentifier, appName: Self.appName, device: Self.deviceName, point: p.point,
                              element: found.element, place: read.place, screens: read.screens, window: ReviewContext.state(of: app),
                              appState: ScreenReview.state?() ?? [:], picture: nil, whole: ReviewReader.whole(of: app, longest: options.wholeLongest))
        c.picture = ReviewReader.picture(of: app, region: options.pictureRegion(point: p.point, element: found.frame))
        let alert = UIAlertController(title: words.title, message: Self.said(found.element), preferredStyle: .alert)
        alert.addTextField { $0.placeholder = self.words.placeholder }
        alert.addAction(UIAlertAction(title: words.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: words.leave, style: .default) { [weak self, weak alert] _ in
            c.text = alert?.textFields?.first?.text ?? ""
            self?.send(c)
        })
        alert.preferredAction = alert.actions.last
        present(alert, animated: true)
    }

    private func send(_ comment: ReviewComment) {
        guard !comment.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        pick(nil)
        status.text = words.sending
        Task { @MainActor in
            do { status.text = try await destination.send(comment, from: self) } catch { status.text = error.localizedDescription }
        }
    }

    /// The Simulator's device ("iPhone 17 Pro"); on a device its name and model ("iPhone (iPhone18,1)").
    static var deviceName: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] { return simulated }
        var info = utsname()
        uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return "\(UIDevice.current.name) (\(model))"
    }

    private static var appName: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
#endif
