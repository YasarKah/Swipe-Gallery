import SwiftUI

struct GuidedCleanupView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let includeVideos: Bool
    @ObservedObject var progressStore: GroupProgressStore

    @State private var steps: [GuidedCleanupStep] = []
    @State private var isLoading = true

    private let guidedService = GuidedCleanupService()

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if steps.isEmpty {
                emptyStateView
            } else {
                GuidedCleanupStepListView(
                    title: preferences.text(.guidedCleanupTitle),
                    description: preferences.text(.guidedCleanupDescription),
                    steps: steps,
                    includeVideos: includeVideos,
                    progressStore: progressStore,
                    autoPopWhenEmpty: false
                )
            }
        }
        .background(screenBackground.ignoresSafeArea())
        .navigationTitle(preferences.text(.guidedCleanupTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: loadTaskKey) {
            await loadSteps()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView(preferences.text(.loading))
                .tint(.white)
            Text(preferences.text(.guidedCleanupDescription))
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var screenBackground: some View {
        AppBackgroundView(variant: .elevated)
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            preferences.text(.noMedia),
            systemImage: "checkmark.seal",
            description: Text(preferences.text(.guidedCleanupAllCaughtUp))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadTaskKey: String {
        let completed = progressStore.completedGroupIds.sorted().joined(separator: "|")
        let progress = progressStore.groupProgress
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value.viewed)-\($0.value.total)" }
            .joined(separator: "|")

        return "\(includeVideos)-\(preferences.language.rawValue)-\(completed)-\(progress)"
    }

    private func loadSteps() async {
        isLoading = true
        steps = await guidedService.fetchRootSteps(
            includeVideos: includeVideos,
            language: preferences.language,
            completedGroupIds: progressStore.completedGroupIds,
            progressByGroupId: progressStore.groupProgress
        )
        isLoading = false
    }
}

private struct GuidedCleanupStepListView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @Environment(\.dismiss) private var dismiss

    private struct LeafTarget: Identifiable, Hashable {
        let step: GuidedCleanupStep
        let startIndex: Int

        var id: String {
            "\(step.id)-\(startIndex)"
        }
    }

    let title: String
    let description: String
    let steps: [GuidedCleanupStep]
    let includeVideos: Bool
    @ObservedObject var progressStore: GroupProgressStore
    let autoPopWhenEmpty: Bool

    @State private var selectedStep: GuidedCleanupStep?
    @State private var selectedLeaf: LeafTarget?
    @State private var resumePromptStep: GuidedCleanupStep?
    @State private var didAutoPop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)

                if visibleSteps.isEmpty {
                    ContentUnavailableView(
                        preferences.text(.noMedia),
                        systemImage: "checkmark.seal",
                        description: Text(preferences.text(.guidedCleanupAllCaughtUp))
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 14) {
                        ForEach(visibleSteps) { step in
                            let progress = progressSummary(for: step)
                            GuidedCleanupCardView(
                                step: step,
                                includeVideos: includeVideos,
                                progressViewed: progress.viewed,
                                progressTotal: progress.total,
                                isCompleted: isCompleted(step)
                            ) {
                                handleTap(step)
                            }
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
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedStep) { step in
            GuidedCleanupStepListView(
                title: step.title,
                description: step.detail,
                steps: step.childSteps,
                includeVideos: includeVideos,
                progressStore: progressStore,
                autoPopWhenEmpty: true
            )
        }
        .navigationDestination(item: $selectedLeaf) { target in
            GuidedCleanupSessionView(
                step: target.step,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                progressStore: progressStore,
                onCompleted: {
                    openNextLeaf(after: target.step)
                }
            )
        }
        .alert(AppText.value(for: .resumeTitle, language: currentLanguage), isPresented: resumePromptBinding) {
            Button(AppText.value(for: .continueFromWhereLeft, language: currentLanguage)) {
                openPendingStep(startFromSavedProgress: true)
            }
            Button(AppText.value(for: .restartFromBeginning, language: currentLanguage)) {
                openPendingStep(startFromSavedProgress: false)
            }
            Button(AppText.value(for: .cancel, language: currentLanguage), role: .cancel) {
                resumePromptStep = nil
            }
        } message: {
            Text(AppText.value(for: .resumeMessage, language: currentLanguage))
        }
        .onAppear {
            didAutoPop = false
            triggerAutoPopIfNeeded()
        }
        .onChange(of: visibleSteps.count) { _, _ in
            triggerAutoPopIfNeeded()
        }
    }

    private var currentLanguage: AppLanguage {
        preferences.language
    }

    private var visibleSteps: [GuidedCleanupStep] {
        steps.compactMap(filteredStep)
    }

    private func handleTap(_ step: GuidedCleanupStep) {
        guard step.isLeaf else {
            AppFeedback.selection()
            selectedStep = step
            return
        }

        guard shouldAskToResume(for: step) else {
            AppFeedback.selection()
            selectedLeaf = LeafTarget(step: step, startIndex: 0)
            return
        }

        AppFeedback.selection()
        resumePromptStep = step
    }

    private func openNextLeaf(after completedStep: GuidedCleanupStep) {
        guard let currentIndex = visibleSteps.firstIndex(where: { $0.id == completedStep.id }) else {
            selectedLeaf = nil
            return
        }

        selectedLeaf = nil

        guard let nextLeaf = visibleSteps
            .dropFirst(currentIndex + 1)
            .first(where: \.isLeaf) else {
            AppFeedback.success()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AppFeedback.selection()
            selectedLeaf = LeafTarget(step: nextLeaf, startIndex: 0)
        }
    }

    private func triggerAutoPopIfNeeded() {
        guard autoPopWhenEmpty, visibleSteps.isEmpty, !didAutoPop else { return }
        didAutoPop = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AppFeedback.success()
            dismiss()
        }
    }

    private func shouldAskToResume(for step: GuidedCleanupStep) -> Bool {
        guard let progress = progressStore.progress(for: step.id) else { return false }
        return progress.viewed > 0 && !progress.isComplete
    }

    private func openPendingStep(startFromSavedProgress: Bool) {
        guard let step = resumePromptStep else { return }
        let startIndex: Int

        if startFromSavedProgress {
            AppFeedback.selection()
            startIndex = progressStore.progress(for: step.id)?.viewed ?? 0
        } else {
            AppFeedback.warning()
            progressStore.clearProgress(for: step.id)
            startIndex = 0
        }

        selectedLeaf = LeafTarget(step: step, startIndex: startIndex)
        resumePromptStep = nil
    }

    private func progressSummary(for step: GuidedCleanupStep) -> (viewed: Int, total: Int) {
        if step.isLeaf {
            let stored = progressStore.progress(for: step.id)
            return (stored?.viewed ?? 0, stored?.total ?? step.totalCount)
        }

        return step.childSteps.reduce(into: (viewed: 0, total: 0)) { partial, child in
            let progress = progressSummary(for: child)
            partial.viewed += progress.viewed
            partial.total += progress.total
        }
    }

    private func isCompleted(_ step: GuidedCleanupStep) -> Bool {
        if step.isLeaf {
            return isCompleted(step.id)
        }

        return !step.childSteps.isEmpty && step.childSteps.allSatisfy(isCompleted)
    }

    private func filteredStep(_ step: GuidedCleanupStep) -> GuidedCleanupStep? {
        if step.isLeaf {
            if isCompleted(step.id) {
                return nil
            }

            if let progress = progressStore.progress(for: step.id), progress.isComplete {
                return nil
            }

            return step
        }

        let filteredChildren = step.childSteps.compactMap(filteredStep)
        guard !filteredChildren.isEmpty else { return nil }

        let counts = filteredChildren.reduce(into: (photos: 0, videos: 0)) { partial, child in
            partial.photos += child.photoCount
            partial.videos += child.videoCount
        }

        return GuidedCleanupStep(
            id: step.id,
            title: step.title,
            subtitle: step.subtitle,
            detail: step.detail,
            kind: step.kind,
            style: step.style,
            dateRange: step.dateRange,
            photoCount: counts.photos,
            videoCount: counts.videos,
            childSteps: filteredChildren
        )
    }

    private var resumePromptBinding: Binding<Bool> {
        Binding(
            get: { resumePromptStep != nil },
            set: { isPresented in
                if !isPresented {
                    resumePromptStep = nil
                }
            }
        )
    }

    private func isCompleted(_ groupId: String) -> Bool {
        progressStore.completedGroupIds.contains(groupId) || (progressStore.progress(for: groupId)?.isComplete ?? false)
    }
}

