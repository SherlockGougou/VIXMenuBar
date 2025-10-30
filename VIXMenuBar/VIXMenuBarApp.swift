import SwiftUI
import AppKit

@main
struct VIXMenuBarApp: App {
    // Shared service and controller
    private let service = VIXService()
    private let statusBarController = StatusBarController()

    var body: some Scene {
        Settings { EmptyView() } // keep Settings available
        // No windows; app runs as menu bar utility
    }

    init() {
        // Create the popover view (but defer attaching to status bar until app is running)
        let contentView = ContentView()
            .environmentObject(service)
            .frame(width: 300, height: 240)

        let hosting = NSHostingController(rootView: contentView)

        // Capture locals to avoid capturing `self` in escaping closure
        let svc = service
        let sbc = statusBarController
        let host = hosting

        // Ensure UI-related setup runs on the main runloop after NSApp is initialized
        DispatchQueue.main.async {
            // Hide Dock icon and make app an accessory (menu-bar only)
            NSApplication.shared.setActivationPolicy(.accessory)

            // Attach status bar and popover
            sbc.setup(with: host, service: svc)

            // Start fetching after subscriptions are in place
            svc.startPolling()

            // Trigger an immediate fetch; Combine sinks should update the status bar
            Task {
                await svc.fetchOnce()
            }
        }
    }
}
