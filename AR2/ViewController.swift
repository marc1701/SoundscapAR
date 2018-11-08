//
//  ViewController.swift
//  AR2
//
//  Created by Marc Green on 22/06/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import UIKit
import ARKit
import CoreML
import aubio

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var MLDataView: UIView!
    
    @IBOutlet weak var humanRatingBar: UIProgressView!
    @IBOutlet weak var naturalRatingBar: UIProgressView!
    @IBOutlet weak var mechanicalRatingBar: UIProgressView!
    
    @IBOutlet weak var humanRatingText: UITextField!
    @IBOutlet weak var naturalRatingText: UITextField!
    @IBOutlet weak var mechanicalRatingText: UITextField!
    
    @IBOutlet weak var MLDataButton: UIButton!
    @IBOutlet weak var barrierButton: UIButton!
    @IBOutlet weak var audioSourceButton: UIButton!
    
    
    // AVAudioSession is an object that communicates to the low-level system how audio will be used in the app
    let audioSession = AVAudioSession()
    let sampleFreq = 44100.0
    let bufferSize = 64
    
    let audioEngine = AVAudioEngine()
    var deviceInput: AVAudioInputNode!
    var deviceInputFormat: AVAudioFormat!
    
    let audioEnvironment = AVAudioEnvironmentNode()
    var mainMixer: AVAudioMixerNode!
    
    let mono = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    let stereo = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    
    // this is updated frame-by-frame
//    var listenerPosition = AVAudio3DPoint()
    
    let lightSource = SCNLight()
    let lightNode = SCNNode()
    
    var sceneRootNode: SCNNode!
    
    // could probably use a system similar to this in order to make sure all the filter objects are connected up in the correct way. I guess we could probably check for prior connections, disconnect and reconnect
    var binauralNodes = [ARBinauralAudioNode]() {
        willSet {
            guard let newNode = newValue.last else { return }
            self.sceneRootNode.addChildNode(newNode)
            self.audioEngine.attach(newNode.audioPlayer)
            self.audioEngine.connect(newNode.audioPlayer, to: self.audioEnvironment, format: mono)
        }
    }
    
    let deviceInputDummy = AVAudioMixerNode()
    ///////////////////////////////////
    // TEMP TEST STUFF FOR BARRIER NODE
    let testBarrierNode = ARAcousticBarrierNode(atPosition: SCNVector3(-0.5, 0, 0))
    //        self.barrierNodes.append(testBarrierNode)
    ///////////////////////////////////
    
    /// ML Object ///
    let SVCClassifier = EnvironmenatalAudioAnalyser()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.MLDataView.isHidden = true
        self.MLDataView.layer.cornerRadius = 8.0
        self.MLDataButton.layer.cornerRadius = 8.0
        self.audioSourceButton.layer.cornerRadius = 8.0
        self.barrierButton.layer.cornerRadius = 8.0
        
        /// AUDIO ///
        self.deviceInput = self.audioEngine.inputNode
        self.deviceInputFormat = self.deviceInput.inputFormat(forBus: 0)
        self.mainMixer = self.audioEngine.mainMixerNode
        
        // activate audio session (low-level)
        self.activateAudioSession()

        self.sceneRootNode = sceneView.scene.rootNode
        

        // do routing of audio nodes (like patching a mixer)
        self.audioRoutingSetup()
        
        // starts our instance of AVAudioEngine (higher-level)
        self.startAudioEngine()
        
        
        
        /// AR ///
        // add node to scene
        let drumsNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, -0.5), withAudioFile: "drums.m4a")
        self.binauralNodes.append(drumsNode)

        let synthNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, 0.5), withAudioFile: "synth.m4a")
        self.binauralNodes.append(synthNode)
        
        // test barrier node
        self.sceneRootNode.addChildNode(self.testBarrierNode)
        ///////
        
        
        // add lighting source at initial camera position (this will follow the camera)
        self.lightSource.type = .omni
        self.lightNode.light = lightSource
        self.lightNode.position = SCNVector3(0, 0, 0)
        self.sceneView.scene.rootNode.addChildNode(lightNode)
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // use world tracking configuration (6DOF)
        let configuration = ARWorldTrackingConfiguration()
        
        self.sceneView.delegate = self
        // start AR processing session
        self.sceneView.session.run(configuration)
        
        self.sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // pause session if view is going to go
        self.sceneView.session.pause()
    }
    
    
    @IBAction func viewTappedOnce(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: self.sceneView)
        let hitTestResults = self.sceneView.hitTest(tapLocation)
//
        guard let node = hitTestResults.first?.node as? ARBinauralAudioNode
            else { return }
        node.audioToggle()
        
//
//        if let node = hitTestResults.first?.node as? ARBinauralAudioNode {
//            node.audioToggle()
//        } else if let node = hitTestResults.first?.node as? ARAcousticBarrierNode {
//            node.audioHidden = !node.audioHidden
//            // of course now there's no way of bringing it back!
//        }
    }
    
    
    @IBAction func showHideMLDataView(_ sender: UIButton) {
        if self.MLDataView.isHidden == true {
            self.MLDataView.isHidden = false
        } else {
            self.MLDataView.isHidden = true
        }
    }
    
    @IBAction func barrierButtonPressed(_ sender: UIButton) {
        // there'll probably only ever be the one node in the present app config
        self.testBarrierNode.audioHidden = !self.testBarrierNode.audioHidden
    }
    
    
    @IBAction func audioButtonPressed(_ sender: UIButton) {
        // toggle play/stop here?
        // open up an overlay view with some object options?
    }
    
    
}
