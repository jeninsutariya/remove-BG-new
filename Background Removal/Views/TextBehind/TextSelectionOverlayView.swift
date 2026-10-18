//
//  TextSelectionOverlayView.swift
//  Background Removal
//
//  Draws the dashed, rotated frame and corner handles around the selected text layer on
//  the canvas. UI only – never part of the rendered image.
//

import UIKit

final class TextSelectionOverlayView: UIView {

    /// Selected layer's frame in this view's coordinates (nil = nothing selected).
    var layout: TextLayout? { didSet { setNeedsDisplay() } }
    var isLocked = false { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let layout, let ctx = UIGraphicsGetCurrentContext() else { return }
        let corners = layout.corners.map { point -> CGPoint in point }
        let pad: CGFloat = 8
        // Expand the frame a little around the glyphs.
        let center = layout.center
        let expanded = corners.map { p -> CGPoint in
            let dx = p.x - center.x, dy = p.y - center.y
            let length = max(hypot(dx, dy), 1)
            return CGPoint(x: p.x + dx / length * pad, y: p.y + dy / length * pad)
        }
        let accent = UIColor(named: "AccentColor") ?? .systemBlue
        let path = UIBezierPath()
        path.move(to: expanded[0])
        expanded.dropFirst().forEach { path.addLine(to: $0) }
        path.close()
        ctx.setShadow(offset: .zero, blur: 2, color: UIColor.black.withAlphaComponent(0.35).cgColor)
        (isLocked ? UIColor.systemGray : accent).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
        guard !isLocked else { return }
        for corner in expanded {
            let handle = UIBezierPath(ovalIn: CGRect(x: corner.x - 5, y: corner.y - 5, width: 10, height: 10))
            UIColor.white.setFill()
            handle.fill()
            accent.setStroke()
            handle.lineWidth = 1.5
            handle.stroke()
        }
    }
}
