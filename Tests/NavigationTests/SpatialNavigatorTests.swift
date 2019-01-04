//
//  SpatialNavigatorTests.swift
//  NavigationTests
//
//  Created by Matthew Seaman on 1/2/19.
//

import XCTest
@testable import Navigate

final class SpatialNavigatorTests: XCTestCase {

    func testPerformance() {
        let navigator = SpatialNavigator(boardRect: CGRect(x: 0, y: 0, width: 500, height: 500))
        navigator.tileSize = CGSize(width: 10, height: 10)
        navigator.recalculate(from: .zero, to: CGPoint(x: 499, y: 499))
        self.measure {
            navigator.waitForRecalculation()
        }
        print("Result: \(navigator.path)")
    }

}
