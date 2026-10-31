#if os(iOS)
import SwiftUI
import UIKit
import XCTest
@testable import ScreenReview

/// What a comment reads from an app with no code in it: the way to the screen (tab, navigation
/// titles, sheet), the app's own SwiftUI view types, and the window. Runs on an iOS Simulator.
@MainActor
final class ScreenReviewTests: XCTestCase {
    struct InboxScreen: View {
        var body: some View { List { Text("a") }.navigationTitle("할 일") }
    }

    struct TimeZoneScreen: View {
        var body: some View { Text("Asia/Seoul").navigationTitle("시간대") }
    }

    private func window(_ root: UIViewController) -> UIWindow {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let w = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        w.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        w.rootViewController = root
        w.makeKeyAndVisible()
        root.view.layoutIfNeeded()
        return w
    }

    func testATabAndANavigationStackSayWhereAndWhichViews() throws {
        let inbox = UINavigationController(rootViewController: UIHostingController(rootView: InboxScreen()))
        inbox.tabBarItem.title = "할 일"
        let settings = UINavigationController(rootViewController: UIHostingController(rootView: Text("나")))
        settings.tabBarItem.title = "나"
        let zone = UIHostingController(rootView: TimeZoneScreen())
        zone.title = "시간대"
        settings.pushViewController(zone, animated: false)
        let tabs = UITabBarController()
        tabs.viewControllers = [inbox, settings]
        tabs.selectedIndex = 1
        let w = window(tabs)
        defer { w.isHidden = true }

        let read = ReviewContext.read(w, options: ReviewOptions())
        XCTAssertTrue(read.place.hasPrefix("나 ›"), read.place)
        XCTAssertTrue(read.place.hasSuffix("시간대"), read.place)
        XCTAssertTrue(read.screens.contains { $0.name.hasPrefix("tab “나” 2/2") }, "\(read.screens)")
        XCTAssertTrue(read.screens.contains { $0.views.contains("ScreenReviewTests.ScreenReviewTests.TimeZoneScreen") }, "\(read.screens)")
    }

