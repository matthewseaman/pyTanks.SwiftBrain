//
//  Navigator.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics
import PlayerSupport

public protocol Navigator {
    
    init(boardRect: CGRect)
    
    var log: Log? { get set }
    
    var hasObstacles: Bool { get }
    
    func add(obstacle: Obstacle)
    
    func removeAllObstacles()
        
    func recalculate(from source: CGPoint, to destination: CGPoint)
    
    func waitForRecalculation()
    
    func nextAction(from currentLocation: CGPoint) -> NavigationAction?
    
}
