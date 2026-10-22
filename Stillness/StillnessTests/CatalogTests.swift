import XCTest
@testable import Stillness

/// Guards catalog.json: a broken file or a missing audio file should fail here, not in front of users.
@MainActor
final class CatalogTests: XCTestCase {
    func testCatalogLoads() {
        let service = CatalogService()
        XCTAssertNil(service.loadError)
        XCTAssertFalse(service.catalog.items.isEmpty)
    }

    func testIDsAreUnique() {
        let service = CatalogService()
        let ids = service.catalog.items.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Two items share an id")
    }

    func testEveryAudioFileExists() {
        let service = CatalogService()
        for item in service.catalog.items where item.kind != .breathing {
            XCTAssertNotNil(CatalogService.resolve(item.audio), "No audio for \(item.id): \(item.audio)")
        }
        for scene in service.catalog.scenes {
            if let loop = scene.loopAudio {
                XCTAssertNotNil(CatalogService.resolve(loop), "No loop audio for scene \(scene.id)")
            }
        }
    }

    func testReferencesPointToRealEntries() {
        let service = CatalogService()
        let topicIDs = Set(service.catalog.topics.map(\.id))
        let itemIDs = Set(service.catalog.items.map(\.id))
        for item in service.catalog.items {
            XCTAssertTrue(Set(item.topics).isSubset(of: topicIDs), "Unknown topic on \(item.id)")
            if item.narratorID != nil { XCTAssertNotNil(service.narrator(for: item), "Unknown narrator on \(item.id)") }
            if item.seriesID != nil { XCTAssertNotNil(service.series(for: item), "Unknown series on \(item.id)") }
        }
        for id in service.catalog.dailyRotation {
            XCTAssertTrue(itemIDs.contains(id), "Daily rotation lists unknown item \(id)")
        }
    }

    func testDailyItemIsStableWithinADay() {
        let service = CatalogService()
        let morning = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: .now)!
        let night = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
        XCTAssertEqual(service.dailyItem(on: morning)?.id, service.dailyItem(on: night)?.id)
    }

    func testThereIsFreeContentInEveryTab() {
        let service = CatalogService()
        let tabs: [Set<ContentKind>] = [[.sleepStory, .soundscape], [.meditation, .breathing], [.music]]
        for kinds in tabs {
            XCTAssertTrue(service.items(kinds: kinds).contains(where: \.isFree), "No free content for \(kinds)")
        }
    }
}
