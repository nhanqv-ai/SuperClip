import Foundation
import ServiceManagement

/// Protocol defining system startup launch management.
public protocol LaunchAtLoginManaging: Sendable {
    var isEnabled: Bool { get }
    @discardableResult
    func setEnabled(_ enable: Bool) -> Bool
}

/// Native macOS SMAppService integration for Launch at Login (macOS 13+ Ventura standard).
public final class LaunchAtLoginManager: LaunchAtLoginManaging, @unchecked Sendable {
    public static let shared = LaunchAtLoginManager()

    public init() {}

    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @discardableResult
    public func setEnabled(_ enable: Bool) -> Bool {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enable {
                    if service.status != .enabled {
                        try service.register()
                    }
                } else {
                    if service.status != .notRegistered && service.status != .notFound {
                        try service.unregister()
                    }
                }
                return true
            } catch {
                NSLog("SuperClip: SMAppService status change notice: \(error.localizedDescription)")
                return false
            }
        }
        return false
    }
}
