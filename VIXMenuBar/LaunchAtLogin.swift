import Foundation
import AppKit
import ServiceManagement

enum LaunchAtLoginError: Error {
    case unsupported
    case registrationFailed(Error?)
    case unregistrationFailed(Error?)
}

struct LaunchAtLogin {
    // Keep label for potential legacy fallback if ever needed
    static let label = "com.gouqinglin.VIXMenuBar"

    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return false
        }
    }

    static func enable() throws {
        guard #available(macOS 13.0, *) else { throw LaunchAtLoginError.unsupported }
        do {
            try SMAppService.mainApp.register()
            // If the system requires user approval, take them to the correct pane
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            // Most common failure: Operation not permitted (user or policy disallows)
            if #available(macOS 13.0, *) {
                SMAppService.openSystemSettingsLoginItems()
            }
            throw LaunchAtLoginError.registrationFailed(error)
        }
    }

    static func disable() throws {
        guard #available(macOS 13.0, *) else { throw LaunchAtLoginError.unsupported }
        let status = SMAppService.mainApp.status
        // If not enabled, do nothing
        guard status == .enabled || status == .requiresApproval else { return }
        do {
            try SMAppService.mainApp.unregister()
            if SMAppService.mainApp.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            if #available(macOS 13.0, *) {
                SMAppService.openSystemSettingsLoginItems()
            }
            throw LaunchAtLoginError.unregistrationFailed(error)
        }
    }

    // No other helpers needed with SMAppService on modern macOS
}
