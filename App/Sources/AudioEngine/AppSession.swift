import CoreAudio
import Foundation

final class AppSession {
    let identity: AppIdentity
    let order: Int
    let channel: MixerChannel
    var processObjectIDs: [AudioObjectID] = []
    var processNames: [String] = []
    var isPlaying = false
    var lastPlayingAt = Date.distantPast
    var tap: ProcessTap?
    var volume: Float
    var isMuted: Bool

    init(identity: AppIdentity, order: Int, volume: Float, isMuted: Bool) {
        self.identity = identity
        self.order = order
        self.volume = volume
        self.isMuted = isMuted
        channel = MixerChannel(gain: isMuted ? 0 : volume)
    }

    var effectiveGain: Float { isMuted ? 0 : volume }

    func wantsTap(at now: Date, retention: TimeInterval) -> Bool {
        isPlaying || (tap != nil && now.timeIntervalSince(lastPlayingAt) < retention)
    }

    func dropTap() {
        tap?.destroy()
        tap = nil
        channel.settle()
    }

    var snapshot: AppSnapshot {
        AppSnapshot(identity: identity, processNames: processNames, volume: volume, isMuted: isMuted, isPlaying: isPlaying, channel: channel)
    }
}

struct AppSnapshot {
    let identity: AppIdentity
    let processNames: [String]
    let volume: Float
    let isMuted: Bool
    let isPlaying: Bool
    let channel: MixerChannel
}
