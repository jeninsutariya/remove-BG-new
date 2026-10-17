//
//  PhotoPickerLoader.swift
//  Background Removal
//
//  Copies PHPicker results to temporary files without decoding them, keeping the
//  selection order. Photos never leave the device.
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers

nonisolated enum PhotoPickerLoader {

    /// Loads the results one at a time (bounded memory). Items that can't be read are skipped.
    static func load(_ results: [PHPickerResult]) async -> [PickedImage] {
        var picked: [PickedImage] = []
        for result in results {
            if let image = await load(result) { picked.append(image) }
        }
        return picked
    }

    private static func load(_ result: PHPickerResult) async -> PickedImage? {
        let provider = result.itemProvider
        let name = provider.suggestedName
        guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else { return nil }

        let fileURL: URL? = await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                // The provided file is deleted when this handler returns, so copy it first.
                guard let url else { continuation.resume(returning: nil); return }
                let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
                let copy = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Picked-\(UUID().uuidString).\(ext)")
                do {
                    try FileManager.default.copyItem(at: url, to: copy)
                    continuation.resume(returning: copy)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
        if let fileURL {
            return PickedImage(source: .file(fileURL), suggestedName: name)
        }

        // Fallback for providers without a file representation.
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        let image: UIImage? = await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
        return image.map { PickedImage(source: .image($0), suggestedName: name) }
    }
}
