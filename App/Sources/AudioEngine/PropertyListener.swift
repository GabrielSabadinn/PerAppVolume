import CoreAudio
import Foundation

final class PropertyListener {
    private let objectID: AudioObjectID
    private var address: AudioObjectPropertyAddress
    private let queue: DispatchQueue
    private let block: AudioObjectPropertyListenerBlock

    init(objectID: AudioObjectID, selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, queue: DispatchQueue, handler: @escaping () -> Void) throws {
        self.objectID = objectID
        self.queue = queue
        address = AudioObjectPropertyAddress(selector, scope: scope)
        block = { _, _ in handler() }
        let status = AudioObjectAddPropertyListenerBlock(objectID, &address, queue, block)
        guard status == noErr else { throw CoreAudioError(status: status, context: "listen \(selector) on object \(objectID)") }
    }

    deinit {
        AudioObjectRemovePropertyListenerBlock(objectID, &address, queue, block)
    }
}
