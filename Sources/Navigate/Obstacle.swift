//
//  Obstacle.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics

/// Some entity on the game map that should be avoided when computing paths.
///
/// Obstacles can be either static or dynamic, but not all `Navigator`s support
/// dynamic obstacles.
public struct Obstacle {
    
    /// A rectangle representing the location of the obstacle in the game board's coordinate space.
    private let rect: CGRect
    
    /// Creates a new obstacle.
    ///
    /// - Parameter rect: A rectangle representing the location of the obstacle in the game board's coordinate space.
    public init(rect: CGRect) {
        self.rect = rect
    }

    /// Determines whether this obstacle intersects some rectangle.
    ///
    /// - Parameter other: Some rectangle in the game board's coordinate space.
    func intersects(_ other: CGRect) -> Bool {
        return self.rect.intersects(other)
    }
    
}