private struct GuidedCleanupCardView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let step: GuidedCleanupStep
    let includeVideos: Bool
    let progressViewed: Int
    let progressTotal: Int
    let isCompleted: Bool
    let action: () -> Void

    private var progressFraction: Double {
        guard progressTotal > 0 else { return 0 }
        return min(1, Double(progressViewed) / Double(progressTotal))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    iconBubble

                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(isCompleted ? AppPalette.textSecondary : AppPalette.textPrimary)

                        Text(step.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isCompleted ? AppPalette.textMuted : AppPalette.textSecondary)

                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(isCompleted ? AppPalette.textMuted.opacity(0.8) : AppPalette.textMuted)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 12)

                    if isCompleted {
                        completedBadge
                    }

                    Image(systemName: isCompleted ? "checkmark" : "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isCompleted ? accentColor.opacity(0.96) : AppPalette.textSecondary)
                }

                HStack(spacing: 8) {
                    badge(text: "📷 \(step.photoCount)")
                    if includeVideos && step.videoCount > 0 {
                        badge(text: "🎬 \(step.videoCount)")
                    }
                    if !step.isLeaf {
                        badge(text: childCountText)
                    }
                }

                if progressTotal > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(progressViewed)/\(progressTotal)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.textPrimary)
                            Spacer()
                            Text("%\(Int(progressFraction * 100))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppPalette.textSecondary)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppPalette.glassBorder.opacity(0.48))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [accentColor.opacity(0.96), AppPalette.neonBlueGlow.opacity(0.78)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(10, proxy.size.width * progressFraction))
                                    .shadow(color: accentColor.opacity(0.24), radius: 10, y: 0)
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(accent: accentColor, cornerRadius: 26, strokeOpacity: 0.18)
            .overlay {
                if isCompleted {
                    completionOverlay
                }
            }
            .saturation(isCompleted ? 0.72 : 1)
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        switch step.style {
        case .hero:
            return AppPalette.accentPurple
        case .highlight:
            return AppPalette.accentBlue
        case .neutral:
            return Color(red: 0.34, green: 0.50, blue: 0.96)
        case .archive:
            return Color(red: 0.40, green: 0.46, blue: 0.84)
        }
    }

    private var iconBubble: some View {
        Image(systemName: iconName)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppPalette.textPrimary)
            .frame(width: 48, height: 48)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(accentColor.opacity(0.18))
                    }
            }
            .overlay {
                Circle()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
            }
            .clipShape(Circle())
            .shadow(color: accentColor.opacity(0.14), radius: 12, y: 6)
    }

    private var iconName: String {
        switch step.kind {
        case .recentMonths:
            return "sparkles"
        case .currentYearRemainder:
            return "calendar.badge.clock"
        case .lastYear:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .olderYears:
            return "archivebox.fill"
        case .year:
            return "calendar"
        case .month:
            return "photo.stack"
        }
    }

    private func badge(text: String) -> some View {
        AccentBadge(text: text, accent: accentColor)
    }

    private var completedBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(accentColor.opacity(0.16))
                }

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accentColor)
        }
        .frame(width: 34, height: 34)
        .overlay {
            Circle()
                .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: accentColor.opacity(0.18), radius: 12, y: 4)
    }

    private var childCountText: String {
        let label = AppText.value(for: .guidedStepCountFormat, language: currentLanguage)
        return String(format: label, locale: Locale(identifier: currentLanguage.localeIdentifier), step.childSteps.count)
    }

    private var currentLanguage: AppLanguage {
        preferences.language
    }

    private var completionOverlay: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(accentColor.opacity(0.34), lineWidth: 1.3)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.03))
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 92, height: 92)
                    .blur(radius: 24)
                    .offset(x: 14, y: -18)
            }
    }
}

private struct GuidedCleanupSessionView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let step: GuidedCleanupStep
    let includeVideos: Bool
    let initialIndex: Int
    @ObservedObject var progressStore: GroupProgressStore
    var onCompleted: (() -> Void)? = nil
    @StateObject private var deleteQueue = DeleteQueueService()

    var body: some View {
        if let group = step.makeMediaGroup() {
            GroupDetailView(
                group: group,
                includeVideos: includeVideos,
                initialIndex: initialIndex,
                onCompleted: onCompleted,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        } else {
            ContentUnavailableView(preferences.text(.featureUnavailable), systemImage: "exclamationmark.triangle")
        }
    }
}
