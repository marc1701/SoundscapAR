//
//  ARBinauralAudioNode.swift
//  AR2
//
//  Created by Marc Green on 05/09/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import Foundation
import ARKit
import AVFoundation

class ARBinauralAudioNode: SCNNode {
    
    // is there a way of having this set up in another object (??ARAudioEngine??) and access it from here?
    fileprivate let mono = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    
    // audio stuff
    let audioPlayer = AVAudioPlayerNode()
    fileprivate var audioBuffer: AVAudioPCMBuffer!
    var audioIsPlaying = false
    var loop = true
    
    override var position: SCNVector3 {
        willSet {
            self.audioPlayer.position = AVAudio3DPoint(x: newValue.x, y: newValue.y, z: newValue.z)
            super.position = newValue // possibly not needed
        }
    }
    
    fileprivate let sceneWithCubeRoot = SCNScene(named: "cubeScene.scn")?.rootNode
    var redMaterials = [SCNMaterial]()
    let greenMaterial = SCNMaterial()
    
    init(atPosition position: SCNVector3, withAudioFile audioFilename: String) {
        
        super.init()
        
        // sceneKit bits
        guard let boxGeometry = self.sceneWithCubeRoot?.childNode(withName: "box", recursively: true)?.geometry
            else { print("Fell down at the first hurdle"); return }
        self.redMaterials = boxGeometry.materials
        self.greenMaterial.diffuse.contents = #colorLiteral(red: 0.4500938654, green: 0.9813225865, blue: 0.4743030667, alpha: 1)
        self.greenMaterial.selfIllumination.contents = #colorLiteral(red: 0, green: 0.5603182912, blue: 0, alpha: 1)
        self.greenMaterial.specular.contents = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        
        self.geometry = boxGeometry
        self.position = position
        
        // audio bits
        self.audioPlayer.renderingAlgorithm = .HRTFHQ
        self.audioPlayer.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
        
        loadAudioFile(fromFile: audioFilename)
        
    }
    
    
    func loadAudioFile(fromFile filename: String) {
        
        // parsing of string
        guard let dotIndex = filename.index(of: ".")
            else { print("Error: Audio file not found"); return }
        let name = String(filename[...filename.index(before: dotIndex)])
        let type = String(filename[filename.index(after: dotIndex)...])
        
        // retrieval of full audio URL (filepath to main bundle)
        guard let fullFilePath = Bundle.main.path(forResource: name, ofType: type)
            else { print("Error: Audio file not found"); return }
        
        let audioURL = URL(fileURLWithPath: fullFilePath)
        
        // loading audio file
        guard let audioPlayerFile = try? AVAudioFile(forReading: audioURL)
            else { print("Error opening audio file"); return }
        
        // set up audio buffer (for loop playback capability)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: UInt32(audioPlayerFile.length)) else { print("PCM buffer set-up error"); return }
        buffer.frameLength = UInt32(audioPlayerFile.length)
        
        do {
            try audioPlayerFile.read(into: buffer)
        } catch {
            print("Buffer read failed")
        }
        
        self.audioBuffer = buffer
        print("Audio loaded successfully")
    }
    
    
//    func updatePosition(to position: SCNVector3) {
//        self.position = position
//        self.audioPlayer.position = AVAudio3DPoint(x: position.x, y: position.y, z: position.z)
//    }
    
    func audioToggle() {
        if audioIsPlaying {
            self.geometry?.materials = self.redMaterials
            self.audioPlayer.stop()
        } else {
            self.geometry?.materials = [self.greenMaterial]
            self.audioPlayer.scheduleBuffer(self.audioBuffer, at: nil, options: .loops, completionHandler: nil)
            self.audioPlayer.play()
        }
        self.audioIsPlaying = !self.audioIsPlaying
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

