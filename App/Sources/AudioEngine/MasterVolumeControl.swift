import AudioToolbox
import CoreAudio
import Foundation

struct MasterVolumeControl {
    let deviceID: AudioDeviceID

    func read() -> Float? {
        var address = AudioObjectPropertyAddress(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput)
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        return try? deviceID.read(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput, initial: Float(0))
    }

    func write(_ volume: Float) {
        try? deviceID.write(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput, value: min(max(volume, 0), 1))
    }

    func listen(on queue: DispatchQueue, handler: @escaping () -> Void) -> PropertyListener? {
        try? PropertyListener(objectID: deviceID, selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioObjectPropertyScopeOutput, queue: queue, handler: handler)
    }
}
