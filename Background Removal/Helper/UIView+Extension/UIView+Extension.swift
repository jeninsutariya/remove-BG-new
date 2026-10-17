//
//  UIView+Extension.swift
//  Safe Mom
//
//  Created by Codeash Mac on 29/09/25.
//

import Foundation
import UIKit

class RectangularDashedView: UIView {

    @IBInspectable var customCornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = customCornerRadius
            layer.masksToBounds = customCornerRadius > 0
            setNeedsLayout()
        }
    }

    @IBInspectable var dashWidth: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }
    
    @IBInspectable var dashColor: UIColor = .clear {
        didSet { setNeedsLayout() }
    }
    
    @IBInspectable var dashLength: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }
    
    @IBInspectable var betweenDashesSpace: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    private var dashBorder: CAShapeLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        
        dashBorder?.removeFromSuperlayer()
        
        let dashBorder = CAShapeLayer()
        dashBorder.lineWidth = dashWidth
        dashBorder.strokeColor = dashColor.cgColor
        dashBorder.lineDashPattern = [dashLength, betweenDashesSpace] as [NSNumber]
        dashBorder.frame = bounds
        dashBorder.fillColor = nil
        
        let path: UIBezierPath
        if customCornerRadius > 0 {
            path = UIBezierPath(roundedRect: bounds, cornerRadius: customCornerRadius)
        } else {
            path = UIBezierPath(rect: bounds)
        }
        
        dashBorder.path = path.cgPath
        layer.addSublayer(dashBorder)
        self.dashBorder = dashBorder
    }
}
@IBDesignable
public class Gradient: UIView {
    @IBInspectable var startColor:   UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor:     UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}

    override public class var layerClass: AnyClass { CAGradientLayer.self }

    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

    func updatePoints() {
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? .init(x: 1, y: 0) : .init(x: 0, y: 0.5)
            gradientLayer.endPoint   = diagonalMode ? .init(x: 0, y: 1) : .init(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? .init(x: 0, y: 0) : .init(x: 0.5, y: 0)
            gradientLayer.endPoint   = diagonalMode ? .init(x: 1, y: 1) : .init(x: 0.5, y: 1)
        }
    }
    func updateLocations() {
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }
    func updateColors() {
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    }
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updatePoints()
        updateLocations()
        updateColors()
    }

}
