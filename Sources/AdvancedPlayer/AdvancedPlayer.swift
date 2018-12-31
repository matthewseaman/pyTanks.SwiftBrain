//
//  AdvancedPlayer.swift
//  AdvancedPlayer
//
//  Created by Matthew Seaman on 12/31/18.
//

import PlayerSupport

public struct AdvancedPlayer: Player {
    
    public var log: Log!
    
    public var gameConfig: GameConfiguration!
    
    public var playerDescription: String? {
        return "Swift client using the example AdvancedPlayer from pyTanks.SwiftBrain."
    }
    
    public init() {}
    
    public func connectedToServer() {
        log.print("connectedToServer", for: .debug)
        
        // Nothing special to do here
    }
    
    public func roundStarting(withGameState gameState: GameState) {
        log.print("roundStarting", for: .debug)
        
        // Nothing much to do here either
    }
    
    public mutating func makeMove(withGameState gameState: GameState) -> [Command] {
        log.print("makeMove", for: .debug)
        
        return []
    }
    
    public func tankKilled() {
        log.print("tankKilled", for: .debug)
        
        // Nothing to do here
    }
    
    public func roundOver() {
        log.print("roundOver", for: .debug)
        
        // Nothing to do here
    }
    
}
