import Foundation

public struct VolumeUsage: Sendable, Equatable {
    public let totalBytes: Int64
    public let availableBytes: Int64

    public init(totalBytes: Int64, availableBytes: Int64) {
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    public var usedBytes: Int64 { totalBytes - availableBytes }

    public var freeFraction: Double {
        totalBytes > 0 ? Double(availableBytes) / Double(totalBytes) : 0
    }

    /// Usage of the volume holding `url`. Defaults to the home folder, which lives on the
    /// writable Data volume (the root `/` is the read-only system volume).
    public static func current(
        for url: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> VolumeUsage {
        let values = try url.resourceValues(forKeys: [
            .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey,
        ])
        return VolumeUsage(
            totalBytes: Int64(values.volumeTotalCapacity ?? 0),
            availableBytes: values.volumeAvailableCapacityForImportantUsage ?? 0
        )
    }
}
