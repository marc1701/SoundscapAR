//
//  ViewControllerARDelegates.swift
//  AR2
//
//  Created by Marc Green on 06/08/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import ARKit

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
//        guard let boxNode = sceneView.scene.rootNode.childNode(withName: "BoxyMcBoxFace", recursively: false) else { return }
        guard let camera = self.sceneView.session.currentFrame?.camera else { return }
        
//        updateSourcePosition(withPositionOf: boxNode, forSource: audioPlayer)
        self.updateListenerPosition(withPositionOf: camera, inEnvironment: self.audioEnvironment)
        
        // if head tracker is not connected, use angles from device
        if !self.headTrackerIsConnected {
            self.updateListenerOrientation(withOrientationOf: camera, inEnvironment: self.audioEnvironment)
        }
        
        // light source intensity follows ambient light intensity
        guard let lightIntensityEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientIntensity,
            let lightTemperatureEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientColorTemperature
            else { print("No light level estimate available"); return }
        self.lightSource.intensity = lightIntensityEstimate
        self.lightSource.temperature = lightTemperatureEstimate
        self.lightNode.position = SCNVector3Make(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
        
        
        // will have to keep an array of these and update each in turn
        self.testBarrierNode.updateAudioProcessing(forPositionOf: camera, withHeadTrackerYaw: self.headTrackerYaw)
    }
}
