//
//  Quadratic.swift
//  Compute
//
//  Created by Matthew Seaman on 1/8/19.
//

import Accelerate

/// A type that represents an equation of the form ax^2 + bx + c = 0.
public struct Quadratic {
    
    /// The x^2 coefficient.
    private let a: Float
    
    /// The x coefficient.
    private let b: Float
    
    /// The constant term.
    private let c: Float
    
    /// Creates a new `Quadratic` of the form ax^2 + bx + c = 0.
    ///
    /// - Parameters:
    ///   - a: The x^2 coefficient.
    ///   - b: The x coefficient.
    ///   - c: The constant term.
    public init(a: Float, b: Float, c: Float) {
        self.a = a
        self.b = b
        self.c = c
    }
    
    /// Calculates and returns solutions for all `quadratics`.
    ///
    /// There are always 2 solutions per quadratic. Any solutions that would end up being complex will be NAN.
    ///
    /// CPU vector instructions are used to accelerate the calculation.
    ///
    /// - Parameter quadratics: The quadratics to solve.
    /// - Returns: An array where each element is a tuple that contains the 2 solutions.
    public static func solutions(for quadratics: [Quadratic]) -> [(Float, Float)] {
        // -b +- √(discriminant)
        // ---------------------
        //         2a
        
        var vForce_n = Int32(quadratics.count)
        let vDSP_n = vDSP_Length(vForce_n)
        
        var a = quadratics.map { $0.a }
        var b = quadratics.map { $0.b }
        var c = quadratics.map { $0.c }
        
        // discriminant
        var discriminant = discriminants(a: &a, b: &b, c: &c, n: vDSP_n)
        
        // √(discriminant)
        var sqrtD = [Float](repeating: 0, count: quadratics.count)
        vvsqrtf(&sqrtD, &discriminant, &vForce_n)
        
        // -b
        var negB = [Float](repeating: 0, count: quadratics.count)
        vDSP_vneg(&b, 1 /* Stride */, &negB, 1 /* Stride */, vDSP_n)
        
        // 2a
        var a2 = [Float](repeating: 0, count: quadratics.count)
        var constant2: Float = 2
        vDSP_vsmul(&a, 1 /* Stride */, &constant2, &a2, 1 /* Stride */, vDSP_n)
        
        // +
        var numerator1 = [Float](repeating: 0, count: quadratics.count)
        vDSP_vadd(&negB, 1 /* Stride */, &sqrtD, 1 /* Stride */, &numerator1, 1 /* Stride */, vDSP_n)
        
        // -
        var numerator2 = [Float](repeating: 0, count: quadratics.count)
        vDSP_vsub(&sqrtD, 1 /* Stride */, &negB, 1 /* Stride */, &numerator2, 1 /* Stride */, vDSP_n)
        
        // /
        
        var result1 = [Float](repeating: 0, count: quadratics.count)
        vDSP_vdiv(&a2, 1 /* Stride */, &numerator1, 1 /* Stride */, &result1, 1 /* Stride */, vDSP_n)
        
        // -
        var result2 = [Float](repeating: 0, count: quadratics.count)
        vDSP_vdiv(&a2, 1 /* Stride */, &numerator2, 1 /* Stride */, &result2, 1 /* Stride */, vDSP_n)
        
        return stride(from: 0, to: quadratics.count, by: 1).map { (result1[$0], result2[$0]) }
    }
    
    /// Calculates and returns discriminants for each quadratic, where `a`, `b`, and `c` must have at least `n` elements and each index represents one quadratic.
    ///
    /// The discriminant is defined as b^2 - 4ac.
    ///
    /// This method uses CPU vector instructions to accelerate the calculations.
    ///
    /// - Parameters:
    ///   - a: The a terms.
    ///   - b: The b terms.
    ///   - c: The c terms.
    ///   - n: The number of discriminants to calculate.
    /// - Returns: An array where each element is the discriminant of the cooresponding quadratic.
    private static func discriminants(a: inout [Float], b: inout [Float], c: inout [Float], n: vDSP_Length) -> [Float] {
        // b^2 - 4ac
        
        let stdCount = Int(n)
        
        // b^2
        var b2 = [Float](repeating: 0, count: stdCount)
        vDSP_vsq(&b, 1 /* Stride */, &b2, 1 /* Stride */, n)
        
        // ac
        var ac = [Float](repeating: 0, count: stdCount)
        vDSP_vmul(&a, 1 /* Stride */, &c, 1 /* Stride */, &ac, 1 /* Stride */, n)
        
        // 4ac
        var ac4 = [Float](repeating: 0, count: stdCount)
        var constant4: Float = 4
        vDSP_vsmul(&ac, 1 /* Stride */, &constant4, &ac4, 1 /* Stride */, n)
        
        // b^2 - 4ac
        var descriminants = [Float](repeating: 0, count: stdCount)
        vDSP_vsub(&ac4, 1 /* Stride */, &b2, 1 /* Stride */, &descriminants, 1 /* Stride */, n)
        
        return descriminants
    }
    
}
