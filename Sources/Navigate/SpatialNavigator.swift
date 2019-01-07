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

/// A signpost ID to use when signposting `SpatialNavigator`.
private let signpostId = OSSignpostID(log: SignpostLog.navigationLog)

/// A `Navigator` that finds the shortest path in a 2D map at one moment in time.
///
/// `SpatialNavigator` uses the standard A* algorithm, optimized for speed and running entirely on the CPU.
///
/// This navigator does not support dynamic obstacles. If you attempt adding dynamic obstacles, they will be treated as static.
public final class SpatialNavigator: Navigator {
    
    public var log: Log?
    
    /// A rectangle representing the game map.
    private let boardRect: CGRect
    
    /// The size of tiles/nodes, which represent the smallest navigatable space on the board.
    ///
    /// Smaller sizes take longer to compute but result in more concise paths. Setting a tile size smaller than the entity that is navigating may result
    /// in gettting stuck on walls.
    public var tileSize: CGSize
    
    /// The maximum 0-based x tile index.
    private let maxXTileIndex: Int
    /// The maximum 0-based y tile index.
    private let maxYTileIndex: Int
    
    /// The stored obstacles, which are always treated as static.
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
    
    /// The raw stored obstacles.
    ///
    /// - Warning: Access to this property is not synchronized across threads.
    private var _obstacles = [Obstacle]()
    
    /// The most-recently computed path, as a collection of points.
    ///
    /// This is stored in an `AnyCollection` so that lazy collections may be used to reduce calculation time.
    private(set) var path: AnyCollection<CGPoint> {
        get {
            return syncQueue.sync { _path }
        }
        set {
            syncQueue.async {
                self._path = newValue
            }
        }
    }
    
    /// The raw stored path.
    ///
    /// - Warning: Access to this property is not synchronized across threads.
    private var _path = AnyCollection<CGPoint>([])
    
    /// The obstacles to use for the current in-flight recalculation.
    ///
    /// This property is set at the beginning of recalculations to the result of accessing `obstacles`.
    /// In this way, we eagerly access the obstacles in a synchronized manner only once, saving a lot of
    /// time not having to context switch between threads as often.
    private var obstaclesForCurrentRecalculation = [Obstacle]()
    
    /// The list of nodes currently up for consideration as the next in the path.
    private var openList = [CGPoint: Node]()
    
    /// The list of nodes already visited.
    private var closedList = Set<Node>()
    
    /// A dispatch queue for synchronizing access to stored properties that may be accessed by multiple threads.
    private let syncQueue = DispatchQueue(label: "SpatialNavigator-sync", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem, target: nil)
    
    /// A dispatch queue for performing path calculations.
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
    
    /// Finds a path from `source` to `destination`, if one exists.
    ///
    /// - Parameters:
    ///   - source: The point in the game board to start with.
    ///   - destination: The point in the game board to end with.
    /// - Returns: A collection of points representing the path.
    private func path(from source: CGPoint, to destination: CGPoint) -> AnyCollection<CGPoint> {
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
        
        return AnyCollection([])
    }
    
    /// Returns a complete path by following the parent chain from the last node.
    ///
    /// - Parameter node: The last (destination) node.
    /// - Returns: A reconstructed path.
    private func reconstructedPath(from node: Node) -> AnyCollection<CGPoint> {
        return AnyCollection(Array(sequence(first: node, next: { $0.parent })).lazy.reversed().map({ $0.rect.center }))
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
    
    /// A `Node` represents one tile on the board.
    fileprivate final class Node {
        
        /// The x index of the tile.
        let xIndex: Int
        
        /// The y index of the tile.
        let yIndex: Int
        
        /// A point of the form `(xIndex, yIndex)`. Since these represent tile coordinates, this point is not in the game board's coordinate space.
        var tilePoint: CGPoint {
            return CGPoint(x: xIndex, y: yIndex)
        }
        
        /// The rect covered by the tile, in the game board's coordinate space.
        let rect: CGRect
        
        /// An unowned reference to the navigator that created this node.
        private unowned let navigator: SpatialNavigator
        
        /// This node's ideal predecessor in a path from source to destination.
        var parent: Node?
        
        /// The best-path distance from the start node.
        var shortestFoundDistanceFromSource: Int
        
        /// The heuristic distance from this node to the destination node.
        var estimatedDistanceFromDestination: Int
        
        /// Creates a new node at a given point in the game board. The node will represent the entire tile `point` falls into.
        ///
        /// - Parameters:
        ///   - point: A point on the game board.
        ///   - navigator: The navigator creating this node.
        convenience init(point: CGPoint, navigator: SpatialNavigator) {
            let xIndex = Int(((point.x) / navigator.tileSize.width).rounded(.down))
            let yIndex = Int(((point.y) / navigator.tileSize.height).rounded(.down))
            self.init(xIndex: xIndex, yIndex: yIndex, parent: nil, navigator: navigator)
        }
        
        /// Creates a new node at the given tile coordinate.
        ///
        /// - Parameters:
        ///   - xIndex: The x index of the tile.
        ///   - yIndex: The y index of the tile.
        ///   - parent: The ideal predecessor of this node in a path from source to destination.
        ///   - navigator: The navigator creating this node.
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
        
        /// An estimated score of how ideal this node is to be included in the path.
        ///
        /// This is the sum of `shortestFoundDistanceFromSource` and `estimatedDistanceFromDestination`.
        var estimatedScore: Int {
            return shortestFoundDistanceFromSource + estimatedDistanceFromDestination
        }
        
        /// Computes the heuristic tile distance from this node to some other node.
        func estimatedDistance(to destination: Node) -> Int {
            return abs(destination.xIndex - xIndex) + abs(destination.yIndex - yIndex)
        }

        /// Returns all nodes that may be navigated to in exactly one tile step in any direction, and that are
        /// not obstructed by obstacles or otherwise outside of game board bounds.
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
