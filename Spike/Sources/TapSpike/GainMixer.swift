import Accelerate
import CoreAudio
import Foundation

final class GainMixer {
    var gain: Float
    private let tapBufferOffset: Int
    private(set) var callbackCount = 0
    private(set) var inputPeak: Float = 0
    private(set) var outputPeak: Float = 0
    private(set) var inputBufferCount = 0
    private(set) var outputBufferCount = 0

    init(gain: Float, tapBufferOffset: Int) {
        self.gain = gain
        self.tapBufferOffset = tapBufferOffset
    }

    func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>) {
        let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outputBuffers = UnsafeMutableAudioBufferListPointer(output)
        callbackCount += 1
        inputBufferCount = inputBuffers.count
        outputBufferCount = outputBuffers.count

        for (index, outBuffer) in outputBuffers.enumerated() {
            guard let outData = outBuffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
            let outFrames = Int(outBuffer.mDataByteSize) / MemoryLayout<Float>.size
            let inIndex = tapBufferOffset + index
            guard inIndex < inputBuffers.count, let inData = inputBuffers[inIndex].mData?.assumingMemoryBound(to: Float.self) else {
                vDSP_vclr(outData, 1, vDSP_Length(outFrames))
                continue
            }
            let frames = min(outFrames, Int(inputBuffers[inIndex].mDataByteSize) / MemoryLayout<Float>.size)
            var currentGain = gain
            vDSP_vsmul(inData, 1, &currentGain, outData, 1, vDSP_Length(frames))
            var peak: Float = 0
            vDSP_maxmgv(inData, 1, &peak, vDSP_Length(frames))
            inputPeak = max(inputPeak, peak)
            vDSP_maxmgv(outData, 1, &peak, vDSP_Length(frames))
            outputPeak = max(outputPeak, peak)
        }
    }

    func drainPeaks() -> (input: Float, output: Float) {
        defer { inputPeak = 0; outputPeak = 0 }
        return (inputPeak, outputPeak)
    }
}
