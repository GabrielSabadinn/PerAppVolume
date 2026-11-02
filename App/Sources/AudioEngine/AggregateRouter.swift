import CoreAudio
import Foundation

final class AggregateRouter {
    static let uidPrefix = "com.gabi.perappvolume.router."

    private let deviceID: AudioDeviceID
    private var procID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "com.gabi.perappvolume.io", qos: .userInteractive)

    init(output: OutputDevice, tapUIDs: [String], mixer: Mixer) throws {
        deviceID = try AggregateRouter.createDevice(output: output, tapUIDs: tapUIDs)
        try? deviceID.write(kAudioDevicePropertyBufferFrameSize, value: output.preferredBufferFrames)
        do {
            try startIO(mixer: mixer)
        } catch {
            AudioHardwareDestroyAggregateDevice(deviceID)
            throw error
        }
    }

    func updateTaps(_ tapUIDs: [String]) throws {
        try deviceID.write(kAudioAggregateDevicePropertyTapList, value: tapUIDs as CFArray)
    }

    func destroy() {
        if let procID {
            AudioDeviceStop(deviceID, procID)
            AudioDeviceDestroyIOProcID(deviceID, procID)
        }
        AudioHardwareDestroyAggregateDevice(deviceID)
    }

    private func startIO(mixer: Mixer) throws {
        var newProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(&newProcID, deviceID, ioQueue) { _, inputData, _, outputData, _ in
            mixer.render(input: inputData, output: outputData)
        }
        guard createStatus == noErr, let newProcID else { throw CoreAudioError(status: createStatus, context: "create IOProc") }
        procID = newProcID
        let startStatus = AudioDeviceStart(deviceID, newProcID)
        guard startStatus == noErr else { throw CoreAudioError(status: startStatus, context: "start IOProc") }
    }

    private static func createDevice(output: OutputDevice, tapUIDs: [String]) throws -> AudioDeviceID {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Per-App Volume Router",
            kAudioAggregateDeviceUIDKey: uidPrefix + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: output.uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: output.uid]],
            kAudioAggregateDeviceTapListKey: tapUIDs.map { [kAudioSubTapUIDKey: $0, kAudioSubTapDriftCompensationKey: true] },
        ]
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &deviceID)
        guard status == noErr else { throw CoreAudioError(status: status, context: "create aggregate device") }
        return deviceID
    }
}
