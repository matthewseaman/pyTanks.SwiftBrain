//
//  NavigationAction.swift
//  Navigate
//
//  Created by Matthew Seaman on 12/31/18.
//

import CoreGraphics

/// A momentary action that may be suggested by a `Navigator`.
public enum NavigationAction {
    /// Go in a certain direction, where the heading is expressed in radians couterclockwise from the positive x axis.
    case go(heading: CGFloat)
    /// Stop for the moment. This may be suggested in order to avoid colliding with a dynamic obstacle as it passes, for example.
    case stop
}
