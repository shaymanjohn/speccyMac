//
//  AudioStreamer.swift
//  speccyMac
//
//  Created by Jose Luis Fernandez-Mayoralas on 11/7/16.
//  Copyright © 2016 Jose Luis Fernandez-Mayoralas. All rights reserved.
//
//  (Minor tweaks to work with speccyMac codebase)

import Foundation
import AudioToolbox

private let kSampleRate = 48000.0
private let kSamplesPerFrame = Int(kSampleRate) / 50
private let kNumberBuffers = 2

typealias AudioDataElement = Float
typealias AudioData = [AudioDataElement]

class AudioStreamer {
    private var outputQueue: AudioQueueRef?
    private var queueStarted: Bool = false
    
    private var buffers = [AudioQueueBufferRef?](repeatElement(nil, count: kNumberBuffers))
    private let bufferByteSize = UInt32(kSamplesPerFrame * MemoryLayout<AudioDataElement>.size) // 20 mili sec of audio
    
    private var audioData: AudioData!
    private var sample: AudioDataElement = 0
    
    var machine: Machine!
    
//    private let semaphore = DispatchSemaphore(value: 0)
    
    init() {
        self.audioData = AudioData(repeating: 0.0, count: kSamplesPerFrame)
        var streamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: kSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
            mBytesPerPacket: UInt32(MemoryLayout<AudioDataElement>.size),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<AudioDataElement>.size),
            mChannelsPerFrame: 1,
            mBitsPerChannel: UInt32(8 * MemoryLayout<AudioDataElement>.size),
            mReserved: 0
        )
        
        // create new output audio queue
        AudioQueueNewOutput(
            &streamBasicDescription,
            audioStreamerOuputCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            nil,
            nil,
            0,
            &self.outputQueue
        )
        
        // allocate audio buffers
        for i in 0 ..< kNumberBuffers {
            AudioQueueAllocateBuffer(
                self.outputQueue!,
                self.bufferByteSize,
                &self.buffers[i]
            )
            
            if let bufferRef = self.buffers[i] {
                // configure audio buffer
                let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
    
                bufferRef.pointee.mUserData = selfPointer
                bufferRef.pointee.mAudioDataByteSize = self.bufferByteSize
                
                audioStreamerOuputCallback(userData: selfPointer, queueRef: self.outputQueue!, buffer: bufferRef)
            }
        }
    }
    
    func start() {
        AudioQueueStart(self.outputQueue!, nil)
        self.queueStarted = true
    }
    
    func stop() {
        AudioQueueStop(self.outputQueue!, false)
        self.queueStarted = false
//        self.semaphore.signal()
    }

    func updateSample(_ counter: UInt32, beep: UInt8) {
        // sample EAR signal or Tape signal
        var amplitude: AudioDataElement = (beep & 0b00010000) > 0 || (beep & 0b01000000) > 0 ? 0.15 : -0.15
        
        amplitude += (beep & 0b00001000) > 0 ? 0.025 : -0.025
        
        sample -= sample / 8
        sample += amplitude / 8
        
        let offset: Int = (Int(counter) * kSamplesPerFrame) / machine.ticksPerFrame;
        if offset < kSamplesPerFrame {
            audioData[offset] = sample
        }
    }
    
    func audioDataProcessed() {
//        self.semaphore.signal()
    }
    
    func getAudioData() -> AudioData {
        return self.audioData
    }
    
    func endFrame() {
        if !self.queueStarted {
            self.start()
        }
        
//        self.semaphore.wait()
    }
}

private func audioStreamerOuputCallback(userData: Optional<UnsafeMutableRawPointer>, queueRef: AudioQueueRef, buffer: AudioQueueBufferRef) {
    // recover AudioStreamer instance from void * userData
    let this = Unmanaged<AudioStreamer>.fromOpaque(userData!).takeUnretainedValue()
    var ptr = buffer.pointee.mAudioData.assumingMemoryBound(to: AudioDataElement.self)
    
    let audioData = this.getAudioData()
    for sample in audioData {
        ptr.pointee = sample
        ptr = ptr.successor()
    }
    
    AudioQueueEnqueueBuffer(queueRef, buffer, 0, nil)
//    this.audioDataProcessed()
}

