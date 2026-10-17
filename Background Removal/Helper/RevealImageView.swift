//
//  RevealImageView.swift
//  Background Removal
//
//  Created by Jenin Sutariya on 06/10/26.
//

import Foundation
import UIKit

class RevealImageView: UIImageView {
    
    public var leftImage: UIImage? {
        didSet {
            if let img = leftImage {
                leftImageLayer.contents = img.cgImage
            }
        }
    }
    public var rightImage: UIImage? {
        didSet {
            if let img = rightImage {
                self.image = img
            }
        }
    }
    
    // private properties
    private let leftImageLayer = CALayer()
    private let maskLayer = CALayer()
    private let lineView = UIView()
    private let arrowImageView = UIImageView(image: UIImage(named: "doubleSidedArrow"))
    private let arrowSize: CGFloat = 40
    private var pct: CGFloat = 0.5 {
        didSet {
            updateView()
        }
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        // any opaque color
        maskLayer.backgroundColor = UIColor.black.cgColor
        leftImageLayer.mask = maskLayer
        // the "reveal" image layer
        layer.addSublayer(leftImageLayer)
       
        // the vertical line
        lineView.backgroundColor = .white
        addSubview(lineView)

        // the drag handle on the line
        arrowImageView.contentMode = .scaleAspectFit
        addSubview(arrowImageView)

        isUserInteractionEnabled = true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first
                else { return }
        let loc = t.location(in: self)
        pct = loc.x / bounds.width
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first
                else { return }
        let loc = t.location(in: self)
        pct = loc.x / bounds.width
    }
    
    private func updateView() {
        // move the vertical line to the touch point
        lineView.frame = CGRect(x: bounds.width * pct, y: bounds.minY, width: 2.5, height: bounds.height)

        // center the drag handle on the line
        arrowImageView.frame = CGRect(x: lineView.center.x - arrowSize / 2,
                                       y: bounds.midY - arrowSize / 2,
                                       width: arrowSize,
                                       height: arrowSize)

        // update the "left image" mask to the touch point
        var r = bounds
        r.size.width = bounds.width * pct
        
        // disable layer animation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        maskLayer.frame = r
        CATransaction.commit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        leftImageLayer.frame = bounds
        updateView()
    }
}

