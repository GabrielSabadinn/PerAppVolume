import Accelerate
import CoreAudio
import Foundation
import os

final class Mixer: @unchecked Sendable {
    private static let rampDuration: Float = 0.010
    private static let scratchCapacity = 8192

    private let channels = OSAllocatedUnfairLock<[MixerChannel]>(initialState: [])
    private let master = MixerChannel(gain: 1)
    private let scratch = UnsafeMutablePointer<Float>.allocate(capacity: Mixer.scratchCapacity)
    private var maxStepPerFrame: Float = 1 / (Mixer.rampDuration * 48_000)
    private var tapBufferOffset = 0

    deinit {
        scratch.deallocate()
    }

    func configure(sampleRate: Double, tapBufferOffset: Int) {
        maxStepPerFrame = 1 / (Mixer.rampDuration * Float(sampleRate))
        self.tapBufferOffset = tapBufferOffset
    }

    func setChannels(_ newChannels: [MixerChannel]) {
        channels.withLock { $0 = newChannels }
    }

    func fadeMasterOut() {
        master.targetGain = 0
    }

    func fadeMasterIn() {
        master.currentGain = 0
        master.targetGain = 1
    }

    func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
        guard let outBuffer = outputBuffers.first, let outData = outBuffer.mData?.assumingMemoryBound(to: Float.self) else { return }
        let outChannels = Int(outBuffer.mNumberChannels)
        let outFrames = Int(outBuffer.mDataByteSize) / (MemoryLayout<Float>.size * outChannels)
        vDSP_vclr(outData, 1, vDSP_Length(outFrames * outChannels))

        let activeChannels = channels.withLock { $0 }
        for (index, channel) in activeChannels.enumerated() {
            let inIndex = tapBufferOffset + index
            guard inIndex < inputBuffers.count, let inData = inputBuffers[inIndex].mData?.assumingMemoryBound(to: Float.self) else {
                channel.settle()
                continue
            }
            mix(channel, from: inData, inChannels: Int(inputBuffers[inIndex].mNumberChannels), inFrames: Int(inputBuffers[inIndex].mDataByteSize) / (MemoryLayout<Float>.size * Int(inputBuffers[inIndex].mNumberChannels)), into: outData, outChannels: outChannels, outFrames: outFrames)
        }
        applyMaster(to: outData, channels: outChannels, frames: outFrames)
    }

    private func mix(_ channel: MixerChannel, from inData: UnsafePointer<Float>, inChannels: Int, inFrames: Int, into outData: UnsafeMutablePointer<Float>, outChannels: Int, outFrames: Int) {
        let frames = min(inFrames, outFrames, Mixer.scratchCapacity)
        let ramp = GainRamp(from: channel.currentGain, to: channel.targetGain, frames: frames, maxStepPerFrame: maxStepPerFrame)
        var rms: Float = 0
        var peak: Float = 0
        for channelIndex in 0..<min(inChannels, outChannels) {
            var start = ramp.start
            var step = ramp.step
            vDSP_vrampmul(inData + channelIndex, inChannels, &start, &step, scratch, 1, vDSP_Length(frames))
            vDSP_vadd(scratch, 1, outData + channelIndex, outChannels, outData + channelIndex, outChannels, vDSP_Length(frames))
            var channelRMS: Float = 0
            var channelPeak: Float = 0
            vDSP_rmsqv(scratch, 1, &channelRMS, vDSP_Length(frames))
            vDSP_maxmgv(scratch, 1, &channelPeak, vDSP_Length(frames))
            rms = max(rms, channelRMS)
            peak = max(peak, channelPeak)
        }
        channel.currentGain = ramp.end
        channel.measuredRMS = rms
        channel.peakHold = max(channel.peakHold, peak)
    }

    private func applyMaster(to outData: UnsafeMutablePointer<Float>, channels: Int, frames: Int) {
        let ramp = GainRamp(from: master.currentGain, to: master.targetGain, frames: frames, maxStepPerFrame: maxStepPerFrame)
        var start = ramp.start
        var step = ramp.step / Float(channels)
        vDSP_vrampmul(outData, 1, &start, &step, outData, 1, vDSP_Length(frames * channels))
        master.currentGain = ramp.end
    }
}
