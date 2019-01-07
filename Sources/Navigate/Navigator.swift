//
//  Navigator.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics
import PlayerSupport

/// A `Navigator` maintains a snapshot of the current game map and computes paths from a source to a destination point.
///
/// Conforming types may or may not support dynamic obstacles.
public protocol Navigator {
    
    /// Creates a new navigator.
    ///
    /// - Parameter boardRect: A rectangle representing the game board.
    init(boardRect: CGRect)
    
    /// A log to write any updates.
    var log: Log? { get set }
    
    /// A boolean indicating whether any obstacles are stored in the navigator.
    var hasObstacles: Bool { get }

    /// Stores an obstacle in the navigator to be taken into account during recalculation.
    func add(obstacle: Obstacle)
    
    /// Removes all stored obstacles.
    func removeAllObstacles()
    
    /// Computes and stores a path from `source` to `destination`. The speed vs. optimality of this algorithm depends on the conforming type.
    ///
    /// - Parameters:
    ///   - source: The starting point.
    ///   - destination: The target point.
    func recalculate(from source: CGPoint, to destination: CGPoint)
    
    /// Blocks the current thread until all previously requested recalculations have completed.
    func waitForRecalculation()
    
    /// Returns a suggested action to perform at the moment this method is called.
    ///
    /// This method does not recompute the path, but rather returns an action based on already-stored path data.
    ///
    /// - Parameter currentLocation: The current location of the entity that is traveling this path.
    /// - Returns: A momentary `NavigationAction`, or `nil` if there is no path or the destination was already reached.
    func nextAction(from currentLocation: CGPoint) -> NavigationAction?
    
}
