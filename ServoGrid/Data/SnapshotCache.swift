import Foundation

struct CacheEnvelope: Codable, Equatable, Sendable {
    let version: Int
    let snapshots: [FuelSnapshot]
}

enum CacheFailure: Error, Equatable {
    case unsupportedVersion(Int)
}

actor SnapshotCache {
    static let currentVersion = 1
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = base.appendingPathComponent("ServoGrid/snapshots-v1.json")
        }
    }

    func load() throws -> CacheEnvelope? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(CacheEnvelope.self, from: data)
        guard envelope.version == Self.currentVersion else {
            throw CacheFailure.unsupportedVersion(envelope.version)
        }
        return envelope
    }

    func save(_ envelope: CacheEnvelope) throws {
        guard envelope.version == Self.currentVersion else {
            throw CacheFailure.unsupportedVersion(envelope.version)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(envelope)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

