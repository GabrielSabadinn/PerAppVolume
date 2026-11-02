import CoreAudio
import Foundation

final class AggregateDevice {
    let id: AudioDeviceID
    private var procID: AudioDeviceIOProcID?

    init(output: OutputDevice, tap: ProcessTap) throws {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "TapSpike Router",
            kAudioAggregateDeviceUIDKey: "com.gabi.tapspike.router.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: output.uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: output.uid]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tap.uid,
                kAudioSubTapDriftCompensationKey: true,
            ]],
        ]
        var aggregateID = AudioDeviceID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateID)
        guard status == noErr else { throw CoreAudioError(status: status, context: "AudioHardwareCreateAggregateDevice") }
        id = aggregateID
    }

    var bufferFrameSize: UInt32 {
        get { (try? id.read(kAudioDevicePropertyBufferFrameSize, initial: UInt32(0))) ?? 0 }
    }

    func setBufferFrameSize(_ frames: UInt32) throws {
        try id.write(kAudioDevicePropertyBufferFrameSize, value: frames)
    }

    var latencyFrames: UInt32 {
        (try? id.read(kAudioDevicePropertyLatency, scope: kAudioObjectPropertyScopeOutput, initial: UInt32(0))) ?? 0
    }

    var safetyOffsetFrames: UInt32 {
        (try? id.read(kAudioDevicePropertySafetyOffset, scope: kAudioObjectPropertyScopeOutput, initial: UInt32(0))) ?? 0
    }

    func start(_ block: @escaping AudioDeviceIOBlock) throws {
        let queue = DispatchQueue(label: "com.gabi.tapspike.io", qos: .userInteractive)
        var newProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(&newProcID, id, queue, block)
        guard createStatus == noErr, let newProcID else { throw CoreAudioError(status: createStatus, context: "AudioDeviceCreateIOProcIDWithBlock") }
        procID = newProcID
        let startStatus = AudioDeviceStart(id, newProcID)
        guard startStatus == noErr else { throw CoreAudioError(status: startStatus, context: "AudioDeviceStart") }
    }

    func destroy() {
        if let procID {
            AudioDeviceStop(id, procID)
            AudioDeviceDestroyIOProcID(id, procID)
        }
        AudioHardwareDestroyAggregateDevice(id)
    }
}
