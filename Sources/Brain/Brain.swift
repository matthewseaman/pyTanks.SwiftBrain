//
//  Brain.swift
//  Brain
//
//  Created by Matthew Seaman on 1/1/19.
//

import Foundation
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
        case tank(id: Int)
    }
    
    private let boardRect: CGRect
    
    private var navigator: Navigator
    
    private var mostRecentGameState: GameState?
    
    private var sendGoOnNextMove = false
    
    private var navigationRecalculationInterval: TimeInterval?
    
    private var lastNavigationRecalculation: Date?
    
    public var log: Log? {
        didSet {
            navigator.log = log
        }
    }
    
    public var navigationTarget: NavigationTarget? {
        didSet {
            navigationRecalculationInterval = nil
            recalculateNavigation()
        }
    }
    
    public init(config: GameConfiguration, mode: NavigationMode, priority: NavigationPriority) {
        self.boardRect = CGRect(x: 0, y: 0, width: config.map.width, height: config.map.height)
        self.navigator = Brain.makeNavigator(boardRect: boardRect, config: config, mode: mode, priority: priority)
    }
    
    public func remember(_ state: GameState) {
        self.mostRecentGameState = state
        
        if let navRecalcInterval = navigationRecalculationInterval, lastNavigationRecalculation == nil || -lastNavigationRecalculation!.timeIntervalSinceNow >= navRecalcInterval {
            recalculateNavigation()
        }
        
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
    
    public func optimalMove() -> Command? {
        if sendGoOnNextMove {
            sendGoOnNextMove = false
            return Command.go
        }
        
        guard let state = mostRecentGameState else {
            log?.print("Cannot determine moves without game state. Ensure state is passed to Brain.remember(_:).", for: .debug)
            return nil
        }
        
        guard navigationTarget != nil, let action = navigator.nextAction(from: state.myTank.center) else {
            log?.print("No recommended action from navigator.", for: .debug)
            return .go
        }
        
        switch action {
        case .go(let heading):
            if !state.myTank.isMoving {
                sendGoOnNextMove = true
            }
            return .turn(heading: Double(heading))
        case .stop:
            return .stop
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
        case .tank(let id):
            guard let tank = state.otherTanks[id] else { return }
            target = CGPoint(x: tank.centerX, y: tank.centerY)
            navigationRecalculationInterval = 1
        }
        
        lastNavigationRecalculation = Date()
        navigator.recalculate(from: state.myTank.center, to: target)
    }
    
    private static func makeNavigator(boardRect: CGRect, config: GameConfiguration, mode: NavigationMode, priority: NavigationPriority) -> Navigator {
        switch mode {
        case .momentary:
            switch priority {
            case .mostOptimalPath:
                let nav = SpatialNavigator(boardRect: boardRect)
                nav.tileSize = CGSize(width: config.tank.width, height: config.tank.height)
                return nav
            }
        }
    }
    
}
