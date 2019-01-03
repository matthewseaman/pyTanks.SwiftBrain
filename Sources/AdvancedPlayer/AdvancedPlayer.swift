//
//  AdvancedPlayer.swift
//  AdvancedPlayer
//
//  Created by Matthew Seaman on 12/31/18.
//

import PlayerSupport
import Brain

public class AdvancedPlayer: Player {
    
    public var log: Log!
    
    public var gameConfig: GameConfiguration!
    
    public var brain: Brain!
    
    public var playerDescription: String? {
        return "Swift client using the example AdvancedPlayer from pyTanks.SwiftBrain."
    }
    
    public init() {}
    
    public func connectedToServer() {
        log.print("connectedToServer", for: .debug)
        
        self.brain = Brain(boardWidth: gameConfig.map.width, height: gameConfig.map.height, mode: .momentary, priority: .mostOptimalPath)
        brain.log = log
    }
    
    public func roundStarting(withGameState gameState: GameState) {
        log.print("roundStarting", for: .debug)
        
        brain.remember(gameState)
        brain.navigationTarget = .point(x: 499, y: 0)
    }
    
    public func makeMove(withGameState gameState: GameState) -> [Command] {
        log.print("makeMove", for: .debug)
        
        brain.remember(gameState)
        return brain.optimalMove()
    }
    
    public func tankKilled() {
        log.print("tankKilled", for: .debug)
        
        // Nothing to do here
    }
    
    public func roundOver() {
        log.print("roundOver", for: .debug)
        
        brain.forgetRoundInfo()
    }
    
}
