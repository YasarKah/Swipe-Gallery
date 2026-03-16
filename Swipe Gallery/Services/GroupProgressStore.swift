//
//  GroupProgressStore.swift
//  Swipe Gallery
//
//  Tamamlanan gruplar ve grup bazında görüntülenen/toplam ilerleme. UserDefaults ile kalıcı.
//

import Foundation
import SwiftUI

/// Grup ilerlemesi: kaç öğe görüntülendi, toplam kaç öğe
struct GroupProgress: Equatable {
    let viewed: Int
    let total: Int
    let updatedAt: Date

    init(viewed: Int, total: Int, updatedAt: Date = Date()) {
        self.viewed = viewed
        self.total = total
        self.updatedAt = updatedAt
    }

    var percent: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(viewed) / Double(total))
    }

    var isComplete: Bool {
        total > 0 && viewed >= total
    }
}

protocol ProgressSnapshotRepository {
    func loadSnapshot() -> ProgressSnapshot
    func saveSnapshot(_ snapshot: ProgressSnapshot)
}

final class LocalProgressRepository: ProgressSnapshotRepository {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> ProgressSnapshot {
        let completedKey = GroupProgressStore.completedKey
        let progressKey = GroupProgressStore.progressKey

        let completedGroupIds: Set<String>
        if let data = defaults.data(forKey: completedKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedGroupIds = decoded
        } else {
            completedGroupIds = []
        }

        let groupProgress: [String: GroupProgress]
        if let data = defaults.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([String: GroupProgress].self, from: data) {
            groupProgress = decoded
        } else {
            groupProgress = [:]
        }

        let updatedAt = groupProgress.values.map(\.updatedAt).max() ?? .distantPast
        return ProgressSnapshot(
            completedGroupIds: completedGroupIds,
            groupProgress: groupProgress,
            updatedAt: updatedAt,
            sourceBundleIdentifier: Bundle.main.bundleIdentifier ?? AppMigrationConfig.currentBundleIdentifier,
            migrationVersion: AppMigrationConfig.migrationVersion
        )
    }

    func saveSnapshot(_ snapshot: ProgressSnapshot) {
        guard let completedData = try? JSONEncoder().encode(snapshot.completedGroupIds),
              let progressData = try? JSONEncoder().encode(snapshot.groupProgress) else {
            return
        }

        defaults.set(completedData, forKey: GroupProgressStore.completedKey)
        defaults.set(progressData, forKey: GroupProgressStore.progressKey)
    }
}

final class GroupProgressStore: ObservableObject {
    static let completedKey = "groupProgressStore.completedIds"
    static let progressKey = "groupProgressStore.progress"

    private let repository: ProgressSnapshotRepository
    var onSnapshotChanged: ((ProgressSnapshot) -> Void)?

    @Published private(set) var completedGroupIds: Set<String> = []
    @Published private(set) var groupProgress: [String: GroupProgress] = [:]

    init(repository: ProgressSnapshotRepository = LocalProgressRepository()) {
        self.repository = repository
        load()
    }

    func markCompleted(_ groupId: String) {
        completedGroupIds.insert(groupId)
        persist()
    }

    func setProgress(groupId: String, viewed: Int, total: Int) {
        guard total > 0 else { return }
        let progress = GroupProgress(viewed: viewed, total: total)
        groupProgress[groupId] = progress
        if progress.isComplete {
            completedGroupIds.insert(groupId)
        }
        persist()
    }

    func progress(for groupId: String) -> GroupProgress? {
        groupProgress[groupId]
    }

    func clearProgress(for groupId: String) {
        groupProgress.removeValue(forKey: groupId)
        completedGroupIds.remove(groupId)
        persist()
    }

    var hasAnyProgress: Bool {
        !completedGroupIds.isEmpty || !groupProgress.isEmpty
    }

    func snapshot(
        sourceBundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppMigrationConfig.currentBundleIdentifier
    ) -> ProgressSnapshot {
        ProgressSnapshot(
            completedGroupIds: completedGroupIds,
            groupProgress: groupProgress,
            updatedAt: groupProgress.values.map(\.updatedAt).max() ?? Date(),
            sourceBundleIdentifier: sourceBundleIdentifier,
            migrationVersion: AppMigrationConfig.migrationVersion
        )
    }

    func replace(with snapshot: ProgressSnapshot, notify: Bool = true) {
        completedGroupIds = snapshot.completedGroupIds
        groupProgress = snapshot.groupProgress
        migrateCompletedIdsFromProgress()
        repository.saveSnapshot(self.snapshot(sourceBundleIdentifier: snapshot.sourceBundleIdentifier))
        if notify {
            onSnapshotChanged?(self.snapshot())
        }
    }

    private func load() {
        let snapshot = repository.loadSnapshot()
        completedGroupIds = snapshot.completedGroupIds
        groupProgress = snapshot.groupProgress
        migrateCompletedIdsFromProgress()
    }

    private func persist() {
        let currentSnapshot = snapshot()
        repository.saveSnapshot(currentSnapshot)
        onSnapshotChanged?(currentSnapshot)
    }

    private func migrateCompletedIdsFromProgress() {
        let completedFromProgress = groupProgress
            .filter { $0.value.isComplete }
            .map(\.key)

        guard !completedFromProgress.isEmpty else { return }

        let originalCount = completedGroupIds.count
        completedGroupIds.formUnion(completedFromProgress)

        if completedGroupIds.count != originalCount {
            repository.saveSnapshot(snapshot())
        }
    }
}

extension GroupProgress: Codable {
    private enum CodingKeys: String, CodingKey {
        case viewed
        case total
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let viewed = try container.decode(Int.self, forKey: .viewed)
        let total = try container.decode(Int.self, forKey: .total)
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date.distantPast
        self.init(viewed: viewed, total: total, updatedAt: updatedAt)
    }
}
