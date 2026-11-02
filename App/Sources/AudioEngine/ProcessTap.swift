import CoreAudio
import Foundation

final class ProcessTap {
    let id: AudioObjectID
    let uid: String
    private(set) var processObjectIDs: [AudioObjectID]
    private let name: String

    init(processObjectIDs: [AudioObjectID], name: String) throws {
        self.name = name
        self.processObjectIDs = processObjectIDs
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(ProcessTap.description(for: processObjectIDs, name: name), &tapID)
        guard status == noErr else { throw CoreAudioError(status: status, context: "create tap \(name)") }
        id = tapID
        uid = try tapID.readString(kAudioTapPropertyUID)
    }

    func update(processObjectIDs: [AudioObjectID]) throws {
        try id.write(kAudioTapPropertyDescription, value: ProcessTap.description(for: processObjectIDs, name: name))
        self.processObjectIDs = processObjectIDs
    }

    func destroy() {
        AudioHardwareDestroyProcessTap(id)
    }

    private static func description(for processObjectIDs: [AudioObjectID], name: String) -> CATapDescription {
        let description = CATapDescription(stereoMixdownOfProcesses: processObjectIDs)
        description.name = name
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        return description
    }
}
