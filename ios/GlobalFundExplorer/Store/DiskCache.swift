import Foundation

/// Stores the last successful grant download in the Caches directory so the app
/// opens instantly and works offline.
struct DiskCache: Sendable {
    struct Snapshot: Codable {
        let savedAt: Date
        let grants: [Grant]
    }

    let fileName: String

    init(fileName: String = "grants.json") {
        self.fileName = fileName
    }

    private var url: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func save(_ grants: [Grant]) {
        let snapshot = Snapshot(savedAt: Date(), grants: grants)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
