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
import QuartzCore

class ViewController: UIViewController {

    @IBOutlet var sceneView: VirtualObjectARView!
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
    
    @IBOutlet weak var ARFeedbackLabel: UILabel!
    
    @IBOutlet weak var audioSourceView: UIView!
    
    var focusSquare = FocusSquare()
    let updateQueue = DispatchQueue(label: "arqueue")
    var screenCenter: CGPoint {
        let bounds = self.sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    /// FROM APPLE DEMO
    
    /// A type which manages gesture manipulation of virtual content in the scene.
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: self.sceneView)
    
    /// Coordinates the loading and unloading of reference nodes for virtual objects.
    let virtualObjectLoader = VirtualObjectLoader()
    
    /// AVAudioSession is an object that communicates to the low-level system how audio will be used in the app
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
        self.audioSourceView.isHidden = true
        self.MLDataView.layer.cornerRadius = 8.0
        self.audioSourceView.layer.cornerRadius = 8.0
        self.MLDataButton.layer.cornerRadius = 8.0
        self.audioSourceButton.layer.cornerRadius = 8.0
        self.barrierButton.layer.cornerRadius = 8.0
        self.ARFeedbackLabel.layer.cornerRadius = 8.0
        
        /// AUDIO ///
        self.deviceInput = self.audioEngine.inputNode
        self.deviceInputFormat = self.deviceInput.inputFormat(forBus: 0)
        self.mainMixer = self.audioEngine.mainMixerNode
        
        // activate audio session (low-level)
        self.activateAudioSession()

        self.sceneRootNode = self.sceneView.scene.rootNode
        self.sceneRootNode.addChildNode(focusSquare)

        // do routing of audio nodes (like patching a mixer)
        self.audioRoutingSetup()
        
        // starts our instance of AVAudioEngine (higher-level)
        self.startAudioEngine()
        
        
        
        /// AR ///
        // add node to scene
//        let drumsNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, -0.5), withAudioFile: "drums.m4a")
        let drumsNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, -0.5), withAudioFile: "drums.m4a", geometryName: "car", geometryScaling: SCNVector3(0.05, 0.05, 0.05))
        self.binauralNodes.append(drumsNode)

//        let synthNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, 0.5), withAudioFile: "synth.m4a")
        let synthNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, 0.5), withAudioFile: "synth.m4a", geometryName: "bird", geometryScaling: SCNVector3(0.2, 0.2, 0.2))
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
        configuration.planeDetection = .horizontal
        
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
        print("tappy tappy!")
        let tapLocation = sender.location(in: self.sceneView)
        let hitTestResults = self.sceneView.hitTest(tapLocation)
//
        guard let node = hitTestResults.first?.node as? ARBinauralAudioNode
            else { print("wtf"); return }
        node.audioToggle()
        print("hmm")
        
//
//        if let node = hitTestResults.first?.node as? ARBinauralAudioNode {
//            node.audioToggle()
//        } else if let node = hitTestResults.first?.node as? ARAcousticBarrierNode {
//            node.audioHidden = !node.audioHidden
//            // of course now there's no way of bringing it back!
//        }
    }
    
    
    @IBAction func showHideMLDataView(_ sender: UIButton) {
        if self.MLDataView.isHidden {
            self.MLDataView.isHidden = false
            self.audioSourceView.isHidden = true
        } else {
            self.MLDataView.isHidden = true
        }
    }
    
    @IBAction func barrierButtonPressed(_ sender: UIButton) {
        // there'll probably only ever be the one node in the present app config
        self.testBarrierNode.audioHidden = !self.testBarrierNode.audioHidden
    }
    
    
    @IBAction func audioButtonPressed(_ sender: UIButton) {
        if self.audioSourceView.isHidden {
            self.audioSourceView.isHidden = false
            self.MLDataView.isHidden = true
        } else {
            self.audioSourceView.isHidden = true
        }
        // toggle play/stop here?
        // open up an overlay view with some object options?
    }
    
    
    func updateFocusSquare(isObjectVisible: Bool) {
        if isObjectVisible {
            self.focusSquare.hide()
        } else {
            self.focusSquare.unhide()
            DispatchQueue.main.async { self.ARFeedbackLabel.text = "Try moving left and right" }
        }
        
        // Perform hit testing only when ARKit tracking is in a good state.
        if let camera = self.sceneView.session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.sceneView.smartHitTest(self.screenCenter) {
            self.updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
//            addObjectButton.isHidden = false
            DispatchQueue.main.async { self.ARFeedbackLabel.text = "Surface detected nicely" }
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
//            addObjectButton.isHidden = true
        }
        
        
    }
    
}
