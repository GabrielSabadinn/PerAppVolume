import CoreAudio
import Foundation

final class OutputDeviceMonitor {
    private let queue: DispatchQueue
    private let onDefaultChange: () -> Void
    private let onListChange: () -> Void
    private var defaultDeviceListener: PropertyListener?
    private var deviceListListener: PropertyListener?
    private var sampleRateListener: PropertyListener?

    init(queue: DispatchQueue, onDefaultChange: @escaping () -> Void, onListChange: @escaping () -> Void) {
        self.queue = queue
        self.onDefaultChange = onDefaultChange
        self.onListChange = onListChange
    }

    func start() throws {
        defaultDeviceListener = try PropertyListener(objectID: .system, selector: kAudioHardwarePropertyDefaultOutputDevice, queue: queue, handler: onDefaultChange)
        deviceListListener = try PropertyListener(objectID: .system, selector: kAudioHardwarePropertyDevices, queue: queue, handler: onListChange)
    }

    func track(_ device: OutputDevice) {
        sampleRateListener = try? PropertyListener(objectID: device.id, selector: kAudioDevicePropertyNominalSampleRate, queue: queue, handler: onDefaultChange)
    }

    func stop() {
        defaultDeviceListener = nil
        deviceListListener = nil
        sampleRateListener = nil
    }
}
