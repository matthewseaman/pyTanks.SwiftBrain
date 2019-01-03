//
//  Brain.swift
//  Brain
//
//  Created by Matthew Seaman on 1/1/19.
//

import CoreGraphics
import PlayerSupport
import Navigate

open class Brain {
    
    public enum NavigationPriority {
        case mostOptimalPath
    }
    
    public enum NavigationMode {
        case momentary
    }
    
    public enum NavigationTarget {
        case point(x: Double, y: Double)
    }
    
    private let boardRect: CGRect
    
    private var navigator: Navigator
    
    private var mostRecentGameState: GameState?
    
    public var log: Log? {
        didSet {
            navigator.log = log
        }
    }
    
    public var navigationTarget: NavigationTarget? {
        didSet {
            recalculateNavigation()
        }
    }
    
    public init(boardWidth width: Double, height: Double, mode: NavigationMode, priority: NavigationPriority) {
        self.boardRect = CGRect(x: 0, y: 0, width: width, height: height)
        self.navigator = Brain.makeNavigator(boardRect: boardRect, mode: mode, priority: priority)
    }
    
    public func remember(_ state: GameState) {
        self.mostRecentGameState = state
        
        guard !navigator.hasObstacles else { return }
        
        for wall in state.walls {
            let obstacle = Obstacle(rect: CGRect(x: wall.centerX - wall.width / 2, y: wall.centerY - wall.height / 2, width: wall.width, height: wall.height))
            navigator.add(obstacle: obstacle)
        }
    }
    
    public func forgetRoundInfo() {
        navigator.removeAllObstacles()
        mostRecentGameState = nil
    }
    
    public func optimalMove() -> [Command] {
        guard let state = mostRecentGameState else {
            log?.print("Cannot determine moves without game state. Ensure state is passed to Brain.remember(_:).", for: .debug)
            return []
        }
        
        guard navigationTarget != nil, let action = navigator.nextAction(from: state.myTank.center) else {
            log?.print("No recommended action from navigator.", for: .debug)
            return [.go]
        }
        
        switch action {
        case .go(let heading):
            return [.turn(heading: Double(heading)), .go]
        case .stop:
            return [.stop]
        }
    }
    
    private func recalculateNavigation() {
        guard let state = mostRecentGameState else {
            log?.print("Cannot navigate without game state. Ensure state is passed to Brain.remember(_:).", for: .debug)
            return
        }
        
        guard let navTarget = navigationTarget else {
            // We don't even need the navigator
            return
        }
        
        let target: CGPoint
        switch navTarget {
        case .point(let x, let y):
            target = CGPoint(x: x, y: y)
        }
        
        navigator.recalculate(from: state.myTank.center, to: target)
    }
    
    private static func makeNavigator(boardRect: CGRect, mode: NavigationMode, priority: NavigationPriority) -> Navigator {
        switch mode {
        case .momentary:
            switch priority {
            case .mostOptimalPath:
                return SpatialNavigator(boardRect: boardRect)
            }
        }
    }
    
}
