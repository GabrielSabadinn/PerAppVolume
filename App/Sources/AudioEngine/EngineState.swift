import Foundation

public enum EngineState: Equatable {
    case idle
    case awaitingPermission
    case running
    case permissionDenied
    case failed(String)
}
