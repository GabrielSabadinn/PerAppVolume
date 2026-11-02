import Foundation

struct GainRamp {
    let start: Float
    let step: Float
    let end: Float

    init(from current: Float, to target: Float, frames: Int, maxStepPerFrame: Float) {
        let delta = target - current
        start = current
        guard frames > 0, delta != 0 else {
            step = 0
            end = current
            return
        }
        let magnitude = min(abs(delta) / Float(frames), maxStepPerFrame)
        step = delta < 0 ? -magnitude : magnitude
        end = magnitude * Float(frames) >= abs(delta) ? target : current + step * Float(frames)
    }
}
