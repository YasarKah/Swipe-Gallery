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
    @State private var deletedSuccessfully = false

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
                    Button(preferences.text(.close)) { onDismiss() }
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
                .foregroundStyle(.white.opacity(0.72))
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

            statsSection
            bottomActions
        }
    }

    private var statsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                statBadge(text: "📷 \(photoCount)")
                statBadge(text: "🎬 \(videoCount)")
            }
            HStack(spacing: 16) {
                Text(preferences.format(.deletedCountFormat, deleteQueue.items.count))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                Text(preferences.format(.viewedPercentFormat, viewedPercent))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppPalette.surface)
    }

    private var bottomActions: some View {
        VStack(spacing: 12) {
            if isDeleting {
                ProgressView(preferences.text(.deleting))
            } else {
                Button(role: .destructive) {
                    Task { await confirmAndDelete() }
                } label: {
                    Text(preferences.format(.deleteAllFormat, deleteQueue.items.count))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.danger)
                .disabled(deleteQueue.items.isEmpty)
            }
        }
        .padding()
        .background(AppPalette.surface)
    }

    private func confirmAndDelete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await deleteQueue.deleteAll()
            deletedSuccessfully = true
            onDismiss()
        } catch {
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
        LinearGradient(
            colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Grid hücresi: küçük önizleme + "Geri al" butonu

private struct ReviewDeleteRowView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let item: MediaItem
    let onRemove: () -> Void

    @State private var image: UIImage?

    var body: some View {
        VStack(spacing: 4) {
            thumbnailView
            Button(preferences.text(.remove), action: onRemove)
                .font(.caption2)
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
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

#Preview("Son kontrol") {
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
}
