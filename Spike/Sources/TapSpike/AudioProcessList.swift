import CoreAudio
import Foundation

struct AudioProcess {
    let objectID: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let isRunningOutput: Bool

    static func all() throws -> [AudioProcess] {
        try AudioObjectID.system
            .readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self)
            .compactMap(AudioProcess.init(objectID:))
    }

    private init?(objectID: AudioObjectID) {
        guard let pid = try? objectID.read(kAudioProcessPropertyPID, initial: pid_t(0)) else { return nil }
        self.objectID = objectID
        self.pid = pid
        bundleID = (try? objectID.readString(kAudioProcessPropertyBundleID)) ?? ""
        isRunningOutput = ((try? objectID.read(kAudioProcessPropertyIsRunningOutput, initial: UInt32(0))) ?? 0) != 0
    }

    var processName: String {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return "?" }
        return withUnsafePointer(to: &info.kp_proc.p_comm) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { String(cString: $0) }
        }
    }
}

struct OutputDevice {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let sampleRate: Double
    let inputStreamCount: Int

    static func systemDefault() throws -> OutputDevice {
        let id = try AudioObjectID.system.read(kAudioHardwarePropertyDefaultOutputDevice, initial: AudioDeviceID(kAudioObjectUnknown))
        return OutputDevice(
            id: id,
            uid: try id.readString(kAudioDevicePropertyDeviceUID),
            name: try id.readString(kAudioObjectPropertyName),
            sampleRate: try id.read(kAudioDevicePropertyNominalSampleRate, initial: Double(0)),
            inputStreamCount: (try? id.readArray(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput, of: AudioStreamID.self).count) ?? 0
        )
    }
}
