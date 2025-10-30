import AppKit
import SwiftUI
import Combine

final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()

    // Track last displayed title to avoid redundant updates
    private var lastDisplayedTitle: String?

    // Event monitors to detect clicks outside the popover
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    func setup(with hostingController: NSViewController, service: VIXService) {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 240)
        popover?.behavior = .transient
        popover?.contentViewController = hostingController
        popover?.delegate = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Try to use a bundled template asset named "VIXIcon" first
            if let bundled = NSImage(named: "VIXIcon") {
                bundled.isTemplate = true
                button.image = bundled
            } else {
                // Fallback to SF Symbol
                button.image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "VIX")
            }

            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover(_:))
            button.target = self

            // Initial title
            updateButtonTitleIfNeeded(button, with: service.latestValue)

            // Subscribe to service updates via Combine
            service.$latestValue
                .receive(on: DispatchQueue.main)
                .sink { [weak self] val in
                    guard let button = self?.statusItem?.button else { return }
                    self?.updateButtonTitleIfNeeded(button, with: val)
                }
                .store(in: &cancellables)

            service.$lastUpdated
                .receive(on: DispatchQueue.main)
                .sink { [weak self] date in
                    guard let button = self?.statusItem?.button else { return }
                    if let d = date {
                        let f = DateFormatter()
                        f.timeStyle = .short
                        f.dateStyle = .none
                        self?.updateToolTipIfNeeded(button, text: "Updated: \(f.string(from: d))")
                    } else {
                        self?.updateToolTipIfNeeded(button, text: nil)
                    }
                }
                .store(in: &cancellables)

            // Ensure initial refresh in case service already has data
            // (Combine sinks above will handle subsequent updates)
            updateButtonTitleIfNeeded(button, with: service.latestValue)
        }
    }

    // Public method to force-refresh the status item from current service values
    func refresh(from service: VIXService) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            self.updateButtonTitleIfNeeded(button, with: service.latestValue)
            if let d = service.lastUpdated {
                let f = DateFormatter()
                f.timeStyle = .short
                f.dateStyle = .none
                self.updateToolTipIfNeeded(button, text: "Updated: \(f.string(from: d))")
            }
        }
    }

    private func updateButtonTitleIfNeeded(_ button: NSStatusBarButton, with value: Double?) {
        let newTitle: String
        if let v = value {
            newTitle = String(format: "%.2f", v)
        } else {
            newTitle = "--"
        }
        if newTitle != lastDisplayedTitle {
            button.title = newTitle
            lastDisplayedTitle = newTitle
            print("StatusBarController.updateButtonTitle -> \(newTitle)")
        }
    }

    private func updateToolTipIfNeeded(_ button: NSStatusBarButton, text: String?) {
        if button.toolTip != text {
            button.toolTip = text
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(sender)
            stopEventMonitoring()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitoring()
        }
    }

    private func startEventMonitoring() {
        stopEventMonitoring()
        // Global monitor captures clicks outside the app
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self else { return }
            self.popover?.performClose(nil)
            self.stopEventMonitoring()
        }
        // Local monitor captures clicks inside the app (so clicks on other UI can also close)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            // If click is outside the popover content view, close it
            if let popover = self.popover, popover.isShown {
                // Determine click location relative to popover window
                if let window = popover.contentViewController?.view.window {
                    let clickPoint = event.locationInWindow
                    // If the event is in a different window, close popover
                    if event.window != window {
                        popover.performClose(nil)
                        self.stopEventMonitoring()
                        return nil
                    }
                } else {
                    popover.performClose(nil)
                    self.stopEventMonitoring()
                    return nil
                }
            }
            return event
        }
    }

    private func stopEventMonitoring() {
        if let g = globalEventMonitor {
            NSEvent.removeMonitor(g)
            globalEventMonitor = nil
        }
        if let l = localEventMonitor {
            NSEvent.removeMonitor(l)
            localEventMonitor = nil
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        stopEventMonitoring()
    }
}
