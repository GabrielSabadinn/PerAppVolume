import CoreAudio
import Foundation

final class ProcessTap {
    let id: AudioObjectID
    let uid: String
    let format: AudioStreamBasicDescription

    init(process: AudioProcess) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: [process.objectID])
        description.name = "TapSpike \(process.bundleID)"
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else { throw CoreAudioError(status: status, context: "AudioHardwareCreateProcessTap") }
        id = tapID
        uid = try tapID.readString(kAudioTapPropertyUID)
        format = try tapID.read(kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
    }

    func destroy() {
        AudioHardwareDestroyProcessTap(id)
    }
}
