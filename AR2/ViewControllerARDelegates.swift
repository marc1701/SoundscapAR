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
        self.updateListenerPositionAndOrientation(withPositionOf: camera, inEnvironment: self.audioEnvironment)
        
        // light source intensity follows ambient light intensity
        guard let lightIntensityEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientIntensity,
            let lightTemperatureEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientColorTemperature
            else { print("No light level estimate available"); return }
        self.lightSource.intensity = lightIntensityEstimate
        self.lightSource.temperature = lightTemperatureEstimate
        self.lightNode.position = SCNVector3Make(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
        
        let isAnyObjectInView = self.virtualObjectLoader.loadedObjects.contains { object in
            return self.sceneView.isNode(object, insideFrustumOf: self.sceneView.pointOfView!)
        }
        
        DispatchQueue.main.async {
            self.virtualObjectInteraction.updateObjectToCurrentTrackingPosition()
            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
        }
        
        // GUESSING I'LL HAVE MY OWN VERSION OF THIS SOON
        // If the object selection menu is open, update availability of items
//        if objectsViewController != nil {
            let planeAnchor = self.focusSquare.currentPlaneAnchor
//            objectsViewController?.updateObjectAvailability(for: planeAnchor)
//        }
        
        // will have to keep an array of these and update each in turn
        self.testBarrierNode.updateAudioProcessing(forPositionOf: camera)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        DispatchQueue.main.async { self.ARFeedbackLabel.text = "Surface detected" }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // make sure anchor is a planeAnchor and the plane can be found in our dictionary
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        DispatchQueue.main.async { self.ARFeedbackLabel.text = "Updated a plane" }
    }
    
}
