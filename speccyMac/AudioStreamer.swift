//
//  AudioStreamer.swift
//  speccyMac
//
//  Originally by Jose Luis Fernandez-Mayoralas on 11/7/16.
//  Rewritten to use a lock-free ring buffer for glitch-free audio.
//

import Foundation
import AudioToolbox

private let kSampleRate = 48000.0
private let kSamplesPerFrame = Int(kSampleRate) / 50  // 960 samples per 20ms frame
private let kNumberBuffers = 3
private let kRingBufferSize = kSamplesPerFrame * 4     // 4 frames of headroom

typealias AudioDataElement = Float

class AudioStreamer {
    private var outputQueue: AudioQueueRef?
    private var queueStarted: Bool = false

    private var buffers = [AudioQueueBufferRef?](repeatElement(nil, count: kNumberBuffers))
    private let bufferByteSize = UInt32(kSamplesPerFrame * MemoryLayout<AudioDataElement>.size)

    // Lock-free ring buffer
    private let ringBuffer = UnsafeMutablePointer<AudioDataElement>.allocate(capacity: kRingBufferSize)
    private var writePos: Int = 0
    private var readPos: Int = 0

    private var sample: AudioDataElement = 0
    private var lastWrittenOffset: Int = -1

    // Frame buffer for building the current frame's samples before pushing to ring
    private let frameBuffer = UnsafeMutablePointer<AudioDataElement>.allocate(capacity: kSamplesPerFrame)

    var machine: Machine!

    init() {
        for i in 0..<kRingBufferSize {
            ringBuffer[i] = 0.0
        }
        for i in 0..<kSamplesPerFrame {
            frameBuffer[i] = 0.0
        }

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

        AudioQueueNewOutput(
            &streamBasicDescription,
            AudioStreamerOuputCallback,
            unsafeBitCast(self, to: UnsafeMutableRawPointer.self),
            nil,
            nil,
            0,
            &self.outputQueue
        )

        for i in 0 ..< kNumberBuffers {
            AudioQueueAllocateBuffer(
                self.outputQueue!,
                self.bufferByteSize,
                &self.buffers[i]
            )

            if let bufferRef = self.buffers[i] {
                let selfPointer = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
                bufferRef.pointee.mUserData = selfPointer
                bufferRef.pointee.mAudioDataByteSize = self.bufferByteSize

                // Pre-fill with silence and enqueue
                let ptr = bufferRef.pointee.mAudioData.assumingMemoryBound(to: AudioDataElement.self)
                for j in 0..<kSamplesPerFrame {
                    ptr[j] = 0.0
                }
                AudioQueueEnqueueBuffer(self.outputQueue!, bufferRef, 0, nil)
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
    }

    @inline(__always) func updateSample(_ counter: UInt32, beep: UInt8) {
        // Sample EAR signal or Tape signal
        var amplitude: AudioDataElement = (beep & 0b00010000) > 0 || (beep & 0b01000000) > 0 ? 0.15 : -0.15

        // Add MIC signal
        amplitude += (beep & 0b00001000) > 0 ? 0.025 : -0.025

        sample -= sample / 8
        sample += amplitude / 8

        let offset: Int = (Int(counter) * kSamplesPerFrame) / machine.ticksPerFrame

        // Fill gaps since last write
        if offset > lastWrittenOffset + 1 && lastWrittenOffset >= 0 {
            let fillStart = lastWrittenOffset + 1
            let fillEnd = min(offset, kSamplesPerFrame)
            for i in fillStart..<fillEnd {
                frameBuffer[i] = sample
            }
        }

        if offset >= 0 && offset < kSamplesPerFrame {
            frameBuffer[offset] = sample
            lastWrittenOffset = offset
        }
    }

    func endFrame() {
        if !self.queueStarted {
            self.start()
        }

        // Fill any remaining samples at end of frame
        if lastWrittenOffset < kSamplesPerFrame - 1 {
            let start = max(0, lastWrittenOffset + 1)
            for i in start..<kSamplesPerFrame {
                frameBuffer[i] = sample
            }
        }

        // Push completed frame into the ring buffer (non-blocking)
        let available = ringAvailable()
        if available >= kSamplesPerFrame {
            for i in 0..<kSamplesPerFrame {
                ringBuffer[(writePos + i) % kRingBufferSize] = frameBuffer[i]
            }
            writePos = (writePos + kSamplesPerFrame) % kRingBufferSize
        }
        // If ring is full, we drop this frame's audio (better than blocking)

        lastWrittenOffset = -1
    }

    /// How many samples can be written before the ring is full
    private func ringAvailable() -> Int {
        let w = writePos
        let r = readPos
        if w >= r {
            return kRingBufferSize - (w - r) - 1
        } else {
            return r - w - 1
        }
    }

    /// How many samples are available to read
    private func ringReadable() -> Int {
        let w = writePos
        let r = readPos
        if w >= r {
            return w - r
        } else {
            return kRingBufferSize - r + w
        }
    }

    /// Called from the audio callback on the audio thread
    func fillBuffer(_ dest: UnsafeMutablePointer<AudioDataElement>) {
        let readable = ringReadable()

        if readable >= kSamplesPerFrame {
            // Normal case: enough data in ring
            for i in 0..<kSamplesPerFrame {
                dest[i] = ringBuffer[(readPos + i) % kRingBufferSize]
            }
            readPos = (readPos + kSamplesPerFrame) % kRingBufferSize
        } else if readable > 0 {
            // Partial data: play what we have, pad with last sample
            for i in 0..<readable {
                dest[i] = ringBuffer[(readPos + i) % kRingBufferSize]
            }
            let lastSample = dest[readable - 1]
            for i in readable..<kSamplesPerFrame {
                dest[i] = lastSample
            }
            readPos = (readPos + readable) % kRingBufferSize
        } else {
            // Underrun: output silence (hold last known sample to avoid pops)
            for i in 0..<kSamplesPerFrame {
                dest[i] = sample
            }
        }
    }
}

private func AudioStreamerOuputCallback(userData: UnsafeMutableRawPointer?, queueRef: AudioQueueRef, buffer: AudioQueueBufferRef) {
    let this = Unmanaged<AudioStreamer>.fromOpaque(userData!).takeUnretainedValue()
    let ptr = buffer.pointee.mAudioData.assumingMemoryBound(to: AudioDataElement.self)

    this.fillBuffer(ptr)

    AudioQueueEnqueueBuffer(queueRef, buffer, 0, nil)
}
