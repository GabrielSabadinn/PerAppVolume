import CoreAudio
import Foundation

public struct OutputDeviceInfo: Identifiable, Equatable {
    public let id: String
    public let name: String
    let deviceID: AudioDeviceID

    public static func == (lhs: OutputDeviceInfo, rhs: OutputDeviceInfo) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

enum OutputDeviceCatalog {
    static func available() -> [OutputDeviceInfo] {
        let deviceIDs = (try? AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioDeviceID.self)) ?? []
        return deviceIDs.compactMap(info(for:)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func select(_ device: OutputDeviceInfo) throws {
        try AudioObjectID.system.write(kAudioHardwarePropertyDefaultOutputDevice, value: device.deviceID)
    }

    private static func info(for deviceID: AudioDeviceID) -> OutputDeviceInfo? {
        guard let uid = try? deviceID.readString(kAudioDevicePropertyDeviceUID), !uid.hasPrefix(AggregateRouter.uidPrefix),
              let outputStreams = try? deviceID.readArray(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput, of: AudioStreamID.self), !outputStreams.isEmpty,
              let name = try? deviceID.readString(kAudioObjectPropertyName) else { return nil }
        return OutputDeviceInfo(id: uid, name: name, deviceID: deviceID)
    }
}
