//
//  ViewControllerAudioFuncs.swift
//  AR2
//
//  Created by Marc Green on 21/08/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import UIKit
import ARKit
import AVFoundation

extension ViewController {
    
//    func loadAudioFile(trackURL: URL) {
//        guard let audioPlayerFile = try? AVAudioFile(forReading: trackURL)
//            else { print("Error opening audio file"); return }
//
//        // set up audio buffer for loop playback
//        guard let buffer = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: UInt32(audioPlayerFile.length)) else { print("PCM buffer set-up error"); return }
//        buffer.frameLength = UInt32(audioPlayerFile.length)
//
//        do {
//            try audioPlayerFile.read(into: buffer)
//        } catch  {
//            print("Buffer read failed.")
//        }
//
//        audioBuffer = buffer
//
//    }
    
    
    func activateAudioSession() {
        // set up audio session
        do {
            try self.audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try self.audioSession.setPreferredSampleRate(sampleFreq)
            try self.audioSession.setPreferredIOBufferDuration(Double(bufferSize) / sampleFreq)
            try self.audioSession.setActive(true)
        }
        catch {
            print("Activation of AVAudioSession failed.")
        }
    }
    
    
    func audioRoutingSetup() {
        
        // attach audioPlayer to the engine
//        audioEngine.attach(audioPlayer)
        self.audioEngine.attach(self.audioEnvironment)
        self.audioEngine.attach(self.deviceInputDummy)
        
        // set attenuation to begin (almost) immediately
        self.audioEnvironment.distanceAttenuationParameters.referenceDistance = 0.1
        
        // make connections (like patching mixer)
        self.audioEngine.connect(self.audioEnvironment, to: self.mainMixer, format: self.stereo)
        self.audioEngine.connect(self.deviceInput, to: self.deviceInputDummy, format: self.deviceInputFormat)
        
        // connect nodes from barrierNode (too see if I can even get this to work on input)
        for audioNode in self.barrierNode.audioNodesToAttach { self.audioEngine.attach(audioNode) }
        for audioMixer in self.barrierNode.mixersToConnect { self.audioEngine.connect(audioMixer, to: self.mainMixer, format: self.deviceInputFormat)}
        
        self.audioEngine.connect(self.deviceInputDummy, to: self.barrierNode.connectionPointsForDeviceInput, fromBus: 0, format: self.deviceInputFormat)
        self.audioEngine.connect(self.barrierNode.lowPassFilter, to: self.barrierNode.connectionPointsForFilterOutput, fromBus: 0, format: self.deviceInputFormat)
        
        self.mainMixer.installTap(onBus: 0, bufferSize: 2048, format: nil) {
            buffer, when in
            guard let data = buffer.floatChannelData else { print("Error with tap"); return }
            
            guard let environmentalRatings = self.SVCClassifier.analyseAudioFrame(data)
                else { print("Classifier ratings not returned."); return }
            
            
            var naturalAverageToDisplay = 0.0
            var mechanicalAverageToDisplay = 0.0
            var humanAverageToDisplay = 0.0
            
            DispatchQueue.main.async {
            
            if self.audioAnalysisModeControl.selectedSegmentIndex == 1 &&
                self.timerIsRunning == true { // timer has been selected and has not yet run out
                
                naturalAverageToDisplay = self.naturalOneMinuteAverage.addSample(value: environmentalRatings.natural)
                mechanicalAverageToDisplay = self.mechanicalOneMinuteAverage.addSample(value: environmentalRatings.mechanical)
                humanAverageToDisplay = self.humanOneMinuteAverage.addSample(value: environmentalRatings.human)
            }
            else if self.audioAnalysisModeControl.selectedSegmentIndex == 1 &&
                self.timerIsRunning == false { // timer has been selected and run out
                
                naturalAverageToDisplay = self.naturalOneMinuteAverage.average
                mechanicalAverageToDisplay = self.mechanicalOneMinuteAverage.average
                humanAverageToDisplay = self.humanOneMinuteAverage.average
            }
            else if self.audioAnalysisModeControl.selectedSegmentIndex == 0 { // rolling average (default) selected
                naturalAverageToDisplay = environmentalRatings.natural
                mechanicalAverageToDisplay = environmentalRatings.mechanical
                humanAverageToDisplay = environmentalRatings.human
            }
            
            
            
                // set displayed values
                self.naturalRatingText.text = String(format: "%.2f", naturalAverageToDisplay * 100)
                self.mechanicalRatingText.text = String(format: "%.2f", mechanicalAverageToDisplay * 100)
                self.humanRatingText.text = String(format: "%.2f", humanAverageToDisplay * 100)
                
                self.naturalRatingBar.progress = Float(naturalAverageToDisplay * 3)
                self.mechanicalRatingBar.progress = Float(mechanicalAverageToDisplay * 3)
                self.humanRatingBar.progress = Float(humanAverageToDisplay * 3)
            }
        }
        
        
//        self.audioEngine.connect(self.deviceInputDummy, to: self.mainMixer, format: self.deviceInputFormat)
        print("Initial audio patching successful.")
        
    }
    
    
    func startAudioEngine() {
        // prepare audio engine (allocates system resources)
        self.audioEngine.prepare()
        
        // start engine with provision for error message
        do {
            try self.audioEngine.start() }
        catch {
            print("Error starting audio engine.")
        }
    }
    
    
    func updateSourcePosition(withPositionOf object: SCNNode, forSource audioSource: AVAudioPlayerNode)  {
        audioSource.position.x = object.worldPosition.x
        audioSource.position.y = object.worldPosition.y
        audioSource.position.z = object.worldPosition.z
    }
    
    
    func updateListenerPositionAndOrientation(withPositionOf camera: ARCamera, inEnvironment audioEnvironment: AVAudioEnvironmentNode) {
        audioEnvironment.listenerPosition.x = camera.transform.columns.3.x
        audioEnvironment.listenerPosition.y = camera.transform.columns.3.y
        audioEnvironment.listenerPosition.z = camera.transform.columns.3.z
        
        // yaw and roll are reversed in AVAudioEnvironment
        audioEnvironment.listenerAngularOrientation.roll = self.radiansToDegrees(radianValue: -camera.eulerAngles.z)
        audioEnvironment.listenerAngularOrientation.pitch = self.radiansToDegrees(radianValue: camera.eulerAngles.x)
        audioEnvironment.listenerAngularOrientation.yaw = self.radiansToDegrees(radianValue: -camera.eulerAngles.y)
    }
    
    
    func radiansToDegrees(radianValue: Float) -> Float {
        return Float(radianValue * 180.0 / Float.pi)
    }
    
}