    func testASheetIsPartOfTheWay() throws {
        let root = UIHostingController(rootView: InboxScreen())
        let w = window(root)
        defer { w.isHidden = true }
        let sheet = UIHostingController(rootView: TimeZoneScreen())
        sheet.title = "시간대"
        root.present(sheet, animated: false)
        let until = Date().addingTimeInterval(5)   // a package's tests have no app around them, so no completion is promised
        while root.presentedViewController == nil, Date() < until { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        XCTAssertNotNil(root.presentedViewController, "the sheet never showed")

        let read = ReviewContext.read(w, options: ReviewOptions())
        XCTAssertTrue(read.place.contains("sheet"), read.place)
        XCTAssertTrue(read.screens.last?.views.contains("ScreenReviewTests.ScreenReviewTests.TimeZoneScreen") == true, "\(read.screens)")
    }

    func testTheWindowIsRead() {
        let w = window(UIHostingController(rootView: InboxScreen()))
        defer { w.isHidden = true }
        let s = ReviewContext.state(of: w)
        XCTAssertEqual(s["window"], "390x844")
        XCTAssertNotNil(s["orientation"])
        XCTAssertNotNil(s["sizeClass"])
        XCTAssertNotNil(ReviewReader.whole(of: w, longest: 400))
    }

    struct Card: View {
        var body: some View {
            Button {} label: {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "star.fill").font(.system(size: 40))
                    Text("회의 준비").font(.title)
                    Text("오후 3시 · 회의실 B").font(.body)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.2)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    func testASingleElementCardStillLetsAPartBePicked() throws {
        // UIKit: a row read as one element, an image inside it.
        let row = UIView(frame: CGRect(x: 20, y: 100, width: 350, height: 80))
        row.isAccessibilityElement = true
        row.accessibilityLabel = "회의 준비"
        let icon = UIImageView(image: UIImage(systemName: "star.fill"))
        icon.frame = CGRect(x: 12, y: 20, width: 40, height: 40)
        row.addSubview(icon)
        let root = UIViewController()
        root.view.addSubview(row)
        let w = window(root)
        defer { w.isHidden = true }
        let stack = try XCTUnwrap(ReviewReader.stack(at: CGPoint(x: 50, y: 140), in: w, options: ReviewOptions()))
        XCTAssertEqual(stack.found[stack.start].element.label, "회의 준비")
        let inner = try XCTUnwrap(stack.found.last)
        XCTAssertEqual(inner.element.role, "piece")
        XCTAssertEqual(inner.frame, CGRect(x: 32, y: 120, width: 40, height: 40))
    }

    func testASwiftUICardOffersWhatItDrawsInside() throws {
        let w = window(UIHostingController(rootView: Card()))
        defer { w.isHidden = true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))   // SwiftUI draws on the next commit
        // A test runs with accessibility off, so SwiftUI gives no elements here and the hosting view
        // stands in for the button; what it draws is there either way.
        let middle = try XCTUnwrap(ReviewReader.stack(at: CGPoint(x: w.bounds.midX, y: w.bounds.midY), in: w, options: ReviewOptions()))
        let card = try XCTUnwrap(middle.found.first { $0.element.role == "piece" }?.frame, "\(middle.found.map(\.frame))")
        XCTAssertLessThan(card.width, w.bounds.width)
        // The card's last line: its own piece, inside the card's.
        let line = try XCTUnwrap(ReviewReader.stack(at: CGPoint(x: card.minX + 40, y: card.maxY - 34), in: w, options: ReviewOptions()))
        let pieces = line.found.suffix(from: line.start + 1).map(\.frame)
        XCTAssertEqual(pieces.first, card, "\(pieces)")
        let text = try XCTUnwrap(pieces.last)
        XCTAssertTrue(card.contains(text) && text.height < card.height / 3, "\(pieces)")
    }

    func testATapPicksTheSmallestAndATapInsideAPickGoesOneLevelIn() {
        func at(_ r: CGRect, _ role: String = "piece") -> ReviewReader.Found { ReviewReader.Found(element: ReviewElement(role: role, frame: r), frame: r) }
        let screen = CGRect(x: 0, y: 0, width: 390, height: 844), card = CGRect(x: 20, y: 100, width: 350, height: 200)
        let row = CGRect(x: 30, y: 200, width: 330, height: 40), line = CGRect(x: 40, y: 210, width: 120, height: 20)
        let stack = ReviewReader.Stack(found: [at(screen, "group"), at(card, "button"), at(row), at(line)], start: 1)
        let point = CGPoint(x: 50, y: 220)
        XCTAssertEqual(ReviewReader.pick(in: stack, at: point, inside: nil), 3, "the smallest under the finger first")
        XCTAssertEqual(ReviewReader.pick(in: stack, at: point, inside: CGRect(x: 0, y: 500, width: 10, height: 10)), 3, "a tap elsewhere starts again")
        XCTAssertEqual(ReviewReader.pick(in: stack, at: point, inside: card), 2, "inside the card, one level in")
        XCTAssertEqual(ReviewReader.pick(in: stack, at: point, inside: row), 3)
        XCTAssertEqual(ReviewReader.pick(in: stack, at: point, inside: line), 3, "the deepest stays")
        XCTAssertEqual(ReviewController.chip(stack.found[1].element), "button")
        XCTAssertEqual(ReviewController.chip(stack.found[3].element), ReviewWords.now.piece)
    }

    func testAppTypeNamesKeepTheirModuleAndLosePrivateContext() {
        XCTAssertEqual(ReviewViews.appName("Ikie.InboxScreen"), "Ikie.InboxScreen")
        XCTAssertEqual(ReviewViews.appName("Ikie.MainView.Tab"), "Ikie.MainView.Tab")
        XCTAssertEqual(ReviewViews.appName("Ikie.(unknown context at $10a3c).Row"), "Ikie.Row")
        XCTAssertEqual(ReviewViews.appName("Ikie.Sheet<Ikie.Row>"), "Ikie.Sheet")
        XCTAssertTrue(ReviewViews.isApple(Text.self, String(reflecting: Text.self)))
        XCTAssertFalse(ReviewViews.isApple(InboxScreen.self, String(reflecting: InboxScreen.self)))
    }
}
#endif
