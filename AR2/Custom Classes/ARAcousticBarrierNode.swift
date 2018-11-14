//
//  ARAcousticBarrierNode.swift
//  AR2
//
//  Created by Marc Green on 25/09/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation

class ARAcousticBarrierNode: SCNNode {
    
    var audioHidden = false {
        willSet {
            self.isHidden = newValue
            self.lowPassFilterParameters.frequency = 20000 // effectively disable the filter
        }
    }
    
    // can we connect from outside the object directly into this filter?
    let lowPassFilter = AVAudioUnitEQ()
    var lowPassFilterParameters: AVAudioUnitEQFilterParameters!
    
    // the connection of *all* these things will have to happen outside this object, in the viewController's audioEngine
    let mixerPreFilterLeft = AVAudioMixerNode()
    let mixerPreFilterRight = AVAudioMixerNode()
    let mixerPostFilterLeft = AVAudioMixerNode()
    let mixerPostFilterRight = AVAudioMixerNode()
    
    // these should help keep things tidier externally
    var connectionPointsForDeviceInput =  [AVAudioConnectionPoint]()
    var connectionPointsForFilterOutput = [AVAudioConnectionPoint]()
    
    var audioNodesToAttach = [AVAudioNode]()
    var mixersToConnect = [AVAudioMixerNode]()
    
    // init to centre pan position
    var panValue = Float.pi / 4 {
        willSet {
            self.gains = ["L": cos(newValue), "R": sin(newValue)]
        }
    }
    
    // will need to think about what geometry to use for this barrier object (and how to allow the user to change the size)
    fileprivate let sceneWithCubeRoot = SCNScene(named: "cubeScene.scn")?.rootNode
    var redMaterials = [SCNMaterial]()
    let blackMaterial = SCNMaterial()
    
    var gains = [String: Float]() {
        willSet {
            guard let leftGain = newValue["L"],
                let rightGain = newValue["R"]
                else { print("Error setting barrier gains"); return }
            
            self.mixerPostFilterLeft.volume = leftGain
            self.mixerPostFilterRight.volume = rightGain
            
            self.mixerPreFilterLeft.volume = 1 - leftGain
            self.mixerPreFilterRight.volume = 1 - rightGain
        }
    }
    
    // distance at which cutoff will be set to 20 kHz (no effective filtering)
    var maximumAttenuationDistance: Float!
    
    // frequency in Hz at which the filter operates when the listener is as close as possible to the barrier
    var minimumCutoffFrequency: Float!
    
    init(atPosition position: SCNVector3, withMinimumCutoffFrequency minimumCutoff: Float = 20.0, maxAttenuationDistance: Float = 10.0) {
        super.init()
        
        // initialise connection points for external audio objects
        self.setupConnectionPoints()
        
        self.position = position
        
        self.lowPassFilterParameters = self.lowPassFilter.bands[0]
        self.lowPassFilterParameters.filterType = .lowPass
        self.lowPassFilterParameters.bypass = false
        
        self.mixerPreFilterLeft.pan = -1
        self.mixerPreFilterRight.pan = 1
        self.mixerPostFilterLeft.pan = -1
        self.mixerPostFilterRight.pan = 1
        
        // the frequency will be set relative to size of barrier and listener position
        // we'll need a method that takes listener position, calculates distance and changes this
        // in that method we could also do the panning
        self.lowPassFilterParameters.frequency = minimumCutoff
        
        guard let boxGeometry = self.sceneWithCubeRoot?.childNode(withName: "box", recursively: true)?.geometry
            else { print("Fell down at the first hurdle"); return }
        
        self.geometry = boxGeometry
        
        self.minimumCutoffFrequency = minimumCutoff
        self.maximumAttenuationDistance = maxAttenuationDistance
    }
    
    
    func alterFilterCutoff(givenPositionOf camera: ARCamera) {
        let cameraPosition = camera.transform.columns.3
        
        let coordinateDistances = SCNVector3Make(cameraPosition.x - self.position.x,
                                                 cameraPosition.y - self.position.y,
                                                 cameraPosition.z - self.position.z)
        
        let distance =  sqrtf(pow(coordinateDistances.x, 2)
            + pow(coordinateDistances.y, 2)
            + pow(coordinateDistances.z, 2))
        
        // can have user-settable max/min values for distance and cutoff here
        self.lowPassFilterParameters.frequency = mapValue(input: distance,
                                                          oldLow: 0, oldHigh: self.maximumAttenuationDistance,
                                                          newLow: self.minimumCutoffFrequency, newHigh: 20000)
    }
    
    
    // this is the one to use to update everything outside the class
    func updateAudioProcessing(forPositionOf camera: ARCamera) {
        
        // if the node is not hidden
        if !self.isHidden {
            self.alterFilterCutoff(givenPositionOf: camera)
        }
        
        self.panValue = self.calculatePanValue(forPositionOf: camera)
    }
    
    
    // this is linear mapping - it would probably be better to make this exponential
    func mapValue(input: Float, oldLow: Float, oldHigh: Float, newLow: Float, newHigh: Float) -> Float {
        return ((input - oldLow) / (oldHigh - oldLow))
            * (newHigh - newLow) + newLow
    }
    
    
    func calculatePanValue(forPositionOf camera: ARCamera) -> Float {
        // what will we ever use it for in adult life?
        let distanceOppositeSide = (self.position.x - camera.transform.columns.3.x)
        let distanceAdjacentSide = (self.position.z - camera.transform.columns.3.z)
        
        let cameraToSelfAngle = atan2(distanceOppositeSide, distanceAdjacentSide)
        
        // do a bunch of fudges to map the angles to a more useful range
        var relativeAngleGivenCameraRotation = cameraToSelfAngle + camera.eulerAngles.y
        if relativeAngleGivenCameraRotation < -Float.pi {
            relativeAngleGivenCameraRotation += 2*Float.pi
        }
        
        var truncatedRelativeAngle = relativeAngleGivenCameraRotation.truncatingRemainder(dividingBy: Float.pi)
        if truncatedRelativeAngle > Float.pi/2 {
            truncatedRelativeAngle = Float.pi - truncatedRelativeAngle
        } else if truncatedRelativeAngle < -Float.pi/2 {
            truncatedRelativeAngle = -Float.pi - truncatedRelativeAngle
        }
        
        // as the panner takes values in the range of 0 and pi/2, this is neat
        return (truncatedRelativeAngle + Float.pi/2)/2
    }
    
    
    //    func setGainsBasedOnPanValue(_ input: Float) {
    //        // input should be between 0 and pi/2
    //        // equal-power panning
    //        self.gains = ["L": cos(input), "R": sin(input)]
    //    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func setupConnectionPoints() {
        self.connectionPointsForDeviceInput = [AVAudioConnectionPoint(node: self.lowPassFilter, bus: 0),
                                               AVAudioConnectionPoint(node: self.mixerPreFilterLeft, bus: 0),
                                               AVAudioConnectionPoint(node: self.mixerPreFilterRight, bus: 0)]
        
        self.connectionPointsForFilterOutput = [AVAudioConnectionPoint(node: self.mixerPostFilterLeft, bus: 0),
                                                AVAudioConnectionPoint(node: self.mixerPostFilterRight, bus: 0)]
        
        self.audioNodesToAttach = [self.lowPassFilter, self.mixerPreFilterLeft, self.mixerPostFilterLeft,
                                   self.mixerPreFilterRight, self.mixerPostFilterRight]
        
        self.mixersToConnect = [self.mixerPostFilterRight, self.mixerPreFilterRight, self.mixerPostFilterLeft, self.mixerPreFilterLeft]
    }
}
