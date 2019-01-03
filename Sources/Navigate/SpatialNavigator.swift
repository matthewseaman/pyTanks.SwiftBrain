//
//  SpatialNavigator.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import Dispatch
import Foundation
import CoreGraphics
import Compute
import PlayerSupport

/// A `Navigator` that finds the shortest path in a 2D map at one moment in time.
public final class SpatialNavigator: Navigator {
    
    public var log: Log?
    
    private let boardRect: CGRect
    
    var tileSize: CGSize
    
    private var obstacles: [Obstacle] {
        get {
            return syncQueue.sync { _obstacles }
        }
        set {
            syncQueue.async {
                self._obstacles = newValue
            }
        }
    }
    
    private var _obstacles = [Obstacle]()
    
    private var path: [CGPoint] {
        get {
            return syncQueue.sync { _path }
        }
        set {
            syncQueue.async {
                self._path = newValue
            }
        }
    }
    
    private var _path = [CGPoint]()
    
    private var openList = Set<Node>()
    
    private var closedList = Set<Node>()
    
    private let syncQueue = DispatchQueue(label: "SpatialNavigator-sync", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    private let backgroundQueue = DispatchQueue(label: "SpatialNavigator-bk", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    public init(boardRect: CGRect) {
        self.boardRect = boardRect
        self.tileSize = CGSize(width: 1, height: 1)
    }
    
    public var hasObstacles: Bool {
        return !obstacles.isEmpty
    }
    
    public func add(obstacle: Obstacle) {
        obstacles.append(obstacle)
    }
    
    public func removeAllObstacles() {
        obstacles = []
    }
    
    public func recalculate(from source: CGPoint, to destination: CGPoint) {
        backgroundQueue.async {
            let startTime = Date()
            self.log?.print("Starting spatial navigation calculation from \(source) to \(destination) on CPU.", for: .gameEvents)
            
            let path = self.path(from: source, to: destination)
            self.path = path
            
            let endTime = Date()
            self.log?.print("Finished spatial navigation calculation from \(source) to \(destination) in \(endTime.timeIntervalSince(startTime)) seconds.", for: .gameEvents)
        }
    }
    
    func path(from source: CGPoint, to destination: CGPoint) -> [CGPoint] {
        let start = Node(point: source, boardRect: boardRect, tileSize: tileSize)
        let end = Node(point: destination, boardRect: boardRect, tileSize: tileSize)
        
        closedList = []
        openList = [start]
        
        start.shortestFoundDistanceFromSource = 0
        start.estimatedDistanceFromDestination = start.estimatedDistance(to: end)
        
        while !openList.isEmpty {
            let node = openList.min(by: { $0.estimatedScore < $1.estimatedScore })!
            
            if node == end {
                return reconstructedPath(from: node)
            }
            
            for neighbor in node.neighbors() {
                let newShortestDistanceFromSource = node.shortestFoundDistanceFromSource + 1
                let betterDistanceFromSource = newShortestDistanceFromSource < neighbor.shortestFoundDistanceFromSource
                if openList.contains(neighbor) && betterDistanceFromSource {
                    openList.remove(neighbor)
                }
                if closedList.contains(neighbor) && betterDistanceFromSource {
                    closedList.remove(neighbor)
                }
                if !openList.contains(neighbor) && !closedList.contains(neighbor) {
                    neighbor.shortestFoundDistanceFromSource = newShortestDistanceFromSource
                    neighbor.estimatedDistanceFromDestination = neighbor.estimatedDistance(to: end)
                    openList.insert(neighbor)
                }
            }
            
            closedList.insert(node)
        }
        
        return []
    }
    
    private func reconstructedPath(from node: Node) -> [CGPoint] {
        return sequence(first: node, next: { $0.parent }).map { $0.rect.center }
    }
    
    public func waitForRecalculation() {
        backgroundQueue.sync {}
    }
    
    public func nextAction(from currentLocation: CGPoint) -> NavigationAction? {
        var currentPath = path
        guard let nextPoint = currentPath.first else {
            return nil
        }
        
        if currentLocation.distance(to: nextPoint) < 1 {
            currentPath.removeFirst()
            self.path = currentPath
            return nextAction(from: currentLocation)
        } else  {
            return .go(heading: currentLocation.vector(pointingTo: nextPoint).radiansCounterclockwiseFromPositiveXAxis)
        }
    }
    
    fileprivate final class Node {
        
        let xIndex: Int
        
        let yIndex: Int
        
        let rect: CGRect
        
        let boardRect: CGRect
        
        let tileSize: CGSize
        
        var parent: Node?
        
        var shortestFoundDistanceFromSource: Int
        
        var estimatedDistanceFromDestination: Int
        
        convenience init(point: CGPoint, boardRect: CGRect, tileSize: CGSize) {
            let xIndex = Int(((point.x + 1) / tileSize.width).rounded(.up))
            let yIndex = Int(((point.y + 1) / tileSize.height).rounded(.up))
            self.init(xIndex: xIndex, yIndex: yIndex, boardRect: boardRect, tileSize: tileSize, parent: nil)
        }
        
        init(xIndex: Int, yIndex: Int, boardRect: CGRect, tileSize: CGSize, parent: Node?) {
            self.parent = parent
            self.xIndex = xIndex
            self.yIndex = yIndex
            
            let origin = CGPoint(x: tileSize.width * CGFloat(xIndex), y: tileSize.height * CGFloat(yIndex))
            self.rect = CGRect(origin: origin, size: tileSize)
            self.boardRect = boardRect
            self.tileSize = tileSize
            
            self.shortestFoundDistanceFromSource = .max
            self.estimatedDistanceFromDestination = .max
        }
        
        var estimatedScore: Int {
            return shortestFoundDistanceFromSource + estimatedDistanceFromDestination
        }
        
        func estimatedDistance(to destination: Node) -> Int {
            return abs(destination.xIndex + xIndex) + abs(destination.yIndex + yIndex)
        }
        
        func neighbors() -> [Node] {
            let positions = [
                (xIndex, yIndex - 1), // Up
                (xIndex, yIndex + 1), // Down
                (xIndex - 1, yIndex), // Left
                (xIndex + 1, yIndex) // Right
            ]
            
            let maxX = Int(boardRect.width / tileSize.width) - 1
            let maxY = Int(boardRect.height / tileSize.height) - 1
            guard !positions.contains(where: { $0.0 < 0 || $0.0 > maxX || $0.1 < 0 || $0.1 > maxY }) else { return [] }
            
            return positions.map { Node(xIndex: $0.0, yIndex: $0.1, boardRect: boardRect, tileSize: rect.size, parent: self) }
        }
    }
    
}

extension SpatialNavigator.Node: Hashable {
    
    static func ==(lhs: SpatialNavigator.Node, rhs: SpatialNavigator.Node) -> Bool {
        return (lhs.xIndex, lhs.yIndex) == (rhs.xIndex, rhs.yIndex)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(xIndex)
        hasher.combine(yIndex)
    }
    
}
