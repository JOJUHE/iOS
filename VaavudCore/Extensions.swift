//
//  Extensions.swift
//  Vaavud
//
//  Created by Gustaf Kugelberg on 10/02/15.
//  Copyright (c) 2015 Andreas Okholm. All rights reserved.
//

import Foundation
import MediaPlayer

class Plot: UIView {
    let f: CGFloat -> CGFloat
    let n: Int
    let range: (CGFloat, CGFloat)
    let color = UIColor.darkGrayColor()
    
    init(frame: CGRect, f: CGFloat -> CGFloat, range: (CGFloat, CGFloat) = (0, 1), n: Int = 10) {
        self.f = f
        self.range = range
        self.n = n
        super.init(frame: frame)
        backgroundColor = UIColor.lightGrayColor()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        color.setFill()
        
        let path = UIBezierPath()
        path.moveToPoint(bounds.lowerLeft)
        for i in 0...n {
            let x = range.0 + (CGFloat(i)/CGFloat(n))*(range.1 - range.0)
            path.addLineToPoint(CGPoint(x: bounds.minX + x*bounds.width, y: bounds.maxY - f(x)*bounds.height))
        }
        path.addLineToPoint(bounds.lowerRight)
        path.closePath()
        path.fill()
    }
}

func sigmoid(x: CGFloat) -> CGFloat {
    return 1/(1 + exp(-x))
}

func ease(x: CGFloat) -> CGFloat {
    return x < 0.5 ? 4*pow(x, 3) : pow(2*x - 2, 3)/2 + 1
}

extension UIViewController {
    func hideVolumeHUD() {
        view.addSubview(MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 100, height: 100)))
    }
}

// MARK: CGAffineTransform

typealias Affine = CGAffineTransform

extension CGAffineTransform {
    static var id: CGAffineTransform { return CGAffineTransformIdentity }
    
    init() {
        self = CGAffineTransform.id
    }
    
    func translate(x: CGFloat, _ y: CGFloat) -> CGAffineTransform {
        return CGAffineTransformTranslate(self, x, y)
    }
    
    func rotate(angle: CGFloat) -> CGAffineTransform {
        return CGAffineTransformRotate(self, angle)
    }
    
    func scale(x: CGFloat, _ y: CGFloat) -> CGAffineTransform {
        return CGAffineTransformScale(self, x, y)
    }
    
    func scale(r: CGFloat) -> CGAffineTransform {
        return scale(r, r)
    }
    
    func apply(rect: CGRect) -> CGRect {
        return CGRectApplyAffineTransform(rect, self)
    }
    
    func apply(point: CGPoint) -> CGPoint {
        return CGPointApplyAffineTransform(point, self)
    }
    
    var inverse: CGAffineTransform {
        return CGAffineTransformInvert(self)
    }

    static func translation(x: CGFloat, _ y: CGFloat) -> CGAffineTransform {
        return CGAffineTransformMakeTranslation(x, y)
    }
    
    static func rotation(angle: CGFloat) -> CGAffineTransform {
        return CGAffineTransformMakeRotation(angle)
    }
    
    static func scaling(sx: CGFloat, _ sy: CGFloat) -> CGAffineTransform {
        return CGAffineTransformMakeScale(sx, sy)
    }
    
    static func scaling(r: CGFloat) -> CGAffineTransform {
        return self.scaling(r, r)
    }
}

func *(lhs: Affine, rhs: Affine) -> Affine {
    return CGAffineTransformConcat(lhs, rhs)
}


// MARK: Points

func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func * (lhs: CGFloat, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs*rhs.x, y: lhs*rhs.y)
}

func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func * (lhs: Polar, rhs: Polar) -> Polar {
    return Polar(r: lhs.r*rhs.r, phi: lhs.phi + rhs.phi)
}

func dist(p: CGPoint, q: CGPoint) -> CGFloat {
    return (p - q).length
}

struct Polar {
    var r: CGFloat
    var phi: CGFloat
    
    var cartesian: CGPoint {
        return CGPoint(x: r*cos(phi), y: r*sin(phi))
    }
    
    func cartesian(center: CGPoint) -> CGPoint {
        return CGPoint(x: center.x + r*cos(phi), y: center.y + r*sin(phi))
    }

    func rotated(phi: CGFloat) -> Polar {
        return self*Polar(r: 1, phi: phi)
    }
}

func rotate(phi: CGFloat)(p: Polar) -> Polar {
    return p*Polar(r: 1, phi: phi)
}

extension CGFloat {
    var radians: CGFloat {
        return self*π/180
    }
    
    var degrees: CGFloat {
        return self*180/π
    }
}

extension CGPoint {
    var length: CGFloat {
        return sqrt(x*x + y*y)
    }
    
    var polar: Polar {
        return Polar(r: length, phi: atan2(y, x))
    }
    
    init(polar: Polar) {
        x = polar.cartesian.x
        y = polar.cartesian.y
    }
    
    init(r: CGFloat, phi: CGFloat) {
        self.init(polar: Polar(r: r, phi: phi))
    }
    
    func approach(goal: CGPoint, by factor: CGFloat) -> CGPoint {
        return (1 - factor)*self + factor*goal
    }
}

func mod(i: Int, n: Int) -> Int {
    return ((i % n) + n) % n
}

func mod(i: CGFloat, n: CGFloat) -> CGFloat {
    return ((i % n) + n) % n
}

extension CGRect {
    init(center: CGPoint, size: CGSize) {
        self.init(origin: CGPoint(x: center.x - size.width/2, y: center.y - size.height/2), size: size)
    }

    func grow(delta: CGFloat) -> CGRect {
        let dw = delta*width
        let dh = delta*height
        
        return CGRect(x: origin.x - dw, y: origin.y - dh, width: width + 2*dw, height: height + 2*dh)
    }
    
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
    var lowerRight: CGPoint {
        return CGPoint(x: maxX, y: maxY)
    }
    
    var lowerMid: CGPoint {
        return CGPoint(x: midX, y: maxY)
    }
    
    var lowerLeft: CGPoint {
        return CGPoint(x: minX, y: maxY)
    }
    
    var upperRight: CGPoint {
        return CGPoint(x: maxX, y: minY)
    }
    
    var upperMid: CGPoint {
        return CGPoint(x: midX, y: minY)
    }

    var upperLeft: CGPoint {
        return CGPoint(x: minX, y: minY)
    }
    
    func insetX(dx: CGFloat) -> CGRect {
        return CGRect(x: origin.x + dx, y: origin.y, width: width - 2*dx, height: height)
    }
    
    func insetY(dy: CGFloat) -> CGRect {
        return CGRect(x: origin.x, y: origin.y + dy, width: width, height: height - 2*dy)
    }
    
    func move(dr: CGPoint) -> CGRect {
        return CGRect(origin: origin + dr, size: size)
    }
}
