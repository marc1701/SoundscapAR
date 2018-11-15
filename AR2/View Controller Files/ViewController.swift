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
    @IBOutlet weak var ARInfoView: UIView!
    @IBOutlet weak var objectSelectionView: UIView!
    
    @IBOutlet weak var humanRatingBar: UIProgressView!
    @IBOutlet weak var naturalRatingBar: UIProgressView!
    @IBOutlet weak var mechanicalRatingBar: UIProgressView!
    
    @IBOutlet weak var humanRatingText: UITextField!
    @IBOutlet weak var naturalRatingText: UITextField!
    @IBOutlet weak var mechanicalRatingText: UITextField!
    
    @IBOutlet weak var MLDataButton: UIButton!
    @IBOutlet weak var objectSelectionButton: UIButton!
    @IBOutlet weak var ARButton: UIButton!
    
    @IBOutlet weak var userInstructionLabel: UILabel!
    @IBOutlet weak var ARBigLabel: UILabel!
    
    @IBOutlet weak var carImage: UIImageView!
    @IBOutlet weak var birdImage: UIImageView!
    @IBOutlet weak var fountainImage: UIImageView!
    @IBOutlet weak var barrierImage: UIImageView!
    
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
    let barrierNode = ARAcousticBarrierNode(atPosition: SCNVector3(-0.5, 0, 0))
    //        self.barrierNodes.append(barrierNode)
    ///////////////////////////////////
    
    /// ML Object ///
    let SVCClassifier = EnvironmenatalAudioAnalyser()
    
    
    /// ARKIT Stuff from Tutorial ///
    var planes = [UUID: VirtualPlane]() {
        didSet {
            if planes.count > 0 {
                self.sessionStatus = .ready
            } else {
                if self.sessionStatus == .ready { self.sessionStatus = .initialised }
            }
        }
    }
    
    var sessionStatus = ARSessionState.initialised {
        didSet {
            DispatchQueue.main.async { self.userInstructionLabel.text = self.sessionStatus.description }
            if sessionStatus == .failed { cleanupARSession() }
            if sessionStatus == .temporarilyUnavailable {
                DispatchQueue.main.async { self.ARBigLabel.textColor = #colorLiteral(red: 0.9529411793, green: 0.6862745285, blue: 0.1333333403, alpha: 1) } }
            if sessionStatus == .ready {
                DispatchQueue.main.async { self.ARBigLabel.textColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1) } }
        }
    }
    
    var objectsActive = [false, false, false, false]
    var objectImageViews = [UIImageView]()
    let redObjectImages = [UIImage(named: "car_red.png"),
                           UIImage(named: "bird_red.png"),
                           UIImage(named: "fountain_red.png"),
                           UIImage(named: "barrier_red.png")]
    let greenObjectImages = [UIImage(named: "car_green.png"),
                             UIImage(named: "bird_green.png"),
                             UIImage(named: "fountain_green.png"),
                             UIImage(named: "barrier_green.png")]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.objectImageViews = [self.carImage, self.birdImage, self.fountainImage, self.barrierImage]
        
        self.MLDataView.isHidden = true
        self.ARButton.backgroundColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        self.MLDataView.backgroundColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        
        /// AUDIO ///
        self.deviceInput = self.audioEngine.inputNode
        self.deviceInputFormat = self.deviceInput.inputFormat(forBus: 0)
        self.mainMixer = self.audioEngine.mainMixerNode
        self.objectSelectionView.isHidden = true
        
        // activate audio session (low-level)
        self.activateAudioSession()

        self.sceneRootNode = sceneView.scene.rootNode
        

        // do routing of audio nodes (like patching a mixer)
        self.audioRoutingSetup()
        
        // starts our instance of AVAudioEngine (higher-level)
        self.startAudioEngine()
        
        /// AR ///
        // add node to scene
//        let drumsNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, -0.5), withAudioFile: "road_mono.m4a", geometryName: "car", geometryScaling: SCNVector3(0.1, 0.1, 0.1))
//        self.binauralNodes.append(drumsNode)
//
//        let synthNode = ARBinauralAudioNode(atPosition: SCNVector3(0, 0, 0.5), withAudioFile: "birdsong_mono.m4a", geometryName: "bird", geometryScaling: SCNVector3(0.1, 0.1, 0.1))
//        self.binauralNodes.append(synthNode)
        
        // test barrier node
        self.sceneRootNode.addChildNode(self.barrierNode)
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
        configuration.planeDetection = .horizontal // I always forget this!
        
        self.sceneView.delegate = self
        // start AR processing session
        self.sceneView.session.run(configuration)
        
//        self.sceneView.debugOptions = ARSCNDebugOptions.showWorldOrigin
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        // resume sessionStatus
        if self.planes.count > 0 { self.sessionStatus = .ready }
    }

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // pause session if view is going to go
        self.sceneView.session.pause()
        
        self.sessionStatus = .temporarilyUnavailable
    }
    
    
    
    @IBAction func viewTappedOnce(_ sender: UITapGestureRecognizer) {
        let tapLocation = sender.location(in: self.sceneView)
        let hitTestResults = self.sceneView.hitTest(tapLocation)
        
        guard let node = hitTestResults.first?.node as? ARBinauralAudioNode
            else { return }
        
        node.audioToggle()
    }
    
    
    @IBAction func showHideMLDataView(_ sender: UIButton) {
        self.MLDataView.isHidden = !self.MLDataView.isHidden
        
        if self.MLDataView.isHidden {
            self.MLDataButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        } else {
            self.MLDataButton.backgroundColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        }
        
        if !self.ARInfoView.isHidden {
            self.ARInfoView.isHidden = true
            self.ARButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
        
        if !self.objectSelectionView.isHidden {
            self.objectSelectionView.isHidden = true
            self.objectSelectionButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
    }
    
    
    @IBAction func objectSelectionButtonPressed(_ sender: UIButton) {
        self.objectSelectionView.isHidden = !self.objectSelectionView.isHidden
        
        if self.objectSelectionView.isHidden {
            self.objectSelectionButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        } else {
            self.objectSelectionButton.backgroundColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        }
        
        if !self.ARInfoView.isHidden {
            self.ARInfoView.isHidden = true
            self.ARButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
        
        if !self.MLDataView.isHidden {
            self.MLDataView.isHidden = true
            self.MLDataButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
    }
    
    
    @IBAction func ARButtonPressed(_ sender: UIButton) {
        self.ARInfoView.isHidden = !self.ARInfoView.isHidden
        
        if self.ARInfoView.isHidden {
            self.ARButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        } else {
            self.ARButton.backgroundColor = #colorLiteral(red: 0.4745098054, green: 0.8392156959, blue: 0.9764705896, alpha: 1)
        }
        
        if !self.MLDataView.isHidden {
            self.MLDataView.isHidden = true
            self.MLDataButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
        
        if !self.objectSelectionView.isHidden {
            self.objectSelectionView.isHidden = true
            self.objectSelectionButton.backgroundColor = #colorLiteral(red: 0, green: 0.5898008943, blue: 1, alpha: 1)
        }
    }
 
    
    func cleanupARSession() {
        // enumerateChildNodes iterates through all the present child nodes and executes the code in the closure
        self.sceneView.scene.rootNode.enumerateChildNodes{ (node, stop) -> Void in
            node.removeFromParentNode()
        }
    }
    
    @IBAction func imageButtonPressed(_ sender: UIButton) {
        if self.objectsActive[sender.tag] {
            self.objectImageViews[sender.tag].image = self.redObjectImages[sender.tag]
        } else {
            self.objectImageViews[sender.tag].image = self.greenObjectImages[sender.tag]
        }
        
        self.objectsActive[sender.tag] = !self.objectsActive[sender.tag]
    }
}
