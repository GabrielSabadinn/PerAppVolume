import CoreAudio
import Foundation

struct CoreAudioError: Error, CustomStringConvertible {
    let status: OSStatus
    let context: String

    var description: String { "\(context) failed with OSStatus \(status) (\(fourCharCode(status)))" }

    private func fourCharCode(_ status: OSStatus) -> String {
        let value = UInt32(bitPattern: status)
        let bytes = [24, 16, 8, 0].map { UInt8((value >> $0) & 0xFF) }
        guard bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return String(status) }
        return String(bytes: bytes, encoding: .ascii) ?? String(status)
    }
}

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func read<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(self, &address, 0, nil, &size, $0)
        }
        guard status == noErr else { throw CoreAudioError(status: status, context: "read \(selector) on \(self)") }
        return value
    }

    func readString(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> String {
        try read(selector, scope: scope, initial: "" as CFString) as String
    }

    func readArray<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, of: T.Type) throws -> [T] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let sizeStatus = AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size)
        guard sizeStatus == noErr else { throw CoreAudioError(status: sizeStatus, context: "size \(selector) on \(self)") }
        let count = Int(size) / MemoryLayout<T>.stride
        let buffer = UnsafeMutablePointer<T>.allocate(capacity: Swift.max(count, 1))
        defer { buffer.deallocate() }
        let status = AudioObjectGetPropertyData(self, &address, 0, nil, &size, buffer)
        guard status == noErr else { throw CoreAudioError(status: status, context: "read array \(selector) on \(self)") }
        return Array(UnsafeBufferPointer(start: buffer, count: Int(size) / MemoryLayout<T>.stride))
    }

    func write<T>(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, value: T) throws {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var copy = value
        let status = withUnsafePointer(to: &copy) {
            AudioObjectSetPropertyData(self, &address, 0, nil, UInt32(MemoryLayout<T>.size), $0)
        }
        guard status == noErr else { throw CoreAudioError(status: status, context: "write \(selector) on \(self)") }
    }
}
