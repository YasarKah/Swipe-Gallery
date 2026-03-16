//
//  Swipe_GalleryTests.swift
//  Swipe GalleryTests
//
//  Created by İbrahim Kahramaner on 15.03.2026.
//

import XCTest
@testable import Swipe_Gallery

final class Swipe_GalleryTests: XCTestCase {
    private let completedKey = "groupProgressStore.completedIds"
    private let progressKey = "groupProgressStore.progress"

    override func setUpWithError() throws {
        clearProgressStore()
    }

    override func tearDownWithError() throws {
        clearProgressStore()
    }

    func testCompletedProgressIsPersistedAcrossStoreReloads() throws {
        let store = GroupProgressStore()

        store.setProgress(groupId: "recent-2026-03", viewed: 12, total: 12)

        XCTAssertEqual(store.progress(for: "recent-2026-03")?.percent, 1)
        XCTAssertTrue(store.completedGroupIds.contains("recent-2026-03"))

        let reloadedStore = GroupProgressStore()
        XCTAssertTrue(reloadedStore.completedGroupIds.contains("recent-2026-03"))
        XCTAssertTrue(reloadedStore.progress(for: "recent-2026-03")?.isComplete ?? false)
    }

    func testClearProgressRemovesStoredState() throws {
        let store = GroupProgressStore()
        store.setProgress(groupId: "march-cleanup", viewed: 3, total: 5)
        store.markCompleted("march-cleanup")

        store.clearProgress(for: "march-cleanup")

        XCTAssertNil(store.progress(for: "march-cleanup"))
        XCTAssertFalse(store.completedGroupIds.contains("march-cleanup"))

        let reloadedStore = GroupProgressStore()
        XCTAssertNil(reloadedStore.progress(for: "march-cleanup"))
        XCTAssertFalse(reloadedStore.completedGroupIds.contains("march-cleanup"))
    }

    func testCompletedIdsMigrateFromStoredProgress() throws {
        let legacyProgress = [
            "legacy-group": GroupProgress(viewed: 8, total: 8)
        ]
        let data = try XCTUnwrap(try? JSONEncoder().encode(legacyProgress))
        UserDefaults.standard.set(data, forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: completedKey)

        let store = GroupProgressStore()

        XCTAssertTrue(store.completedGroupIds.contains("legacy-group"))
        XCTAssertTrue(store.progress(for: "legacy-group")?.isComplete ?? false)
    }

    private func clearProgressStore() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: progressKey)
    }
}
