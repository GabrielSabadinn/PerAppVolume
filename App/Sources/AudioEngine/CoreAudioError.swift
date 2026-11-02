import CoreAudio
import Foundation

public struct CoreAudioError: Error, CustomStringConvertible {
    public let status: OSStatus
    public let context: String

    public var description: String { "\(context) failed with OSStatus \(status) (\(fourCharCode))" }

    var isIllegalOperation: Bool { status == kAudioHardwareIllegalOperationError }

    private var fourCharCode: String {
        let value = UInt32(bitPattern: status)
        let bytes = [24, 16, 8, 0].map { UInt8((value >> $0) & 0xFF) }
        guard bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return String(status) }
        return String(bytes: bytes, encoding: .ascii) ?? String(status)
    }
}
