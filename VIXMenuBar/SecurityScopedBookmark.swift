import Foundation
import AppKit

/// Utilities for handling security-scoped bookmarks to access user's LaunchAgents directory
enum SecurityScopedBookmark {
    private static let launchAgentsBookmarkKey = "LaunchAgentsDirBookmark"

    /// The default LaunchAgents directory URL in the user's home
    static var defaultLaunchAgentsDir: URL {
        let fm = FileManager.default
        return fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents")
    }

    /// Returns the stored security-scoped URL for LaunchAgents if available and resolvable
    static func resolvedLaunchAgentsDir() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: launchAgentsBookmarkKey) else {
            return nil
        }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            if isStale {
                // Try to re-create a fresh bookmark
                try saveLaunchAgentsBookmark(url)
            }
            return url
        } catch {
            return nil
        }
    }

    /// Save a security-scoped bookmark for the LaunchAgents directory
    @discardableResult
    static func saveLaunchAgentsBookmark(_ url: URL) throws -> Data {
        let data = try url.bookmarkData(options: [.withSecurityScope],
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil)
        UserDefaults.standard.set(data, forKey: launchAgentsBookmarkKey)
        return data
    }

    /// Ask user to grant access to the LaunchAgents directory and persist a security-scoped bookmark.
    /// Returns the chosen directory URL if granted, otherwise nil.
    static func requestAccessToLaunchAgents() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Allow access to LaunchAgents folder to enable Launch at Login"
        panel.message = "The app needs permission to create a small configuration file in your ~/Library/LaunchAgents folder so it can start at login."
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = defaultLaunchAgentsDir
        panel.prompt = "Grant Access"

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return nil
        }
        do {
            _ = try saveLaunchAgentsBookmark(url)
        } catch {
            return nil
        }
        return url
    }
}
