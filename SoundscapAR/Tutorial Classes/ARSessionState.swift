//
//  ARSessionState.swift
//  ARTutorialApp
//
//  Created by Marc Green on 24/08/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import Foundation

enum ARSessionState: String, CustomStringConvertible {
    case initialised, ready, temporarilyUnavailable, failed
    
    var description: String {
        switch self {
        case .initialised:
            return "Move iPhone around so the camera can detect the ground"
        case .ready:
            return "Flat plane detected. You can now select and place objects."
        case .temporarilyUnavailable:
            return "Temporaily Unavailable"
        case .failed:
            return "Failed"
        }
    }
}
