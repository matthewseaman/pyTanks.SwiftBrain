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

/// A `Brain` is the central class for public use by pyTanks.SwiftBrain clients.
///
/// It is expected that each `Player` will maintain exactly one unique `Brain` instance.
///
/// You set the `Brain`'s goal by setting `navigationTarget`, give it game state info by calling `remember(_:)`, and determine a move for a frame
/// by calling `optimalMove()`.
open class Brain {
    
    /// A type representing a desired priority of navigation.
    public enum NavigationPriority {
        /// A priority to find the most optimal path, even if this takes awhile.
        case mostOptimalPath
    }
    
    /// A type representing a navigation mode.
    public enum NavigationMode {
        /// Navigation will only take into account the game board at the moment in time when recalculation starts.
        ///
        /// This mode is not capable of dodging bullets or avoiding collision with other tanks.
        case momentary
    }
    
    /// A type describing the desired location to navigate to.
    public enum NavigationTarget: Equatable {
        /// A target of a specific point on the game board.
        case point(x: Double, y: Double)
        /// A target of a particular tank with given id. This produces the effect of following a tank.
        case tank(id: Int)
    }
    
    /// A rectangle representing the game board.
    private let boardRect: CGRect
    
    /// The navigator responsible for navigating the board.
    private var navigator: Navigator
    
    /// The most-recently "remembered" game state.
    private var mostRecentGameState: GameState?
    
    /// If `true`, the next call to `optimalMove()` will return `.go` and return.
    private var sendGoOnNextMove = false
    
    /// An optional time interval on which to recalculate navigation.
    private var navigationRecalculationInterval: TimeInterval?
    
    /// The exact date/time of the most recent navigation recalculation.
    private var lastNavigationRecalculation: Date?
    
    /// A log to write info to.
    public var log: Log? {
        didSet {
            navigator.log = log
        }
    }
    
    /// The desired location to navigate to.
    public var navigationTarget: NavigationTarget? {
        didSet {
            guard navigationTarget != oldValue || lastNavigationRecalculation == nil else { return }
            navigationRecalculationInterval = nil
            recalculateNavigation()
        }
    }
    
    /// Creates a new `Brain` for a `Player`.
    ///
    /// - Parameters:
    ///   - config: The game configuration.
    ///   - mode: The navigation mode.
    ///   - priority: The navigation priority.
    public init(config: GameConfiguration, mode: NavigationMode = .momentary, priority: NavigationPriority = .mostOptimalPath) {
        self.boardRect = CGRect(x: 0, y: 0, width: config.map.width, height: config.map.height)
        self.navigator = Brain.makeNavigator(boardRect: boardRect, config: config, mode: mode, priority: priority)
    }

    /// Updates the brain with info from a `GameState`.
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
    
    /// Removes all round-specific info from the brain.
    public func forgetRoundInfo() {
        navigator.removeAllObstacles()
        mostRecentGameState = nil
        sendGoOnNextMove = false
        navigationRecalculationInterval = nil
        lastNavigationRecalculation = nil
    }
    
    /// Calculates and returns the optimal command for this moment in time.
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
    
    /// Kicks off navigation recalculation.
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
    
    /// Returns an appropriate `Navigator` based on `mode` and `priority`.
    ///
    /// - Parameters:
    ///   - boardRect: A rectangle representing the game board.
    ///   - config: The game configuration.
    ///   - mode: The navigation mode.
    ///   - priority: The navigation priority.
    /// - Returns: A `Navigator`.
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
