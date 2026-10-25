import Foundation

/// Writes backup files to the temporary directory so they can be handed to the share sheet.
enum BackupFiles {
    private static func write(_ data: Data, named name: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func exportJSON(from store: DataStore) throws -> URL {
        let data = try Backup.encode(Backup.build(from: store))
        return try write(data, named: "vehicle-care-backup-\(DateUtil.today()).json", in: FileManager.default.temporaryDirectory)
    }

    static func exportCSVs(from store: DataStore) throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vehicle-care-csv")
        return try Backup.csvFiles(Backup.build(from: store)).map { try write(Data($0.content.utf8), named: $0.name, in: dir) }
    }

    /// Reads a file chosen with the system file importer (security-scoped URL).
    static func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try Data(contentsOf: url)
    }
}
