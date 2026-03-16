//
//  HomeView.swift
//  Swipe Gallery
//
//  Ana ekran: grup kartları listesi ve "Videoları dahil et" toggle.
//

import SwiftUI

struct HomeView: View {
    private enum GroupSortOption: String, CaseIterable, Identifiable {
        case newestFirst
        case oldestFirst
        case largestFirst
        case smallestFirst

        var id: String { rawValue }
    }

    private struct NavigationTarget: Identifiable, Hashable {
        let group: MediaGroup
        let startIndex: Int
        var id: String { "\(group.id)-\(startIndex)" }
    }

    @EnvironmentObject private var preferences: AppPreferences
    @State private var includeVideos: Bool = false
    @State private var groups: [MediaGroup] = []
    @State private var selectedTarget: NavigationTarget?
    @State private var resumePromptGroup: MediaGroup?
    @State private var showSettings = false
    @State private var showSortSheet = false
    @State private var sortOption: GroupSortOption = .newestFirst
    @State private var isLoading = true
    @State private var loadError: String?
    @StateObject private var deleteQueue = DeleteQueueService()
    @StateObject private var progressStore = GroupProgressStore()

    private let groupingService = MediaGroupingService()

    var body: some View {
        NavigationStack {
            ZStack {
                screenBackground
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = loadError {
                    errorView(message: error)
                } else if groups.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            guidedCleanupSection
                            groupListHeader
                            groupRows
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle(preferences.text(.appTitle))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        AppFeedback.selection()
                        showSortSheet = true
                    } label: {
                        toolbarIcon(systemName: "arrow.up.arrow.down")
                    }

                    Button {
                        AppFeedback.selection()
                        showSettings = true
                    } label: {
                        toolbarIcon(systemName: "gearshape.fill")
                    }
                }
            }
            .task(id: "\(includeVideos)-\(preferences.language.rawValue)") { await loadGroups() }
            .navigationDestination(item: $selectedTarget) { target in
                destinationView(for: target)
            }
            .alert(preferences.text(.resumeTitle), isPresented: resumePromptBinding) {
                Button(preferences.text(.continueFromWhereLeft)) {
                    openPendingGroup(startFromSavedProgress: true)
                }
                Button(preferences.text(.restartFromBeginning)) {
                    openPendingGroup(startFromSavedProgress: false)
                }
                Button(preferences.text(.cancel), role: .cancel) {
                    resumePromptGroup = nil
                }
            } message: {
                Text(preferences.text(.resumeMessage))
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(
                    includeVideos: $includeVideos
                )
                .environmentObject(preferences)
            }
            .confirmationDialog(preferences.text(.sort), isPresented: $showSortSheet, titleVisibility: .visible) {
                Button(preferences.text(.sortNewestFirst)) { sortOption = .newestFirst }
                Button(preferences.text(.sortOldestFirst)) { sortOption = .oldestFirst }
                Button(preferences.text(.sortLargestFirst)) { sortOption = .largestFirst }
                Button(preferences.text(.sortSmallestFirst)) { sortOption = .smallestFirst }
                Button(preferences.text(.cancel), role: .cancel) { }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text(preferences.text(.loadingGallery))
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            preferences.text(.accessRequired),
            systemImage: "photo.on.rectangle.angled",
            description: Text(message)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            preferences.text(.noPhotosFound),
            systemImage: "photo.on.rectangle.angled",
            description: Text(preferences.text(.noPhotosDescription))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var groupListHeader: some View {
        HStack {
            Text(preferences.text(.groupsTitle))
                .font(.title3.weight(.bold))
                .foregroundStyle(AppPalette.textPrimary)
            Spacer()
            AccentBadge(text: sortOptionTitle, accent: AppPalette.accentBlue, useMaterial: false)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var groupRows: some View {
        ForEach(Array(sortedGroups.enumerated()), id: \.element.id) { index, group in
            let resolvedGroup = resolvedGroup(for: group)
            GroupRowView(
                group: resolvedGroup,
                includeVideos: includeVideos,
                progressViewed: progressStore.progress(for: resolvedGroup.id)?.viewed ?? 0,
                progressTotal: progressStore.progress(for: resolvedGroup.id)?.total ?? 0,
                rowIndex: index,
                onTap: { handleGroupTap(resolvedGroup) }
            )
        }
    }

    private var guidedCleanupSection: some View {
        NavigationLink {
            GuidedCleanupView(
                includeVideos: includeVideos,
                progressStore: progressStore
            )
            .environmentObject(preferences)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preferences.text(.guidedCleanupHomeTitle))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppPalette.textPrimary)
                        Text(preferences.text(.guidedCleanupHomeSubtitle))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppPalette.textPrimary)
                        .frame(width: 50, height: 50)
                        .background {
                            Circle()
                                .fill(AppPalette.cardBase.opacity(0.96))
                        }
                        .overlay {
                            Circle()
                                .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
                        }
                }

                Text(preferences.text(.guidedCleanupHomeDetail))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    heroBadge(text: preferences.text(.guidedCleanupTitle), accent: AppPalette.accentPurple)
                    heroBadge(text: preferences.text(.sortNewestFirst), accent: AppPalette.accentBlue)
                    if includeVideos {
                        heroBadge(text: "🎬", accent: AppPalette.accentPink)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        AppPalette.cardBase.opacity(0.98),
                        AppPalette.accentPurple.opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppPalette.accentPurple.opacity(0.18), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                AppFeedback.selection()
            }
        )
    }

    private func loadGroups() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let result = await groupingService.fetchGroups(
            includeVideos: includeVideos,
            completedGroupIds: progressStore.completedGroupIds,
            language: preferences.language
        )

        if result.isEmpty {
            let hasAccess = groupingService.hasPhotoAccess()
            if !hasAccess {
                loadError = preferences.text(.noPhotosDescription)
            }
        }
        groups = result
    }

    private var screenBackground: some View {
        AppBackgroundView()
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppPalette.surface)
    }

    private var sortedGroups: [MediaGroup] {
        let pinned = groups.filter { $0.type == .smart }
        let remaining = groups.filter { $0.type != .smart }

        let sorted = remaining.sorted { lhs, rhs in
            switch sortOption {
            case .newestFirst:
                return sortDate(for: lhs) > sortDate(for: rhs)
            case .oldestFirst:
                return sortDate(for: lhs) < sortDate(for: rhs)
            case .largestFirst:
                return totalCount(for: lhs) > totalCount(for: rhs)
            case .smallestFirst:
                return totalCount(for: lhs) < totalCount(for: rhs)
            }
        }

        return pinned + sorted
    }

    private func sortDate(for group: MediaGroup) -> Date {
        switch group.type {
        case .today:
            return Date()
        case .recent:
            return Date().addingTimeInterval(-60)
        case .random:
            return Date().addingTimeInterval(-120)
        case .monthCollection:
            return group.childGroups.compactMap { $0.dateRange?.upperBound }.max() ?? .distantPast
        default:
            return group.dateRange?.upperBound ?? .distantPast
        }
    }

    private func totalCount(for group: MediaGroup) -> Int {
        group.photoCount + group.videoCount
    }

    @ViewBuilder
    private func destinationView(for target: NavigationTarget) -> some View {
        switch target.group.type {
        case .smart:
            SmartGroupsView(
                group: target.group,
                includeVideos: includeVideos,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        case .smartCategory(let kind):
            if kind == .similar {
                SmartCategoryGroupsView(
                    group: target.group,
                    includeVideos: includeVideos,
                    deleteQueue: deleteQueue,
                    progressStore: progressStore
                )
            } else {
                GroupDetailView(
                    group: target.group,
                    includeVideos: includeVideos,
                    initialIndex: target.startIndex,
                    deleteQueue: deleteQueue,
                    progressStore: progressStore
                )
            }
        case .monthCollection:
            MonthCollectionView(
                group: target.group,
                includeVideos: includeVideos,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        default:
            GroupDetailView(
                group: target.group,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        }
    }

    private func resolvedGroup(for group: MediaGroup) -> MediaGroup {
        var resolved = group
        resolved.isCompleted = isCompleted(group.id)
        resolved.childGroups = group.childGroups.map { child in
            var updatedChild = child
            updatedChild.isCompleted = isCompleted(child.id)
            return updatedChild
        }

        if case .monthCollection = group.type {
            resolved.isCompleted = !resolved.childGroups.isEmpty && resolved.childGroups.allSatisfy(\.isCompleted)
        }

        return resolved
    }

    private func handleGroupTap(_ group: MediaGroup) {
        AppFeedback.selection()
        guard shouldAskToResume(for: group) else {
            selectedTarget = NavigationTarget(group: group, startIndex: 0)
            return
        }
        resumePromptGroup = group
    }

    private func shouldAskToResume(for group: MediaGroup) -> Bool {
        guard group.type != .smart && group.type != .monthCollection else { return false }
        if case .smartCategory(.similar) = group.type { return false }
        guard let progress = progressStore.progress(for: group.id) else { return false }
        return progress.viewed > 0 && !progress.isComplete
    }

    private func isCompleted(_ groupId: String) -> Bool {
        progressStore.completedGroupIds.contains(groupId) || (progressStore.progress(for: groupId)?.isComplete ?? false)
    }

    private func openPendingGroup(startFromSavedProgress: Bool) {
        guard let group = resumePromptGroup else { return }
        let startIndex: Int

        if startFromSavedProgress {
            AppFeedback.selection()
            startIndex = progressStore.progress(for: group.id)?.viewed ?? 0
        } else {
            AppFeedback.warning()
            progressStore.clearProgress(for: group.id)
            startIndex = 0
        }

        selectedTarget = NavigationTarget(group: resolvedGroup(for: group), startIndex: startIndex)
        resumePromptGroup = nil
    }

    private var resumePromptBinding: Binding<Bool> {
        Binding(
            get: { resumePromptGroup != nil },
            set: { isPresented in
                if !isPresented { resumePromptGroup = nil }
            }
        )
    }

    private func heroBadge(text: String, accent: Color) -> some View {
        AccentBadge(text: text, accent: accent, prominent: true, useMaterial: false)
    }

    private var sortOptionTitle: String {
        switch sortOption {
        case .newestFirst:
            return preferences.text(.sortNewestFirst)
        case .oldestFirst:
            return preferences.text(.sortOldestFirst)
        case .largestFirst:
            return preferences.text(.sortLargestFirst)
        case .smallestFirst:
            return preferences.text(.sortSmallestFirst)
        }
    }

    private func toolbarIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.textPrimary)
            .frame(width: 34, height: 34)
            .background {
                Circle()
                    .fill(AppPalette.cardBase.opacity(0.94))
            }
            .overlay {
                Circle()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.14), lineWidth: 1)
            }
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppPreferences())
            .previewDisplayName("Ana ekran")
    }
}

