#if os(iOS)
import UIKit

/// The way from the outermost thing at the tapped point to what is picked, one chip each
/// ("카드 › 버튼 › 회의 준비"), the way a browser's inspector shows an element's parents. A finger
/// sliding along it moves the outline live (`onPreview`); lifting picks that one (`onPick`).
@MainActor
final class ReviewCrumbs: UIView {
    var onPreview: (Int) -> Void = { _ in }
    var onPick: (Int) -> Void = { _ in }
    private let row = UIStackView()
    private let tint: UIColor
    private var selected = 0

    init(tint: UIColor) {
        self.tint = tint
        super.init(frame: .zero)
        backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.94)
        layer.cornerRadius = 18
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6), row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6), row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func set(_ names: [String], selected: Int) {
        row.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for name in names {
            let chip = UIButton(configuration: .gray())
            chip.configuration?.title = name
            chip.configuration?.titleLineBreakMode = .byTruncatingTail
            chip.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
            chip.isUserInteractionEnabled = false   // the row takes the finger, so it can slide across chips
            row.addArrangedSubview(chip)
        }
        light(selected)
    }

    private func light(_ index: Int) {
        selected = index
        for (i, chip) in row.arrangedSubviews.compactMap({ $0 as? UIButton }).enumerated() {
            chip.configuration?.baseBackgroundColor = i == index ? tint : nil
            chip.configuration?.baseForegroundColor = i == index ? .white : .label
        }
    }

    /// The chip under the finger, or the nearest one at either end.
    private func index(_ touches: Set<UITouch>) -> Int? {
        guard let x = touches.first?.location(in: row).x, !row.arrangedSubviews.isEmpty else { return nil }
        let width = row.bounds.width / CGFloat(row.arrangedSubviews.count)
        return min(max(Int(x / max(width, 1)), 0), row.arrangedSubviews.count - 1)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { slide(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { slide(touches) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { if let i = index(touches) { light(i); onPick(i) } }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { onPick(selected) }

    private func slide(_ touches: Set<UITouch>) {
        guard let i = index(touches), i != selected else { return }
        light(i)
        UISelectionFeedbackGenerator().selectionChanged()
        onPreview(i)
    }
}
#endif
