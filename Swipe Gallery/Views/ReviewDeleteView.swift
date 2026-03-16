//
//  ReviewDeleteView.swift
//  Swipe Gallery
//
//  Grup bitince açılır: silinecek fotoğraflar grid, tek tek geri al veya toplu sil (PhotoKit performChanges).
//

import SwiftUI
import Photos

struct ReviewDeleteView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var deleteQueue: DeleteQueueService
    let groupTitle: String
    let totalInGroup: Int
    let photoCount: Int
    let videoCount: Int
    let viewedCount: Int
    let onDismiss: () -> Void

    @State private var isDeleting = false
    @State private var errorMessage: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var viewedPercent: Int {
        guard totalInGroup > 0 else { return 0 }
        return min(100, Int((Double(viewedCount) / Double(totalInGroup)) * 100))
    }

    var body: some View {
        NavigationStack {
            Group {
                if deleteQueue.items.isEmpty {
                    emptyStateView
                } else {
                    gridAndActionsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(screenBackground.ignoresSafeArea())
            .navigationTitle(preferences.text(.finalReview))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text(.close)) {
                        AppFeedback.selection()
                        onDismiss()
                    }
                }
            }
            .alert(preferences.text(.error), isPresented: .constant(errorMessage != nil)) {
                Button(preferences.text(.ok)) { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView(
            preferences.text(.noItemsToDelete),
            systemImage: "checkmark.circle",
            description: Text(preferences.text(.noItemsToDeleteDescription))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDismiss() }
        }
    }

    private var gridAndActionsView: some View {
        VStack(spacing: 0) {
            Text(preferences.format(.deletingCountFormat, deleteQueue.items.count))
                .font(.subheadline)
                .foregroundStyle(AppPalette.textSecondary)
                .padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(deleteQueue.items) { item in
                        ReviewDeleteRowView(
                            item: item,
                            onRemove: { deleteQueue.remove(item) }
                        )
                    }
                }
                .padding()
            }

            VStack(spacing: 14) {
                statsSection
                bottomActions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var statsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                statBadge(text: "📷 \(photoCount)")
                if videoCount > 0 {
                    statBadge(text: "🎬 \(videoCount)")
                }
            }
            HStack(spacing: 16) {
                Text(preferences.format(.deletedCountFormat, deleteQueue.items.count))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
                Text(preferences.format(.viewedPercentFormat, viewedPercent))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(accent: AppPalette.accentBlue, cornerRadius: 22, strokeOpacity: 0.16, shadowOpacity: 0.7)
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if isDeleting {
                ProgressView(preferences.text(.deleting))
                    .tint(AppPalette.textPrimary)
            } else {
                GlassActionButton(
                    title: preferences.format(.deleteAllFormat, deleteQueue.items.count),
                    systemImage: "trash.fill",
                    accent: AppPalette.danger,
                    isEnabled: !deleteQueue.items.isEmpty
                ) {
                    Task { await confirmAndDelete() }
                }
            }
        }
        .padding(14)
        .glassCard(accent: AppPalette.danger, cornerRadius: 22, strokeOpacity: 0.16, shadowOpacity: 0.7)
    }

    private func confirmAndDelete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await deleteQueue.deleteAll()
            AppFeedback.success()
            onDismiss()
        } catch {
            AppFeedback.error()
            errorMessage = preferences.format(.deleteFailedFormat, error.localizedDescription)
        }
    }

    private func statBadge(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12))
            .clipShape(Capsule())
    }

    private var screenBackground: some View {
        AppBackgroundView(variant: .elevated)
    }
}

// MARK: - Grid hücresi: küçük önizleme + sade geri alma butonu

private struct ReviewDeleteRowView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let item: MediaItem
    let onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            thumbnailView
            GlassIconButton(systemImage: "arrow.uturn.backward", accent: AppPalette.accentPurple, size: 36) {
                AppFeedback.selection()
                onRemove()
            }
            .accessibilityLabel(preferences.text(.remove))
        }
    }

    private var thumbnailView: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(AppPalette.surface)
            }
        }
        .frame(height: 100)
        .clipped()
        .glassCard(accent: AppPalette.accentPurple, cornerRadius: 12, strokeOpacity: 0.14, shadowOpacity: 0.5)
        .onAppear { loadThumbnail() }
    }

    private func loadThumbnail() {
        let size = CGSize(width: 200, height: 200)
        ImageLoaderService.loadImage(
            for: item.phAsset,
            targetSize: size,
            contentMode: .aspectFill,
            deliveryMode: .fastFormat
        ) { img in
            image = img
        }
    }
}

struct ReviewDeleteView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewDeleteView(
            deleteQueue: DeleteQueueService(),
            groupTitle: "OCA '25",
            totalInGroup: 84,
            photoCount: 70,
            videoCount: 14,
            viewedCount: 84,
            onDismiss: {}
        )
        .environmentObject(AppPreferences())
        .previewDisplayName("Son kontrol")
    }
}
