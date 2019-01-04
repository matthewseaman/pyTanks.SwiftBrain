//
//  SpatialNavigator.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import os
import Dispatch
import Foundation
import CoreGraphics
import Compute
import PlayerSupport

private let signpostId = OSSignpostID(log: SignpostLog.navigationLog)

/// A `Navigator` that finds the shortest path in a 2D map at one moment in time.
public final class SpatialNavigator: Navigator {
    
    public var log: Log?
    
    private let boardRect: CGRect
    
    public var tileSize: CGSize
    
    private let maxXTileIndex: Int
    private let maxYTileIndex: Int
    
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
    
    private(set) var path: [CGPoint] {
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
    
    private var obstaclesForCurrentRecalculation = [Obstacle]()
    
    private var openList = [CGPoint: Node]()
    
    private var closedList = Set<Node>()
    
    private let syncQueue = DispatchQueue(label: "SpatialNavigator-sync", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    private let backgroundQueue = DispatchQueue(label: "SpatialNavigator-bk", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    public init(boardRect: CGRect) {
        self.boardRect = boardRect
        self.tileSize = CGSize(width: 1, height: 1)
        
        self.maxXTileIndex = Int(boardRect.width / tileSize.width) - 1
        self.maxYTileIndex = Int(boardRect.height / tileSize.height) - 1
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
            os_signpost(.begin, log: SignpostLog.navigationLog, name: "Spatial Pathfinding")
            
            let path = self.path(from: source, to: destination)
            self.path = path
            
            let endTime = Date()
            self.log?.print("Finished spatial navigation calculation from \(source) to \(destination) in \(endTime.timeIntervalSince(startTime)) seconds.", for: .gameEvents)
            os_signpost(.end, log: SignpostLog.navigationLog, name: "Spatial Pathfinding")
        }
    }
    
    private func path(from source: CGPoint, to destination: CGPoint) -> [CGPoint] {
        self.obstaclesForCurrentRecalculation = self.obstacles
        
        let start = Node(point: source, navigator: self)
        let end = Node(point: destination, navigator: self)
        
        closedList = []
        openList = [start.tilePoint: start]
        
        start.shortestFoundDistanceFromSource = 0
        start.estimatedDistanceFromDestination = start.estimatedDistance(to: end)
        
        while !openList.isEmpty {
            let node = openList.values.min(by: { $0.estimatedScore < $1.estimatedScore })!
            closedList.insert(node)
            openList[node.tilePoint] = nil
            
            if node == end {
                return reconstructedPath(from: node)
            }
            
            let newShortestDistanceFromSource = node.shortestFoundDistanceFromSource + 1
            
            for neighbor in node.neighbors() {
                if closedList.contains(neighbor) {
                    continue
                }
                
                if let existing = openList[neighbor.tilePoint] {
                    if newShortestDistanceFromSource < existing.shortestFoundDistanceFromSource {
                        existing.shortestFoundDistanceFromSource = newShortestDistanceFromSource
                        existing.parent = neighbor.parent
                    }
                } else {
                    neighbor.shortestFoundDistanceFromSource = newShortestDistanceFromSource
                    neighbor.estimatedDistanceFromDestination = neighbor.estimatedDistance(to: end)
                    openList[neighbor.tilePoint] = neighbor
                }
            }
        }
        
        return []
    }
    
    private func reconstructedPath(from node: Node) -> [CGPoint] {
        return sequence(first: node, next: { $0.parent }).reversed().map { $0.rect.center }
    }
    
    public func waitForRecalculation() {
        backgroundQueue.sync {}
    }
    
    public func nextAction(from currentLocation: CGPoint) -> NavigationAction? {
        var currentPath = path
        guard let nextPoint = currentPath.first else {
            return nil
        }
        
        if currentLocation.distance(to: nextPoint) < tileSize.width / 4 {
            currentPath.removeFirst()
            self.path = currentPath
            return nextAction(from: currentLocation)
        } else {
            let heading = currentLocation.vector(pointingTo: nextPoint).radiansCounterclockwiseFromPositiveXAxis
            log?.print("\(currentLocation) -> \(nextPoint) turn \(heading)", for: .debug)
            return .go(heading: heading)
        }
    }
    
    fileprivate final class Node {
        
        let xIndex: Int
        
        let yIndex: Int
        
        var tilePoint: CGPoint {
            return CGPoint(x: xIndex, y: yIndex)
        }
        
        let rect: CGRect
        
        private unowned let navigator: SpatialNavigator
        
        var parent: Node?
        
        var shortestFoundDistanceFromSource: Int
        
        var estimatedDistanceFromDestination: Int
        
        convenience init(point: CGPoint, navigator: SpatialNavigator) {
            let xIndex = Int(((point.x) / navigator.tileSize.width).rounded(.down))
            let yIndex = Int(((point.y) / navigator.tileSize.height).rounded(.down))
            self.init(xIndex: xIndex, yIndex: yIndex, parent: nil, navigator: navigator)
        }
        
        init(xIndex: Int, yIndex: Int, parent: Node?, navigator: SpatialNavigator) {
            self.parent = parent
            self.xIndex = xIndex
            self.yIndex = yIndex
            
            let origin = CGPoint(x: navigator.tileSize.width * CGFloat(xIndex), y: navigator.tileSize.height * CGFloat(yIndex))
            self.rect = CGRect(origin: origin, size: navigator.tileSize)
            self.navigator = navigator
            
            self.shortestFoundDistanceFromSource = .max
            self.estimatedDistanceFromDestination = .max
        }
        
        var estimatedScore: Int {
            return shortestFoundDistanceFromSource + estimatedDistanceFromDestination
        }
        
        func estimatedDistance(to destination: Node) -> Int {
            return abs(destination.xIndex - xIndex) + abs(destination.yIndex - yIndex)
        }
        
        func neighbors() -> [Node] {
            let positions = [
                (xIndex, yIndex - 1), // Up
                (xIndex, yIndex + 1), // Down
                (xIndex - 1, yIndex), // Left
                (xIndex + 1, yIndex) // Right
            ]
            
            var nodes = [Node]()
            nodes.reserveCapacity(positions.count)
            
            for (x, y) in positions {
                guard x >= 0 && x <= navigator.maxXTileIndex && y >= 0 && y <= navigator.maxYTileIndex else { continue }
                let node = Node(xIndex: x, yIndex: y, parent: self, navigator: navigator)
                guard !navigator.obstaclesForCurrentRecalculation.contains(where: { $0.intersects(node.rect) }) else { continue }
                nodes.append(node)
            }
            
            return nodes
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

extension SpatialNavigator.Node: CustomStringConvertible {
    
    var description: String {
        return "(\(xIndex), \(yIndex))"
    }
    
}
