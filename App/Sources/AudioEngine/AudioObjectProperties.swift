import CoreAudio
import Foundation

extension AudioObjectPropertyAddress {
    init(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) {
        self.init(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func read<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw CoreAudioError(status: status, context: "read \(selector) on object \(self)") }
        return value
    }

    func readString(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> String {
        try read(selector, scope: scope, initial: "" as CFString) as String
    }

    func readArray<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, of: T.Type) throws -> [T] {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size)
        guard sizeStatus == noErr else { throw CoreAudioError(status: sizeStatus, context: "size of \(selector) on object \(self)") }
        let capacity = Swift.max(Int(size) / MemoryLayout<T>.stride, 1)
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer)
        guard status == noErr else { throw CoreAudioError(status: status, context: "read array \(selector) on object \(self)") }
        return Array(UnsafeBufferPointer(start: buffer, count: Int(size) / MemoryLayout<T>.stride))
    }

    func write<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, value: T) throws {
        var address = AudioObjectPropertyAddress(selector, scope: scope)
        var copy = value
        let status = withUnsafePointer(to: &copy) {
            AudioObjectSetPropertyData(self, &address, 0, nil, UInt32(MemoryLayout<T>.size), $0)
        }
        guard status == noErr else { throw CoreAudioError(status: status, context: "write \(selector) on object \(self)") }
    }
}
