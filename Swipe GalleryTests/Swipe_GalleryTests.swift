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
    private let preferencesUpdatedAtKey = "appPreferences.languageUpdatedAt"
    private let migrationSuiteName = "group.com.yasarkah.smartswipe.tests"

    override func setUpWithError() throws {
        clearProgressStore()
        clearMigrationSuite()
    }

    override func tearDownWithError() throws {
        clearProgressStore()
        clearMigrationSuite()
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

    func testGroupProgressDecodesLegacyPayloadWithoutUpdatedAt() throws {
        let data = """
        {
          "legacy-group": {
            "viewed": 4,
            "total": 7
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([String: GroupProgress].self, from: data)

        XCTAssertEqual(decoded["legacy-group"]?.viewed, 4)
        XCTAssertEqual(decoded["legacy-group"]?.total, 7)
        XCTAssertEqual(decoded["legacy-group"]?.updatedAt, .distantPast)
    }

    func testAppGroupMigrationStoreRoundTripsPayload() throws {
        let store = AppGroupMigrationStore(suiteName: migrationSuiteName)
        let payload = MigrationPayload(
            progress: ProgressSnapshot(
                completedGroupIds: ["guided-photos-month-2026-3"],
                groupProgress: [
                    "guided-photos-month-2026-3": GroupProgress(viewed: 22, total: 22, updatedAt: Date(timeIntervalSince1970: 120))
                ],
                updatedAt: Date(timeIntervalSince1970: 120),
                sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            preferences: PreferencesSnapshot(
                languageCode: AppLanguage.english.rawValue,
                updatedAt: Date(timeIntervalSince1970: 80),
                sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            exportedAt: Date(timeIntervalSince1970: 140),
            sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
            appleUserID: "user-1"
        )

        store.savePayload(payload)
        let loaded = store.loadPayload()

        XCTAssertEqual(loaded, payload)
    }

    func testMigrationMergerPrefersCompletedProgress() throws {
        let olderCompleted = MigrationPayload(
            progress: ProgressSnapshot(
                completedGroupIds: ["2026-3"],
                groupProgress: ["2026-3": GroupProgress(viewed: 12, total: 12, updatedAt: Date(timeIntervalSince1970: 100))],
                updatedAt: Date(timeIntervalSince1970: 100),
                sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            preferences: PreferencesSnapshot(
                languageCode: AppLanguage.turkish.rawValue,
                updatedAt: Date(timeIntervalSince1970: 100),
                sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            exportedAt: Date(timeIntervalSince1970: 100),
            sourceBundleIdentifier: AppMigrationConfig.legacyBundleIdentifier,
            appleUserID: "user-1"
        )

        let newerIncomplete = MigrationPayload(
            progress: ProgressSnapshot(
                completedGroupIds: [],
                groupProgress: ["2026-3": GroupProgress(viewed: 4, total: 12, updatedAt: Date(timeIntervalSince1970: 200))],
                updatedAt: Date(timeIntervalSince1970: 200),
                sourceBundleIdentifier: AppMigrationConfig.currentBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            preferences: PreferencesSnapshot(
                languageCode: AppLanguage.english.rawValue,
                updatedAt: Date(timeIntervalSince1970: 200),
                sourceBundleIdentifier: AppMigrationConfig.currentBundleIdentifier,
                migrationVersion: AppMigrationConfig.migrationVersion
            ),
            exportedAt: Date(timeIntervalSince1970: 200),
            sourceBundleIdentifier: AppMigrationConfig.currentBundleIdentifier,
            appleUserID: "user-1"
        )

        let merged = MigrationPayloadMerger.merge(local: nil, shared: olderCompleted, cloud: newerIncomplete)

        XCTAssertEqual(merged?.progress.groupProgress["2026-3"]?.viewed, 12)
        XCTAssertTrue(merged?.progress.completedGroupIds.contains("2026-3") ?? false)
        XCTAssertEqual(merged?.preferences.language, .english)
    }

    func testLocalPreferencesRepositoryPersistsTimestampedLanguage() throws {
        let repository = LocalPreferencesRepository(defaults: .standard)
        let snapshot = PreferencesSnapshot(
            languageCode: AppLanguage.english.rawValue,
            updatedAt: Date(timeIntervalSince1970: 321),
            sourceBundleIdentifier: AppMigrationConfig.currentBundleIdentifier,
            migrationVersion: AppMigrationConfig.migrationVersion
        )

        repository.saveSnapshot(snapshot)
        let loaded = repository.loadSnapshot()

        XCTAssertEqual(loaded.language, .english)
        XCTAssertEqual(loaded.updatedAt, Date(timeIntervalSince1970: 321))
    }

    private func clearProgressStore() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.removeObject(forKey: progressKey)
        UserDefaults.standard.removeObject(forKey: LocalPreferencesRepository.languageKey)
        UserDefaults.standard.removeObject(forKey: preferencesUpdatedAtKey)
    }

    private func clearMigrationSuite() {
        guard let defaults = UserDefaults(suiteName: migrationSuiteName) else { return }
        defaults.removeObject(forKey: AppMigrationConfig.appGroupPayloadKey)
    }
}
