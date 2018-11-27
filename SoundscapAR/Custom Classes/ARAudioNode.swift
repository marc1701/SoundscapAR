//
//  File.swift
//  AR2
//
//  Created by Marc Green on 19/11/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation

class ARAudioNode: SCNNode {
    var audioIsPlaying = false
    
    override init() {
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
