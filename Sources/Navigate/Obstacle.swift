//
//  Obstacle.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics

public struct Obstacle {
    
    let rect: CGRect
    
    public init(rect: CGRect) {
        self.rect = rect
    }
    
    func intersects(_ other: CGRect) {
        self.rect.intersects(other)
    }
    
}
