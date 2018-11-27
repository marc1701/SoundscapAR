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
        
        guard let camera = self.sceneView.session.currentFrame?.camera else { return }
        
        self.updateListenerPositionAndOrientation(withPositionOf: camera, inEnvironment: self.audioEnvironment)
        
        // light source intensity follows ambient light intensity
        guard let lightIntensityEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientIntensity,
            let lightTemperatureEstimate = sceneView.session.currentFrame?.lightEstimate?.ambientColorTemperature
            else { print("No light level estimate available"); return }
        self.lightSource.intensity = lightIntensityEstimate
        self.lightSource.temperature = lightTemperatureEstimate
        self.lightNode.position = SCNVector3Make(camera.transform.columns.3.x, camera.transform.columns.3.y, camera.transform.columns.3.z)
        
        
        // will have to keep an array of these and update each in turn
        self.barrierNode.updateAudioProcessing(forPositionOf: camera)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // this is optional as? because otherwise the if statement won't work
        // usually would need to unwrap var coming from as?
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return } // could do non-plane things here
        
        let plane = VirtualPlane(anchor: planeAnchor)
        
        // add detected and implemented virtual plane to the dictionary
        self.planes[planeAnchor.identifier] = plane
        
        // add the VirtualPlane as a child node to the SCNNode added by ARKit with the ARAnchor
        node.addChildNode(plane)
    }
    
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        return node
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // make sure anchor is a planeAnchor and the plane can be found in our dictionary
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = self.planes[planeAnchor.identifier] else { return }
        
        plane.updateWithNewAnchor(planeAnchor)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        // make sure anchor is a planeAnchor and the plane can be found in the dictionary
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let index = planes.index(forKey: planeAnchor.identifier) else { return }
        
        self.planes.remove(at: index)
    }
}
