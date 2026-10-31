#if os(iOS)
import UIKit

/// How the review layer opens and how far it reads. The defaults suit most apps; an app whose own
/// gestures hold two fingers still asks for more `fingers`. The read limits keep a huge list from
/// stalling a touch. The numbers are guesses, unmeasured.
public struct ReviewOptions: Sendable {
    /// How many fingers held still open the layer. Two, as the Simulator has no third (⌥ gives two).
    public var fingers = 2
    /// How long, in seconds: long enough that a pinch or a two-finger scroll never opens it.
    public var hold = 0.6
    /// The outline and the bar's button.
    public var tint: UIColor = .systemMint
    /// The accessibility walk to the element under a touch.
    public var walkDepth = 80
    public var walkNodes = 4000
    /// Drawn pieces a tap can go into inside the smallest accessibility element: at least this many
    /// points a side, at most this many steps.
    public var pieceMin: CGFloat = 6
    public var piecesShown = 6
    /// How many parents an element's path keeps.
    public var pathDepth = 8
    /// The view types read by reflection: values visited per screen, how deep, names kept.
    public var mirrorNodes = 3000
    public var mirrorDepth = 60
    public var viewsShown = 8
    /// How many controllers a comment walks from the window's root.
    public var screensDeep = 16
    /// The picture: the element and this much around it, at least `pictureMin` and at most
    /// `pictureMax` a side; a point alone, or a larger element, gets a `pictureAround` square.
    public var pictureMargin: CGFloat = 24
    public var pictureMin: CGFloat = 160
    public var pictureMax: CGFloat = 900
    public var pictureAround: CGFloat = 400
    /// The whole window's picture, its longest side in pixels at most (JPEG).
    public var wholeLongest: CGFloat = 1600

    public init() {}

    /// The part of the window the picture shows.
    func pictureRegion(point: CGPoint, element: CGRect?) -> CGRect {
        if let e = element, e.width + 2 * pictureMargin <= pictureMax, e.height + 2 * pictureMargin <= pictureMax {
            let width = max(e.width + 2 * pictureMargin, pictureMin), height = max(e.height + 2 * pictureMargin, pictureMin)
            return CGRect(x: e.midX - width / 2, y: e.midY - height / 2, width: width, height: height)
        }
        return CGRect(x: point.x - pictureAround / 2, y: point.y - pictureAround / 2, width: pictureAround, height: pictureAround)
    }
}

/// The layer's few words, in Korean or English by the person's first language.
struct ReviewWords {
    struct Failure: LocalizedError {
        let said: String
        var errorDescription: String? { said }
    }

    let bar, close, title, placeholder, cancel, leave, comment, piece, sending, sent, shared, notShared: String

    static var now: ReviewWords { Locale.preferredLanguages.first?.hasPrefix("ko") == true ? ko : en }

    static let ko = ReviewWords(bar: "리뷰 모드: 누르면 손가락 밑 가장 작은 것을 골라요. 아래 칸을 쓸면 넓어져요", close: "닫기", title: "코멘트 남기기", placeholder: "바꿀 점을 한 줄로",
                                cancel: "취소", leave: "남기기", comment: "코멘트", piece: "그림", sending: "보내는 중…", sent: "남겼어요", shared: "공유했어요", notShared: "공유하지 않았어요")
    static let en = ReviewWords(bar: "Review: tap picks the smallest thing; slide along the bar below to widen", close: "Close", title: "Leave a comment", placeholder: "What to change, in a line",
                                cancel: "Cancel", leave: "Leave", comment: "Comment", piece: "drawing", sending: "Sending…", sent: "Left", shared: "Shared", notShared: "Not shared")
}
#endif
