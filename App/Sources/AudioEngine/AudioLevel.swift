import Foundation

public struct AudioLevel: Equatable {
    public let rms: Float
    public let peak: Float

    public static let silent = AudioLevel(rms: 0, peak: 0)

    func decayed(towardRMS measuredRMS: Float, peak measuredPeak: Float) -> AudioLevel {
        AudioLevel(rms: max(measuredRMS, rms * 0.85), peak: max(measuredPeak, peak * 0.92))
    }
}
