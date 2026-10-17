//
//  ZIPExportService.swift
//  Background Removal
//
//  Builds a .zip of the real output files using the system's native archiver
//  (NSFileCoordinator `.forUploading` zips a directory) – no third-party dependency.
//

import Foundation

nonisolated enum ZIPExportError: LocalizedError {
    case empty
    case writeFailed(String)
    case archiveFailed(String)

    var errorDescription: String? {
        switch self {
        case .empty: return "Select at least one finished image to export."
        case .writeFailed(let reason): return "The export files couldn't be written: \(reason)"
        case .archiveFailed(let reason): return "The ZIP archive couldn't be created: \(reason)"
        }
    }
}

nonisolated final class ZIPExportService: Sendable {

    static let shared = ZIPExportService()

    /// Writes `files` into a folder and zips it. Returns the archive URL inside a temporary export
    /// directory; call `cleanUp(_:)` with that URL once the share sheet is finished.
    func createArchive(files: [(name: String, data: Data)], archiveName: String = "BackgroundRemoval_Export") throws -> URL {
        guard !files.isEmpty else { throw ZIPExportError.empty }
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("ZIPExport-\(UUID().uuidString)", isDirectory: true)
        let contentDir = workDir.appendingPathComponent(archiveName, isDirectory: true)
        do {
            try fm.createDirectory(at: contentDir, withIntermediateDirectories: true)
            for file in files {
                try file.data.write(to: contentDir.appendingPathComponent(file.name), options: .atomic)
            }
        } catch {
            try? fm.removeItem(at: workDir)
            throw ZIPExportError.writeFailed(error.localizedDescription)
        }

        let archiveURL = workDir.appendingPathComponent("\(archiveName).zip")
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: contentDir, options: [.forUploading], error: &coordinationError) { zippedURL in
            do {
                try fm.copyItem(at: zippedURL, to: archiveURL)
            } catch {
                copyError = error
            }
        }
        // The loose image files are no longer needed once the archive exists.
        try? fm.removeItem(at: contentDir)

        if let error = coordinationError ?? (copyError as NSError?) {
            try? fm.removeItem(at: workDir)
            throw ZIPExportError.archiveFailed(error.localizedDescription)
        }
        guard let size = (try? fm.attributesOfItem(atPath: archiveURL.path)[.size] as? NSNumber)?.intValue, size > 22 else {
            try? fm.removeItem(at: workDir)
            throw ZIPExportError.archiveFailed("The archive is empty.")
        }
        return archiveURL
    }

    /// Writes one output file into its own temporary export directory (for sharing a single image).
    func writeSingleFile(name: String, data: Data) throws -> URL {
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent("ZIPExport-\(UUID().uuidString)", isDirectory: true)
        let url = workDir.appendingPathComponent(name)
        do {
            try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            try? fm.removeItem(at: workDir)
            throw ZIPExportError.writeFailed(error.localizedDescription)
        }
        return url
    }

    /// Deletes the temporary export directory (never touches project files).
    func cleanUp(_ archiveURL: URL) {
        let workDir = archiveURL.deletingLastPathComponent()
        guard workDir.lastPathComponent.hasPrefix("ZIPExport-") else { return }
        try? FileManager.default.removeItem(at: workDir)
    }
}
