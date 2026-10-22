import Foundation
import Observation
import SwiftData

/// Saves audio to Application Support so sessions play without a connection.
@Observable @MainActor
final class DownloadService {
    private(set) var inProgress: Set<String> = []
    var lastError: String?

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static func localURL(for record: DownloadRecord) -> URL? {
        let url = directory.appendingPathComponent(record.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func download(_ item: ContentItem, context: ModelContext) async {
        guard !inProgress.contains(item.id), let source = CatalogService.resolve(item.audio) else { return }
        inProgress.insert(item.id)
        defer { inProgress.remove(item.id) }

        let fileExtension = source.pathExtension.isEmpty ? "m4a" : source.pathExtension
        let fileName = "\(item.id).\(fileExtension)"
        let destination = Self.directory.appendingPathComponent(fileName)

        do {
            let downloaded: URL
            if source.isFileURL {
                downloaded = source
            } else {
                let (temporary, response) = try await URLSession.shared.download(from: source)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw URLError(.badServerResponse)
                }
                downloaded = temporary
            }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: downloaded, to: destination)
            context.insert(DownloadRecord(contentID: item.id, fileName: fileName))
            try context.save()
            lastError = nil
        } catch {
            lastError = "Couldn't download \(item.title). Check your connection and storage, then try again."
        }
    }

    func remove(_ record: DownloadRecord, context: ModelContext) {
        try? FileManager.default.removeItem(at: Self.directory.appendingPathComponent(record.fileName))
        context.delete(record)
        try? context.save()
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: Self.directory)
    }
}
