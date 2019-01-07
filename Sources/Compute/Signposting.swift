//
//  Signposting.swift
//  Compute
//
//  Created by Matthew Seaman on 1/4/19.
//

import os

/// `OSLog` objects to pass to `os_signpost` calls when profiling.
public struct SignpostLog {
    
    /// A log for signposts in the Navigation system.
    public static let navigationLog = OSLog(subsystem: "com.matthewseaman.pyTanks.SwiftBrain", category: "Navigation")
    
}