private struct MonthCollectionView: View {
    @EnvironmentObject private var preferences: AppPreferences
    private struct NavigationTarget: Identifiable, Hashable {
        let group: MediaGroup
        let startIndex: Int
        var id: String { "\(group.id)-\(startIndex)" }
    }

    let group: MediaGroup
    let includeVideos: Bool
    @ObservedObject var deleteQueue: DeleteQueueService
    @ObservedObject var progressStore: GroupProgressStore
    @State private var selectedTarget: NavigationTarget?
    @State private var resumePromptGroup: MediaGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionIntro(preferences.text(.monthCollectionDescription), accent: AppPalette.accentBlue)

                VStack(spacing: 12) {
                    ForEach(Array(group.childGroups.enumerated()), id: \.element.id) { index, child in
                        let resolvedChild = resolvedGroup(for: child)
                        GroupRowView(
                            group: resolvedChild,
                            includeVideos: includeVideos,
                            progressViewed: progressStore.progress(for: resolvedChild.id)?.viewed ?? 0,
                            progressTotal: progressStore.progress(for: resolvedChild.id)?.total ?? 0,
                            rowIndex: index,
                            onTap: { handleGroupTap(resolvedChild) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            AppBackgroundView()
                .ignoresSafeArea()
        )
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedTarget) { target in
            GroupDetailView(
                group: target.group,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        }
        .alert(preferences.text(.resumeTitle), isPresented: resumePromptBinding) {
            Button(preferences.text(.continueFromWhereLeft)) {
                openPendingGroup(startFromSavedProgress: true)
            }
            Button(preferences.text(.restartFromBeginning)) {
                openPendingGroup(startFromSavedProgress: false)
            }
            Button(preferences.text(.cancel), role: .cancel) {
                resumePromptGroup = nil
            }
        } message: {
            Text(preferences.text(.resumeMessage))
        }
    }

    private func resolvedGroup(for group: MediaGroup) -> MediaGroup {
        var resolved = group
        resolved.isCompleted = isCompleted(group.id)
        return resolved
    }

    private func handleGroupTap(_ group: MediaGroup) {
        AppFeedback.selection()
        guard shouldAskToResume(for: group) else {
            selectedTarget = NavigationTarget(group: group, startIndex: 0)
            return
        }
        resumePromptGroup = group
    }

    private func shouldAskToResume(for group: MediaGroup) -> Bool {
        guard let progress = progressStore.progress(for: group.id) else { return false }
        return progress.viewed > 0 && !progress.isComplete
    }

    private func isCompleted(_ groupId: String) -> Bool {
        progressStore.completedGroupIds.contains(groupId) || (progressStore.progress(for: groupId)?.isComplete ?? false)
    }

    private func openPendingGroup(startFromSavedProgress: Bool) {
        guard let group = resumePromptGroup else { return }
        let startIndex: Int

        if startFromSavedProgress {
            AppFeedback.selection()
            startIndex = progressStore.progress(for: group.id)?.viewed ?? 0
        } else {
            AppFeedback.warning()
            progressStore.clearProgress(for: group.id)
            startIndex = 0
        }

        selectedTarget = NavigationTarget(group: resolvedGroup(for: group), startIndex: startIndex)
        resumePromptGroup = nil
    }

    private var resumePromptBinding: Binding<Bool> {
        Binding(
            get: { resumePromptGroup != nil },
            set: { isPresented in
                if !isPresented { resumePromptGroup = nil }
            }
        )
    }
}

private struct SmartGroupsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    private struct NavigationTarget: Identifiable, Hashable {
        let group: MediaGroup
        let startIndex: Int
        var id: String { "\(group.id)-\(startIndex)" }
    }

    let group: MediaGroup
    let includeVideos: Bool
    @ObservedObject var deleteQueue: DeleteQueueService
    @ObservedObject var progressStore: GroupProgressStore
    @State private var categories: [MediaGroup] = []
    @State private var selectedTarget: NavigationTarget?
    @State private var resumePromptGroup: MediaGroup?
    @State private var isLoading = true

    private let groupingService = MediaGroupingService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionIntro(preferences.text(.smartDescription), accent: AppPalette.accentPurple)

                if isLoading {
                    ProgressView(preferences.text(.loading))
                        .tint(.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, child in
                            let resolvedChild = resolvedGroup(for: child)
                            GroupRowView(
                                group: resolvedChild,
                                includeVideos: includeVideos,
                                progressViewed: progressStore.progress(for: resolvedChild.id)?.viewed ?? 0,
                                progressTotal: progressStore.progress(for: resolvedChild.id)?.total ?? 0,
                                rowIndex: index,
                                onTap: { handleGroupTap(resolvedChild) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            AppBackgroundView(variant: .elevated)
                .ignoresSafeArea()
        )
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedTarget) { target in
            GroupDetailView(
                group: target.group,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        }
        .alert(preferences.text(.resumeTitle), isPresented: resumePromptBinding) {
            Button(preferences.text(.continueFromWhereLeft)) {
                openPendingGroup(startFromSavedProgress: true)
            }
            Button(preferences.text(.restartFromBeginning)) {
                openPendingGroup(startFromSavedProgress: false)
            }
            Button(preferences.text(.cancel), role: .cancel) {
                resumePromptGroup = nil
            }
        } message: {
            Text(preferences.text(.resumeMessage))
        }
        .task(id: "\(includeVideos)-\(preferences.language.rawValue)") {
            await loadSmartCategories()
        }
    }

    private func resolvedGroup(for group: MediaGroup) -> MediaGroup {
        var resolved = group
        resolved.isCompleted = isCompleted(group.id)
        return resolved
    }

    private func loadSmartCategories() async {
        isLoading = true
        defer { isLoading = false }
        categories = await groupingService.fetchSmartCategories(
            includeVideos: includeVideos,
            completedGroupIds: progressStore.completedGroupIds,
            language: preferences.language
        )
    }

    private func handleGroupTap(_ group: MediaGroup) {
        AppFeedback.selection()
        guard shouldAskToResume(for: group) else {
            selectedTarget = NavigationTarget(group: group, startIndex: 0)
            return
        }
        resumePromptGroup = group
    }

    private func shouldAskToResume(for group: MediaGroup) -> Bool {
        guard let progress = progressStore.progress(for: group.id) else { return false }
        return progress.viewed > 0 && !progress.isComplete
    }

    private func isCompleted(_ groupId: String) -> Bool {
        progressStore.completedGroupIds.contains(groupId) || (progressStore.progress(for: groupId)?.isComplete ?? false)
    }

    private func openPendingGroup(startFromSavedProgress: Bool) {
        guard let group = resumePromptGroup else { return }
        let startIndex: Int

        if startFromSavedProgress {
            AppFeedback.selection()
            startIndex = progressStore.progress(for: group.id)?.viewed ?? 0
        } else {
            AppFeedback.warning()
            progressStore.clearProgress(for: group.id)
            startIndex = 0
        }

        selectedTarget = NavigationTarget(group: resolvedGroup(for: group), startIndex: startIndex)
        resumePromptGroup = nil
    }

    private var resumePromptBinding: Binding<Bool> {
        Binding(
            get: { resumePromptGroup != nil },
            set: { isPresented in
                if !isPresented { resumePromptGroup = nil }
            }
        )
    }
}

private struct SmartCategoryGroupsView: View {
    @EnvironmentObject private var preferences: AppPreferences
    private struct NavigationTarget: Identifiable, Hashable {
        let group: MediaGroup
        let startIndex: Int
        var id: String { "\(group.id)-\(startIndex)" }
    }

    let group: MediaGroup
    let includeVideos: Bool
    @ObservedObject var deleteQueue: DeleteQueueService
    @ObservedObject var progressStore: GroupProgressStore
    @State private var selectedTarget: NavigationTarget?
    @State private var resumePromptGroup: MediaGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionIntro(preferences.text(.similarDescription), accent: AppPalette.accentPink)

                VStack(spacing: 12) {
                    if let allSimilarGroup {
                        GroupRowView(
                            group: allSimilarGroup,
                            includeVideos: includeVideos,
                            progressViewed: progressStore.progress(for: allSimilarGroup.id)?.viewed ?? 0,
                            progressTotal: progressStore.progress(for: allSimilarGroup.id)?.total ?? 0,
                            rowIndex: 0,
                            onTap: { handleGroupTap(allSimilarGroup) }
                        )
                    }

                    ForEach(Array(group.childGroups.enumerated()), id: \.element.id) { index, child in
                        let resolvedChild = resolvedGroup(for: child)
                        GroupRowView(
                            group: resolvedChild,
                            includeVideos: includeVideos,
                            progressViewed: progressStore.progress(for: resolvedChild.id)?.viewed ?? 0,
                            progressTotal: progressStore.progress(for: resolvedChild.id)?.total ?? 0,
                            rowIndex: index + 1,
                            onTap: { handleGroupTap(resolvedChild) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            AppBackgroundView(variant: .elevated)
                .ignoresSafeArea()
        )
        .navigationTitle(group.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedTarget) { target in
            GroupDetailView(
                group: target.group,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        }
        .alert(preferences.text(.resumeTitle), isPresented: resumePromptBinding) {
            Button(preferences.text(.continueFromWhereLeft)) {
                openPendingGroup(startFromSavedProgress: true)
            }
            Button(preferences.text(.restartFromBeginning)) {
                openPendingGroup(startFromSavedProgress: false)
            }
            Button(preferences.text(.cancel), role: .cancel) {
                resumePromptGroup = nil
            }
        } message: {
            Text(preferences.text(.resumeMessage))
        }
    }

    private func resolvedGroup(for group: MediaGroup) -> MediaGroup {
        var resolved = group
        resolved.isCompleted = isCompleted(group.id)
        return resolved
    }

    private var allSimilarGroup: MediaGroup? {
        guard !group.assetIdentifiers.isEmpty else { return nil }
        let allCompleted = !group.childGroups.isEmpty && group.childGroups.allSatisfy {
            isCompleted($0.id)
        }

        return MediaGroup(
            id: "\(group.id)-all",
            title: preferences.text(.allSimilar),
            type: .smartCluster,
            assetIdentifiers: group.assetIdentifiers,
            isCompleted: allCompleted,
            photoCount: group.assetIdentifiers.count,
            videoCount: 0
        )
    }

    private func handleGroupTap(_ group: MediaGroup) {
        guard shouldAskToResume(for: group) else {
            selectedTarget = NavigationTarget(group: group, startIndex: 0)
            return
        }
        resumePromptGroup = group
    }

    private func shouldAskToResume(for group: MediaGroup) -> Bool {
        guard let progress = progressStore.progress(for: group.id) else { return false }
        return progress.viewed > 0 && !progress.isComplete
    }

    private func isCompleted(_ groupId: String) -> Bool {
        progressStore.completedGroupIds.contains(groupId) || (progressStore.progress(for: groupId)?.isComplete ?? false)
    }

    private func openPendingGroup(startFromSavedProgress: Bool) {
        guard let group = resumePromptGroup else { return }
        let startIndex: Int

        if startFromSavedProgress {
            startIndex = progressStore.progress(for: group.id)?.viewed ?? 0
        } else {
            progressStore.clearProgress(for: group.id)
            startIndex = 0
        }

        selectedTarget = NavigationTarget(group: resolvedGroup(for: group), startIndex: startIndex)
        resumePromptGroup = nil
    }

    private var resumePromptBinding: Binding<Bool> {
        Binding(
            get: { resumePromptGroup != nil },
            set: { isPresented in
                if !isPresented { resumePromptGroup = nil }
            }
        )
    }
}

private struct SettingsSheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss
    @Binding var includeVideos: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(variant: .elevated)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(preferences.text(.settingsDescription))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)

                        settingCard {
                            HStack(spacing: 14) {
                                iconBubble(systemName: "video.fill")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preferences.text(.includeVideos))
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(preferences.text(.includeVideosDescription))
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.68))
                                }
                                Spacer()
                                Toggle("", isOn: $includeVideos)
                                    .labelsHidden()
                                    .tint(AppPalette.accentPurple)
                                    .onChange(of: includeVideos) { _, _ in
                                        AppFeedback.selection()
                                    }
                            }
                        }

