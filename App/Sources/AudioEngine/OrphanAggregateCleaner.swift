import CoreAudio
import Foundation

enum OrphanAggregateCleaner {
    static func destroyLeftovers(uidPrefix: String) {
        let devices = (try? AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioDeviceID.self)) ?? []
        for device in devices {
            guard let uid = try? device.readString(kAudioDevicePropertyDeviceUID), uid.hasPrefix(uidPrefix) else { continue }
            AudioHardwareDestroyAggregateDevice(device)
        }
    }
}
