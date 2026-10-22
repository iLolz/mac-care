import Foundation

public enum FullDiskAccess {
    /// Opens System Settings at Privacy & Security > Full Disk Access.
    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    )!

    /// macOS has no API for this, so we try to list folders that are protected by TCC:
    /// they can be seen without Full Disk Access but not listed.
    public static func isGranted(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let probes = ["Library/Safari", "Library/Containers/com.apple.stocks", ".Trash"]
            .map { home.appendingPathComponent($0).path }

        for probe in probes where FileManager.default.fileExists(atPath: probe) {
            return (try? FileManager.default.contentsOfDirectory(atPath: probe)) != nil
        }
        return false
    }
}
