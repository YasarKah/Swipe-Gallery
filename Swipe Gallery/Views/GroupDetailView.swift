//
//  GroupDetailView.swift
//  Swipe Gallery
//
//  Seçilen gruba ait medya listesi; tek tek SwipeCardView ile gösterilir. Sayaç ve bitişte ReviewDeleteView.
//

import SwiftUI
import Photos
import CoreLocation

private let detailCardExitAnimationDuration: TimeInterval = 0.18

struct GroupDetailView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let group: MediaGroup
    let includeVideos: Bool
    let initialIndex: Int
    var onCompleted: (() -> Void)? = nil
    @ObservedObject var deleteQueue: DeleteQueueService
    @ObservedObject var progressStore: GroupProgressStore
    @Environment(\.dismiss) private var dismiss

    @State private var media: [MediaItem] = []
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var nextImage: UIImage?
    @State private var nextImageItemId: String?
    @State private var currentImageReady = false
    @State private var isLoading = true
    @State private var showReviewDelete = false
    @State private var showBackAlert = false
    @State private var showInfoSheet = false
    @State private var lastDecision: SwipeDecision?
    @State private var lastDeletedItem: MediaItem?

    private let groupingService = MediaGroupingService()

    private var progressPercent: Int {
        guard !media.isEmpty else { return 0 }
        return min(100, Int((Double(currentIndex) / Double(media.count)) * 100))
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if media.isEmpty {
                emptyView
            } else if currentIndex >= media.count {
                reviewRedirectView
            } else {
                GeometryReader { proxy in
                    let cardHeight = mediaStageHeight(for: proxy.size.height)

                    VStack(spacing: 0) {
                        Spacer(minLength: 6)

                        swipeCardStackWithNext(cardHeight: cardHeight)
                            .frame(maxWidth: .infinity)
                            .frame(height: cardHeight, alignment: .center)

                        Spacer(minLength: 16)

                        statusPanel
                            .padding(.horizontal, 24)

                        Spacer(minLength: 12)

                        actionBar
                            .padding(.horizontal, 24)
                            .padding(.bottom, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(screenBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    AppFeedback.warning()
                    showBackAlert = true
                } label: {
                    toolbarCircle(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(group.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.textPrimary)
                    if !media.isEmpty {
                        Text("\(currentIndex + 1)/\(media.count) - %\(progressPercent)")
                            .font(.caption)
                            .foregroundStyle(AppPalette.textSecondary)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    AppFeedback.selection()
                    showInfoSheet = true
                } label: {
                    toolbarCircle(systemName: "info.circle")
                }
            }
        }
        .task { await loadMedia() }
        .onDisappear { saveProgress() }
        .fullScreenCover(isPresented: $showReviewDelete) {
            ReviewDeleteView(
                deleteQueue: deleteQueue,
                groupTitle: group.title,
                totalInGroup: media.count,
                photoCount: group.photoCount,
                videoCount: group.videoCount,
                viewedCount: currentIndex,
                onDismiss: {
                    progressStore.markCompleted(group.id)
                    progressStore.setProgress(groupId: group.id, viewed: media.count, total: media.count)
                    AppFeedback.success()
                    showReviewDelete = false
                    onCompleted?()
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showInfoSheet) {
            if currentIndex < media.count {
                MediaInfoSheet(item: media[currentIndex])
                    .environmentObject(preferences)
            }
        }
        .alert(preferences.text(.exitPromptTitle), isPresented: $showBackAlert) {
            Button(preferences.text(.saveAndExit)) {
                AppFeedback.selection()
                saveProgress()
                dismiss()
            }
            Button(preferences.text(.exitWithoutSaving)) {
                AppFeedback.warning()
                deleteQueue.clear()
                dismiss()
            }
            Button(preferences.text(.deleteNow)) {
                AppFeedback.warning()
                Task {
                    try? await deleteQueue.deleteAll()
                    await MainActor.run {
                        AppFeedback.success()
                        saveProgress()
                        dismiss()
                    }
                }
            }
            Button(preferences.text(.cancel), role: .cancel) { }
        } message: {
            Text(preferences.text(.exitPromptMessage))
        }
    }

    private func undoLastDecision() {
        guard currentIndex > 0 else { return }
        if lastDecision == .delete, let item = lastDeletedItem {
            deleteQueue.remove(item)
        }
        AppFeedback.selection()
        currentIndex -= 1
        cardOffset = .zero
        currentImageReady = false
        lastDecision = nil
        lastDeletedItem = nil
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
            Text(preferences.text(.loading))
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            preferences.text(.noMedia),
            systemImage: "photo.on.rectangle.angled",
            description: Text(preferences.text(.noMediaDescription))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewRedirectView: some View {
        Color.clear
            .onAppear { showReviewDelete = true }
    }

    private var nextCardOpacity: Double {
        let width = UIScreen.main.bounds.width
        return min(0.92, abs(cardOffset.width) / (width * 0.38))
    }

    private func swipeCardStackWithNext(cardHeight: CGFloat) -> some View {
        let currentItem = media[safe: currentIndex]
        return ZStack {
            if let nextItem = media[safe: currentIndex + 1] {
                NextCardPlaceholderView(
                    item: nextItem,
                    cardHeight: cardHeight,
                    onImageLoaded: { img in
                        nextImage = img
                        nextImageItemId = nextItem.id
                    }
                )
                .id(nextItem.id)
                .opacity(nextCardOpacity)
            }
            if let currentItem {
                let initialImage = (nextImageItemId == currentItem.id ? nextImage : nil)
                SwipeCardView(
                    item: currentItem,
                    index: currentIndex,
                    total: media.count,
                    initialImage: initialImage,
                    cardHeight: cardHeight,
                    onDecision: { applyDecision($0) },
                    cardOffset: $cardOffset,
                    isImageReady: $currentImageReady
                )
                .id(currentItem.id)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            GlassActionButton(
                title: preferences.text(.delete),
                systemImage: "xmark",
                accent: AppPalette.danger,
                isEnabled: currentImageReady,
                action: { triggerDecision(.delete) }
            )
            GlassIconButton(
                systemImage: "arrow.uturn.backward",
                accent: AppPalette.accentPurple,
                size: 50,
                action: { undoLastDecision() }
            )
            .opacity(currentIndex > 0 ? 1 : 0.55)
            .disabled(currentIndex == 0)

            GlassActionButton(
                title: preferences.text(.keep),
                systemImage: "checkmark",
                accent: AppPalette.accentBlue,
                isEnabled: currentImageReady,
                action: { triggerDecision(.keep) }
            )
        }
        .padding(.horizontal, 6)
        .frame(height: 62)
    }

    private func loadMedia() async {
        isLoading = true

        let fetchedMedia = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let items = groupingService.fetchMedia(for: group, includeVideos: includeVideos)
                continuation.resume(returning: items)
            }
        }

        media = fetchedMedia
        cardOffset = .zero
        nextImage = nil
        nextImageItemId = nil
        currentImageReady = false

        let safeInitialIndex = min(max(initialIndex, 0), max(media.count - 1, 0))
        currentIndex = media.isEmpty ? 0 : safeInitialIndex

        guard let currentItem = media[safe: currentIndex] else {
            isLoading = false
            return
        }

        preloadImage(for: currentItem) { image in
            nextImage = image
            nextImageItemId = currentItem.id
            currentImageReady = image != nil
            isLoading = false
        }
    }

    private func applyDecision(_ decision: SwipeDecision) {
        guard let item = media[safe: currentIndex] else { return }
        lastDecision = decision
        lastDeletedItem = decision == .delete ? item : nil
        if decision == .delete {
            deleteQueue.add(item)
        }
        let nextIndex = currentIndex + 1
        let total = media.count
        let nextItem = media[safe: nextIndex]
        currentIndex = nextIndex
        cardOffset = .zero
        currentImageReady = nextItem != nil && nextImageItemId == nextItem?.id && nextImage != nil
        DispatchQueue.main.async { [progressStore, group] in
            progressStore.setProgress(groupId: group.id, viewed: nextIndex, total: total)
        }
        if nextIndex >= media.count {
            currentImageReady = false
            showReviewDelete = true
        }
    }

    private func triggerDecision(_ decision: SwipeDecision) {
        guard currentImageReady else { return }
        AppFeedback.commit(style: .rigid)
        withAnimation(.easeOut(duration: detailCardExitAnimationDuration)) {
            cardOffset = CGSize(width: decision == .delete ? -400 : 400, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + detailCardExitAnimationDuration) {
            applyDecision(decision)
        }
    }

    private func saveProgress() {
        progressStore.setProgress(groupId: group.id, viewed: currentIndex, total: media.count)
    }

    private func preloadImage(for item: MediaItem, completion: @escaping (UIImage?) -> Void) {
        ImageLoaderService.loadImage(
            for: item.phAsset,
            targetSize: CGSize(width: 1400, height: 1400),
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat,
            completion: completion
        )
    }

    private var screenBackground: some View {
        ZStack {
            AppBackgroundView(variant: .elevated)

            RadialGradient(
                colors: [AppPalette.neonBlueGlow.opacity(progressBackgroundOpacity), .clear],
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .blur(radius: 16)
        }
        .animation(.easeInOut(duration: 0.3), value: progressPercent)
    }

    private var progressBackgroundOpacity: Double {
        min(0.32, Double(progressPercent) / 100 * 0.32)
    }

    private func mediaStageHeight(for totalHeight: CGFloat) -> CGFloat {
        let reservedHeight: CGFloat = 110
        let availableHeight = max(280, totalHeight - reservedHeight)
        return min(availableHeight, totalHeight * 0.76)
    }

    private func finishGroup(deleteQueue shouldDelete: Bool) {
        if shouldDelete {
            Task {
                try? await deleteQueue.deleteAll()
                await MainActor.run {
                    progressStore.markCompleted(group.id)
                    saveProgress()
                    dismiss()
                }
            }
        } else {
            deleteQueue.clear()
            progressStore.markCompleted(group.id)
            saveProgress()
            dismiss()
        }
    }

    private var statusPanel: some View {
        HStack(spacing: 10) {
            AccentBadge(text: "📷 \(group.photoCount)", accent: AppPalette.accentBlue)
            if includeVideos && group.videoCount > 0 {
                AccentBadge(text: "🎬 \(group.videoCount)", accent: AppPalette.accentPurple)
            }
            AccentBadge(text: "🗑️ \(deleteQueue.items.count)", accent: AppPalette.danger)
            Spacer(minLength: 8)
            AccentBadge(text: "%\(progressPercent)", accent: AppPalette.accentPink, prominent: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard(accent: AppPalette.accentBlue, cornerRadius: 22, strokeOpacity: 0.16, shadowOpacity: 0.8)
    }

    private func toolbarCircle(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(AppPalette.textPrimary)
            .frame(width: 34, height: 34)
            .background {
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Circle()
                            .fill(AppPalette.glassSurface)
                    }
            }
            .overlay {
                Circle()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
            }
    }
}

// MARK: - Arkada görünen sonraki kart (opacity ile) — ön kartla aynı oran

private struct NextCardPlaceholderView: View {
    let item: MediaItem
    var cardHeight: CGFloat
    var onImageLoaded: ((UIImage?) -> Void)?
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = CGSize(
                width: max(proxy.size.width - 24, 0),
                height: max(proxy.size.height - 24, 0)
            )
            let mediaSize = item.fittedSize(in: canvasSize)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.glassSurfaceStrong,
                                AppPalette.glassSurface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.03))
                    .frame(width: mediaSize.width, height: mediaSize.height)

                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: mediaSize.width, height: mediaSize.height)
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: cardHeight)
        .glassCard(accent: AppPalette.accentBlue, cornerRadius: 30, strokeOpacity: 0.18, shadowOpacity: 0.8)
        .onAppear { loadImage() }
    }

    private func loadImage() {
        ImageLoaderService.loadImage(
            for: item.phAsset,
            targetSize: CGSize(width: 800, height: 800),
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat
        ) { img in
            image = img
            onImageLoaded?(img)
        }
    }
}

struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GroupDetailView(
                group: MediaGroup(id: "1", title: "OCA '25", type: .month(year: 2025, month: 1), photoCount: 50, videoCount: 2),
                includeVideos: false,
                initialIndex: 0,
                deleteQueue: DeleteQueueService(),
                progressStore: GroupProgressStore()
            )
            .environmentObject(AppPreferences())
        }
        .previewDisplayName("Grup detay")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct MediaInfoSheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss
    @State private var metadata = MediaTechnicalInfo.loading(for: .turkish)

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(variant: .elevated)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(preferences.text(.photoInfoDescription))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.textSecondary)

                        infoCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle(preferences.text(.info))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text(.close)) {
                        AppFeedback.selection()
                        dismiss()
                    }
                }
            }
        }
        .task {
            metadata = MediaTechnicalInfo.loading(for: preferences.language)
            metadata = await MediaTechnicalInfo.load(for: item, language: preferences.language)
        }
    }

    private var infoCard: some View {
        VStack(spacing: 0) {
            ForEach(metadata.rows.indices, id: \.self) { index in
                let row = metadata.rows[index]
                HStack(alignment: .top, spacing: 12) {
                    Text(row.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 110, alignment: .leading)

                    Spacer(minLength: 8)

                    Text(row.value)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if index < metadata.rows.count - 1 {
                    Divider()
                        .overlay(.white.opacity(0.08))
                        .padding(.horizontal, 16)
                }
            }
        }
        .glassCard(accent: AppPalette.accentPurple, cornerRadius: 22, strokeOpacity: 0.16, shadowOpacity: 0.7)
    }
}

