import CoreAudio
import Foundation

struct OutputDevice {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let sampleRate: Double
    let inputStreamCount: Int
    let isBluetooth: Bool

    static func systemDefault() throws -> OutputDevice {
        let id = try AudioObjectID.system.read(kAudioHardwarePropertyDefaultOutputDevice, initial: AudioDeviceID(kAudioObjectUnknown))
        guard id != kAudioObjectUnknown else { throw CoreAudioError(status: kAudioHardwareBadDeviceError, context: "default output device") }
        let transport = (try? id.read(kAudioDevicePropertyTransportType, initial: UInt32(0))) ?? 0
        return OutputDevice(
            id: id,
            uid: try id.readString(kAudioDevicePropertyDeviceUID),
            name: try id.readString(kAudioObjectPropertyName),
            sampleRate: try id.read(kAudioDevicePropertyNominalSampleRate, initial: Double(0)),
            inputStreamCount: (try? id.readArray(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput, of: AudioStreamID.self).count) ?? 0,
            isBluetooth: transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
        )
    }

    var preferredBufferFrames: UInt32 { isBluetooth ? 512 : 256 }
}
