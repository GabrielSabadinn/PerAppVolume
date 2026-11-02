import CoreAudio
import Foundation

struct AudioProcessObject: Hashable {
    let objectID: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let isRunningOutput: Bool

    static func enumerate() throws -> [AudioProcessObject] {
        try AudioObjectID.system
            .readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self)
            .compactMap(AudioProcessObject.init(objectID:))
    }

    private init?(objectID: AudioObjectID) {
        guard let pid = try? objectID.read(kAudioProcessPropertyPID, initial: pid_t(0)) else { return nil }
        self.objectID = objectID
        self.pid = pid
        bundleID = (try? objectID.readString(kAudioProcessPropertyBundleID)) ?? ""
        isRunningOutput = ((try? objectID.read(kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))) ?? 0) != 0
    }
}
