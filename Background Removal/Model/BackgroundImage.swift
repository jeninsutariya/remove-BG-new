//
//  BackgroundImage.swift
//  Background Removal
//
//  A remote replacement background listed in `image_urls.json`.
//

import Foundation

nonisolated struct BackgroundImage: Decodable, Identifiable, Hashable {
    let id: Int
    let image: URL

    private enum CodingKeys: String, CodingKey {
        case id, image, url, imageURL = "image_url", imageUrl
    }

    init(id: Int, image: URL) {
        self.id = id
        self.image = image
    }

    /// Accepts `{"id": 1, "image": "https://…"}` and tolerates common variations
    /// (`"id": "1"`, `"url"`, `"image_url"`, `"imageUrl"`).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intID = try? container.decode(Int.self, forKey: .id) {
            id = intID
        } else if let stringID = try? container.decode(String.self, forKey: .id), let intID = Int(stringID) {
            id = intID
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing or invalid id")
        }

        let keys: [CodingKeys] = [.image, .url, .imageURL, .imageUrl]
        for key in keys {
            if let string = try? container.decode(String.self, forKey: key),
               let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
               let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                image = url
                return
            }
        }
        throw DecodingError.dataCorruptedError(forKey: .image, in: container, debugDescription: "Missing or invalid image URL")
    }
}
