import CoreAudio
import Foundation

enum PermissionProbe {
    static func run() throws {
        let output = try OutputDevice.systemDefault()
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Per-App Volume Permission Probe"
        description.isPrivate = true
        description.muteBehavior = .unmuted
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(description, &tapID)
        guard tapStatus == noErr else { throw CoreAudioError(status: tapStatus, context: "create probe tap") }
        defer { AudioHardwareDestroyProcessTap(tapID) }
        let router = try AggregateRouter(output: output, tapUIDs: [try tapID.readString(kAudioTapPropertyUID)], mixer: Mixer())
        router.destroy()
    }
}
