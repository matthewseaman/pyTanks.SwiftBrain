//
//  CG+.swift
//  Compute
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics

extension CGPoint {
    
    public func distance(to other: CGPoint) -> CGFloat {
        return hypot(x - other.x, y - other.y)
    }
    
    public func vector(pointingTo other: CGPoint) -> CGVector {
        return CGVector(dx: other.x - x, dy: other.y - y)
    }
    
}

extension CGRect {
    
    public var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
}

extension CGVector {
    
    public var radiansCounterclockwiseFromPositiveXAxis: CGFloat {
        let angle = atan2(dy, dx)
        if angle < 0 {
            return 2 * .pi + angle
        }
        return angle
    }
    
}

// MARK: - Hashable

extension CGPoint: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
}

extension CGSize: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
    
}

extension CGRect: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(origin)
        hasher.combine(size)
    }
    
}
