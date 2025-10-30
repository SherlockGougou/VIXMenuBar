import Foundation

enum LaunchAtLoginError: Error {
    case cannotCreateDirectory
    case cannotWritePlist(Error)
    case cannotRemovePlist(Error)
    case launchctlError(String)
}

struct LaunchAtLogin {
    static let label = "com.gouqinglin.VIXMenuBar"

    static var plistURL: URL {
        let fm = FileManager.default
        return fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
            .appendingPathComponent("\(label).plist")
    }

    static func isEnabled() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: plistURL.path)
    }

    static func enable() throws {
        let fm = FileManager.default
        let dir = plistURL.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw LaunchAtLoginError.cannotCreateDirectory
        }

        let programPath = Bundle.main.bundlePath

        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", programPath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch {
            throw LaunchAtLoginError.cannotWritePlist(error)
        }

        // We intentionally do not call `launchctl bootstrap` here because it frequently
        // fails when called from inside apps due to system restrictions. Writing the plist
        // to ~/Library/LaunchAgents is sufficient: launchd will load it at next login.
    }

    static func disable() throws {
        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: plistURL.path) {
                try fm.removeItem(at: plistURL)
            }
        } catch {
            throw LaunchAtLoginError.cannotRemovePlist(error)
        }
    }

    // Helper to run launchctl if manual load/unload is desired (not used by default)
    private static func runLaunchctl(args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let str = String(data: data, encoding: .utf8) ?? ""
            throw LaunchAtLoginError.launchctlError(str)
        }
    }
}
