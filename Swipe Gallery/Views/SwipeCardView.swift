//
//  SwipeCardView.swift
//  Swipe Gallery
//
//  Tek fotoğraf kartı: sol swipe → silme kuyruğu, sağ swipe → tut. Altta X ve ✓ butonları.
//

import SwiftUI
import Photos
import PhotosUI

/// Kartın dışarı kayma animasyonu süresi; onDecision bu süre sonra çağrılır
private let cardExitAnimationDuration: TimeInterval = 0.18

struct SwipeCardView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let item: MediaItem
    let index: Int
    let total: Int
    var initialImage: UIImage? = nil
    var cardHeight: CGFloat
    let onDecision: (SwipeDecision) -> Void
    @Binding var cardOffset: CGSize

    @State private var image: UIImage?
    @State private var hapticGenerator: UIImpactFeedbackGenerator?
    @State private var showLivePhotoPreview = false

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        .sheet(isPresented: $showLivePhotoPreview) {
            LivePhotoPreviewSheet(item: item)
        }
    }

    /// Tinder tarzı: sürüklerken kart hafifçe yarım daire hissiyle döner (radius çevresinde)
    private var cardRotation: Angle {
        let divisor: CGFloat = 28
        return .degrees(Double(cardOffset.width / divisor))
    }

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            imageView
            if item.isLivePhoto {
                liveBadge
            }
            overlayLabels
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: AppPalette.accentBlue.opacity(0.06), radius: 18, y: 8)
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        .rotationEffect(cardRotation)
        .offset(cardOffset)
        .gesture(dragGesture)
    }

    private var liveBadge: some View {
        Button {
            showLivePhotoPreview = true
        } label: {
            Label(preferences.text(.live), systemImage: "livephoto")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppPalette.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(14)
    }

    private var imageView: some View {
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
                                AppPalette.accentBlue.opacity(0.16),
                                AppPalette.accentPurple.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.02))
                    .frame(width: mediaSize.width, height: mediaSize.height)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(.white.opacity(0.04), lineWidth: 0.5)
                    }

                if let img = image ?? initialImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: mediaSize.width, height: mediaSize.height)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if hapticGenerator == nil {
                let gen = UIImpactFeedbackGenerator(style: .medium)
                gen.prepare()
                hapticGenerator = gen
            }
            if image != nil { return }
            if let preloaded = initialImage {
                image = preloaded
            } else {
                loadImage()
            }
        }
    }

    private var overlayLabels: some View {
        HStack {
            keepLabel
            Spacer()
            deleteLabel
        }
        .padding(22)
        .opacity(dragOpacity)
    }

    private var keepLabel: some View {
        decisionPill(title: preferences.text(.keep), systemImage: "checkmark.circle.fill", color: AppPalette.success)
    }

    private var deleteLabel: some View {
        decisionPill(title: preferences.text(.delete), systemImage: "xmark.circle.fill", color: AppPalette.danger)
    }

    private var dragOpacity: Double {
        let width = UIScreen.main.bounds.width
        return min(1, abs(cardOffset.width) / (width * 0.3))
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                cardOffset = value.translation
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                if value.translation.width < -threshold {
                    commitDecision(.delete)
                } else if value.translation.width > threshold {
                    commitDecision(.keep)
                } else {
                    withAnimation(.spring(response: 0.3)) { cardOffset = .zero }
                }
            }
    }

    private func commitDecision(_ decision: SwipeDecision) {
        hapticGenerator?.impactOccurred()
        withAnimation(.easeOut(duration: cardExitAnimationDuration)) {
            cardOffset = CGSize(
                width: decision == .delete ? -400 : 400,
                height: cardOffset.height
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + cardExitAnimationDuration) {
            onDecision(decision)
        }
    }

    private func loadImage() {
        let size = CGSize(width: 1200, height: 1200)
        ImageLoaderService.loadImage(
            for: item.phAsset,
            targetSize: size,
            contentMode: .aspectFit,
            deliveryMode: .highQualityFormat
        ) { img in
            image = img
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                AppPalette.cardBase.opacity(0.58),
                AppPalette.backgroundBottom.opacity(0.46)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func decisionPill(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.28))
            .clipShape(Capsule())
    }
}

// Preview gerçek PHAsset gerektirir; simülatörde galeri ile test edin.

private struct LivePhotoPreviewSheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    let item: MediaItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if item.isLivePhoto {
                    LivePhotoPlayerView(asset: item.phAsset)
                        .padding(20)
                } else {
                    ContentUnavailableView(
                        preferences.text(.featureUnavailable),
                        systemImage: "sparkles",
                        description: Text(preferences.text(.featureUnavailableDescription))
                    )
                }
            }
            .navigationTitle(preferences.text(.live))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(preferences.text(.close)) { dismiss() }
                }
            }
        }
    }
}

private struct LivePhotoPlayerView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let asset: PHAsset
    @State private var livePhoto: PHLivePhoto?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppPalette.surface)

            if let livePhoto {
                LivePhotoContainerView(livePhoto: livePhoto)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(12)
            } else {
                ProgressView(preferences.text(.preparingLivePhoto))
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(AppPalette.border, lineWidth: 1)
        }
        .task {
            ImageLoaderService.loadLivePhoto(
                for: asset,
                targetSize: CGSize(width: 1400, height: 1400)
            ) { loaded in
                livePhoto = loaded
            }
        }
    }
}

private struct LivePhotoContainerView: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        uiView.livePhoto = livePhoto
        uiView.startPlayback(with: .full)
    }
}