private struct MediaTechnicalInfo {
    struct Row {
        let title: String
        let value: String
    }

    let rows: [Row]

    static func loading(for language: AppLanguage) -> MediaTechnicalInfo {
        MediaTechnicalInfo(rows: [
            Row(title: AppText.value(for: .status, language: language), value: AppText.value(for: .loading, language: language))
        ])
    }

    static func load(for item: MediaItem, language: AppLanguage) async -> MediaTechnicalInfo {
        let asset = item.phAsset
        let resources = PHAssetResource.assetResources(for: asset)
        let primaryResource = resources.first

        let sizeText = await fileSizeText(for: primaryResource, language: language)
        let fileName = primaryResource?.originalFilename ?? AppText.value(for: .unknown, language: language)
        let fileExtension = fileName.split(separator: ".").last.map(String.init)?.uppercased() ?? AppText.value(for: .unknown, language: language)
        let dimensions = "\(asset.pixelWidth) x \(asset.pixelHeight)"
        let typeText = item.isVideo ? "Video" : (item.isLivePhoto ? AppText.value(for: .livePhotoType, language: language) : AppText.value(for: .photo, language: language))
        let durationText = item.isVideo ? String(format: language == .turkish ? "%.1f sn" : "%.1f sec", asset.duration) : "-"
        let dateText = item.creationDate.map { DateFormatter.mediaInfo(language: language).string(from: $0) } ?? AppText.value(for: .unknown, language: language)
        let locationText = locationText(for: asset.location, language: language)

        return MediaTechnicalInfo(rows: [
            Row(title: AppText.value(for: .type, language: language), value: typeText),
            Row(title: AppText.value(for: .size, language: language), value: sizeText),
            Row(title: AppText.value(for: .fileExtension, language: language), value: fileExtension),
            Row(title: AppText.value(for: .file, language: language), value: fileName),
            Row(title: AppText.value(for: .resolution, language: language), value: dimensions),
            Row(title: AppText.value(for: .duration, language: language), value: durationText),
            Row(title: AppText.value(for: .date, language: language), value: dateText),
            Row(title: AppText.value(for: .location, language: language), value: locationText),
        ])
    }

    private static func locationText(for location: CLLocation?, language: AppLanguage) -> String {
        guard let location else { return AppText.value(for: .unknown, language: language) }
        return String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private static func fileSizeText(for resource: PHAssetResource?, language: AppLanguage) async -> String {
        guard let resource else { return AppText.value(for: .unknown, language: language) }

        let sizeInBytes = await withCheckedContinuation { continuation in
            var totalBytes = 0
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options
            ) { chunk in
                totalBytes += chunk.count
            } completionHandler: { error in
                guard error == nil else {
                    continuation.resume(returning: -1)
                    return
                }
                continuation.resume(returning: totalBytes)
            }
        }

        guard sizeInBytes >= 0 else { return AppText.value(for: .unknown, language: language) }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        return formatter.string(fromByteCount: Int64(sizeInBytes))
    }
}

private extension DateFormatter {
    static func mediaInfo(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}
