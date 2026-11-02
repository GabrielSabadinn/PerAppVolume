import AudioEngine
import Foundation

enum LevelScale {
    private static let floorDecibels: Float = -50

    static func normalized(_ level: AudioLevel, gain: Float) -> Float {
        guard gain > 0.001 else { return 0 }
        return decibelsToUnit(level.rms / gain)
    }

    private static func decibelsToUnit(_ amplitude: Float) -> Float {
        guard amplitude > 0 else { return 0 }
        let decibels = 20 * log10(amplitude)
        return min(max((decibels - floorDecibels) / -floorDecibels, 0), 1)
    }
}
