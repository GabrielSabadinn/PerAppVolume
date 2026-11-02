import Foundation

final class MixerChannel: @unchecked Sendable {
    var targetGain: Float
    var currentGain: Float
    var measuredRMS: Float = 0
    var peakHold: Float = 0

    init(gain: Float) {
        targetGain = gain
        currentGain = gain
    }

    func settle() {
        currentGain = targetGain
    }

    func consumePeak() -> Float {
        defer { peakHold = 0 }
        return peakHold
    }
}