                        settingCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 14) {
                                    iconBubble(systemName: "globe")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preferences.text(.language))
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(preferences.text(.languageDescription))
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                }

                                Picker("", selection: $preferences.language) {
                                    ForEach(AppLanguage.allCases) { language in
                                        Text(language.displayName).tag(language)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .onChange(of: preferences.language) { _, _ in
                                    AppFeedback.selection()
                                }
                            }
                        }

                        settingCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 14) {
                                    iconBubble(systemName: "doc.text.magnifyingglass")
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(preferences.text(.legal))
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text(preferences.text(.legalDescription))
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.68))
                                    }
                                }

                                legalLink(
                                    title: preferences.text(.privacyPolicy),
                                    systemName: "hand.raised.fill",
                                    url: AppLegalLinks.privacyPolicy
                                )

                                legalLink(
                                    title: preferences.text(.termsOfUse),
                                    systemName: "doc.text.fill",
                                    url: AppLegalLinks.termsOfUse
                                )

                                legalLink(
                                    title: preferences.text(.support),
                                    systemName: "lifepreserver.fill",
                                    url: AppLegalLinks.support
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(preferences.text(.settings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text(.close)) { dismiss() }
                }
            }
        }
    }

    private func settingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .glassCard(accent: AppPalette.accentPurple, cornerRadius: 22, strokeOpacity: 0.16, shadowOpacity: 0.7)
    }

    private func iconBubble(systemName: String) -> some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: systemName)
                .foregroundStyle(AppPalette.textPrimary)
        }
    }

    private func legalLink(title: String, systemName: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 12) {
                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppPalette.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(AppPalette.accentPurple.opacity(0.14))
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.textSecondary)
            }
            .padding(.vertical, 4)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                AppFeedback.selection()
            }
        )
    }
}

private func sectionIntro(_ text: String, accent: Color) -> some View {
    Text(text)
        .font(.subheadline)
        .foregroundStyle(AppPalette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [AppPalette.cardBase.opacity(0.98), accent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(accent.opacity(0.14), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
}
