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
            } else {
                GuidedCleanupStepListView(
                    title: preferences.text(.guidedCleanupTitle),
                    description: preferences.text(.guidedCleanupDescription),
                    steps: steps,
                    includeVideos: includeVideos,
                    progressStore: progressStore
                )
            }
        }
        .background(screenBackground.ignoresSafeArea())
        .navigationTitle(preferences.text(.guidedCleanupTitle))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(includeVideos)-\(preferences.language.rawValue)") {
            await loadSteps()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView(preferences.text(.loading))
                .tint(.white)
            Text(preferences.text(.guidedCleanupDescription))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func loadSteps() async {
        isLoading = true
        steps = await guidedService.fetchRootSteps(includeVideos: includeVideos, language: preferences.language)
        isLoading = false
    }
}

private struct GuidedCleanupStepListView: View {
    @EnvironmentObject private var preferences: AppPreferences

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

    @State private var selectedStep: GuidedCleanupStep?
    @State private var selectedLeaf: LeafTarget?
    @State private var resumePromptStep: GuidedCleanupStep?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                VStack(spacing: 14) {
                    ForEach(steps) { step in
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
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(
            LinearGradient(
                colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                progressStore: progressStore
            )
        }
        .navigationDestination(item: $selectedLeaf) { target in
            GuidedCleanupSessionView(
                step: target.step,
                includeVideos: includeVideos,
                initialIndex: target.startIndex,
                progressStore: progressStore
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
    }

    private var currentLanguage: AppLanguage {
        preferences.language
    }

    private func handleTap(_ step: GuidedCleanupStep) {
        guard step.isLeaf else {
            selectedStep = step
            return
        }

        guard shouldAskToResume(for: step) else {
            selectedLeaf = LeafTarget(step: step, startIndex: 0)
            return
        }

        resumePromptStep = step
    }

    private func shouldAskToResume(for step: GuidedCleanupStep) -> Bool {
        guard let progress = progressStore.progress(for: step.id) else { return false }
        return progress.viewed > 0 && progress.viewed < progress.total
    }

    private func openPendingStep(startFromSavedProgress: Bool) {
        guard let step = resumePromptStep else { return }
        let startIndex: Int

        if startFromSavedProgress {
            startIndex = progressStore.progress(for: step.id)?.viewed ?? 0
        } else {
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
            return progressStore.completedGroupIds.contains(step.id)
        }

        return !step.childSteps.isEmpty && step.childSteps.allSatisfy(isCompleted)
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
}

private struct GuidedCleanupCardView: View {
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
                            .foregroundStyle(.white)
                            .strikethrough(isCompleted, color: .white.opacity(0.75))

                        Text(step.subtitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))

                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(3)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
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
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("%\(Int(progressFraction * 100))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.16))
                                Capsule()
                                    .fill(.white.opacity(0.92))
                                    .frame(width: max(10, proxy.size.width * progressFraction))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundGradient)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientColors: [Color] {
        switch step.style {
        case .hero:
            return [AppPalette.accentPurple, AppPalette.accentPink]
        case .highlight:
            return [AppPalette.accentBlue, Color(red: 0.29, green: 0.45, blue: 0.97)]
        case .neutral:
            return [Color(red: 0.23, green: 0.36, blue: 0.82), Color(red: 0.34, green: 0.42, blue: 0.90)]
        case .archive:
            return [Color(red: 0.22, green: 0.29, blue: 0.58), Color(red: 0.19, green: 0.24, blue: 0.48)]
        }
    }

    private var iconBubble: some View {
        Image(systemName: iconName)
            .font(.title3.weight(.bold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.16))
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            }
            .clipShape(Circle())
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
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private var childCountText: String {
        let label = AppText.value(for: .guidedStepCountFormat, language: currentLanguage)
        return String(format: label, locale: Locale(identifier: currentLanguage.localeIdentifier), step.childSteps.count)
    }

    private var currentLanguage: AppLanguage {
        preferences.language
    }
}

private struct GuidedCleanupSessionView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let step: GuidedCleanupStep
    let includeVideos: Bool
    let initialIndex: Int
    @ObservedObject var progressStore: GroupProgressStore
    @StateObject private var deleteQueue = DeleteQueueService()

    var body: some View {
        if let group = step.makeMediaGroup() {
            GroupDetailView(
                group: group,
                includeVideos: includeVideos,
                initialIndex: initialIndex,
                deleteQueue: deleteQueue,
                progressStore: progressStore
            )
        } else {
            ContentUnavailableView(preferences.text(.featureUnavailable), systemImage: "exclamationmark.triangle")
        }
    }
}
