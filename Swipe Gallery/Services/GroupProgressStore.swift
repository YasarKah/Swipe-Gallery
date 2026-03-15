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
    var percent: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(viewed) / Double(total))
    }
}

final class GroupProgressStore: ObservableObject {
    private let completedKey = "groupProgressStore.completedIds"
    private let progressKey = "groupProgressStore.progress"

    @Published private(set) var completedGroupIds: Set<String> = []
    @Published private(set) var groupProgress: [String: GroupProgress] = [:]

    init() {
        load()
    }

    func markCompleted(_ groupId: String) {
        completedGroupIds.insert(groupId)
        saveCompleted()
    }

    func setProgress(groupId: String, viewed: Int, total: Int) {
        guard total > 0 else { return }
        groupProgress[groupId] = GroupProgress(viewed: viewed, total: total)
        saveProgress()
    }

    func progress(for groupId: String) -> GroupProgress? {
        groupProgress[groupId]
    }

    func clearProgress(for groupId: String) {
        groupProgress.removeValue(forKey: groupId)
        completedGroupIds.remove(groupId)
        saveProgress()
        saveCompleted()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: completedKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedGroupIds = decoded
        }
        if let data = UserDefaults.standard.data(forKey: progressKey),
           let decoded = try? JSONDecoder().decode([String: GroupProgress].self, from: data) {
            groupProgress = decoded
        }
    }

    private func saveCompleted() {
        guard let data = try? JSONEncoder().encode(completedGroupIds) else { return }
        UserDefaults.standard.set(data, forKey: completedKey)
    }

    private func saveProgress() {
        guard let data = try? JSONEncoder().encode(groupProgress) else { return }
        UserDefaults.standard.set(data, forKey: progressKey)
    }
}

extension GroupProgress: Codable {}
