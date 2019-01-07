//
//  CG+.swift
//  Compute
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics

extension CGPoint {

    /// Computes the linear distance from this point to some other point.
    public func distance(to other: CGPoint) -> CGFloat {
        return hypot(x - other.x, y - other.y)
    }
    
    /// Returns a standard vector from this point to some other point.
    public func vector(pointingTo other: CGPoint) -> CGVector {
        return CGVector(dx: other.x - x, dy: other.y - y)
    }
    
}

extension CGRect {
    
    /// The center point of the rect.
    public var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    
}

extension CGVector {
    
    /// The direction of the vector, expressed as radians countercockwise from the positive x axis.
    ///
    /// This value assumes a downward-increasing y axis.
    public var radiansCounterclockwiseFromPositiveXAxis: CGFloat {
        // The game board has origin in top left, but headings are expressed counterclockwise.
        // Need to flip y axis.
        return atan2(-dy, dx)
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
