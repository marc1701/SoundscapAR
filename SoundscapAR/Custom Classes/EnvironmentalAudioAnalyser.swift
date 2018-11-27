//
//  EnvironmentalAudioAnalyser.swift
//  AR2
//
//  Created by Marc Green on 08/11/2018.
//  Copyright © 2018 Marc Green. All rights reserved.
//

import Foundation
import aubio
import CoreML

class EnvironmenatalAudioAnalyser {
    
    //// AUBIO ////
    var averagePeriod = 21 // ~1s of audio (44100 / 2048 samples) -- make user-editable?
    var naturalValueMovingAverage: MovingAverage!
    var mechanicalValueMovingAverage: MovingAverage!
    var humanValueMovingAverage: MovingAverage!
    
    let win_size : uint_t = 2048
    let hop_size : uint_t!
    let n_filters : uint_t = 40
    let n_coefs : uint_t = 20
    let fs : uint_t = 44100
    
    // output vector (for mfccs)
    let out_vec : UnsafeMutablePointer<fvec_t>!
    
    // used for intermediate raw fft data (includes phase)
    let fftgrain : UnsafeMutablePointer<cvec_t>!
    
    var mfccDataDouble = [Double]()
    
    let phase_voc : OpaquePointer!
    let mfcc_calculator : OpaquePointer!
    
    let device_in_vec : UnsafeMutablePointer<fvec_t>!
    
    
    //// ML ////
    let scaler = MFCC_Scaler()
    let classifier = MFCC_SVC()
    
    init(framesForAveraging: Int = 21) {
        // setup properties
        self.averagePeriod = framesForAveraging
        
        self.hop_size = self.win_size/2
        self.out_vec = new_fvec(n_coefs)
        self.fftgrain = new_cvec(win_size)
        self.phase_voc = new_aubio_pvoc(win_size, hop_size)
        self.mfcc_calculator = new_aubio_mfcc(win_size, n_filters, n_coefs, fs)
        self.device_in_vec = new_fvec(hop_size)
        
        self.naturalValueMovingAverage = MovingAverage(period: self.averagePeriod)
        self.mechanicalValueMovingAverage = MovingAverage(period: self.averagePeriod)
        self.humanValueMovingAverage = MovingAverage(period: self.averagePeriod)
    }
    
    func analyseAudioFrame(_ data: UnsafePointer<UnsafeMutablePointer<Float>>) -> (natural: Double, mechanical: Double, human: Double)? {
        
        // copy audio buffer into aubio fvec
        for i in 0..<Int(hop_size) { fvec_set_sample(device_in_vec, data.pointee[i], uint_t(i)) }
        
        // execute phase vocoder - fft "is computed and returned in fftgrain as two vetors, magnitude and phase"
        aubio_pvoc_do(phase_voc, device_in_vec, fftgrain)
        
        // calc mfccs based on fftgrain, write to out_vec
        aubio_mfcc_do(mfcc_calculator, fftgrain, out_vec)
        
        // wrangling to get the mfccs
        guard let mfccDataFvec = out_vec?.pointee.data else { print("No MFCC data available"); return nil }
        
        // clear data from last frame
        mfccDataDouble.removeAll()
        for i in 0..<Int(n_coefs) { mfccDataDouble.append(Double(mfccDataFvec[i])) }
        
        // more stupid wrangling to get the data into the right format
        guard let mfccDataMLArray = try? MLMultiArray(shape:[20], dataType:MLMultiArrayDataType.double)
            else { fatalError("Unexpected runtime error. MLMultiArray") }
        for (i, value) in mfccDataDouble.enumerated() { mfccDataMLArray[i] = NSNumber(floatLiteral: value) }
        
        // scale data
        guard let scalerOutput = try? scaler.prediction(input: mfccDataMLArray)
            else { fatalError("Couldn't scale data") }
        let scaledData = scalerOutput.transformed_features
        
        // get classifier output probabilities
        guard let classifierOutput = try? classifier.prediction(MFCCs: scaledData)
            else { fatalError("Classifier error") }
        
        guard let humanRating = classifierOutput.classProbability[5],
            let naturalRating = classifierOutput.classProbability[7],
            let mechanicalRating = classifierOutput.classProbability[1]
            else { print("Unable to get predictions from CoreML model."); return nil }
        
        let naturalAverage = self.naturalValueMovingAverage.addSample(value: naturalRating)
        let mechanicalAverage = self.mechanicalValueMovingAverage.addSample(value: mechanicalRating)
        let humanAverage = self.humanValueMovingAverage.addSample(value: humanRating)
        
        return (naturalAverage, mechanicalAverage, humanAverage)
    }
}
