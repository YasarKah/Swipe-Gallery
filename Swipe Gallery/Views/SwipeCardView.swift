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
    @Binding var isImageReady: Bool

    @State private var image: UIImage?
    @State private var livePhoto: PHLivePhoto?
    @State private var isPreparingLivePhoto = false
    @State private var livePlaybackToken = 0

    var body: some View {
        cardContent
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        .glassCard(accent: AppPalette.accentPurple, cornerRadius: 30, strokeOpacity: 0.20)
        .rotationEffect(cardRotation)
        .offset(cardOffset)
        .gesture(dragGesture)
    }

    private var liveBadge: some View {
        Button {
            playLivePhoto()
        } label: {
            AccentBadge(
                text: isPreparingLivePhoto ? preferences.text(.preparingLivePhoto) : preferences.text(.live),
                accent: AppPalette.accentPink,
                prominent: true
            )
        }
        .buttonStyle(.plain)
        .disabled(!isImageReady || isPreparingLivePhoto)
        .opacity((!isImageReady || isPreparingLivePhoto) ? 0.65 : 1)
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
                                AppPalette.glassSurfaceStrong,
                                AppPalette.glassSurface
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

                if let livePhoto {
                    LivePhotoInlineView(livePhoto: livePhoto, playbackToken: livePlaybackToken)
                        .frame(width: mediaSize.width, height: mediaSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else if let img = image ?? initialImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: mediaSize.width, height: mediaSize.height)
                } else {
                    ProgressView()
                        .tint(AppPalette.textPrimary)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isImageReady = initialImage != nil
            if image != nil { return }
            if let preloaded = initialImage {
                image = preloaded
                isImageReady = true
            } else {
                isImageReady = false
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
        decisionPill(title: preferences.text(.keep), systemImage: "checkmark.circle.fill", color: AppPalette.accentBlue)
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
                guard isImageReady else { return }
                cardOffset = value.translation
            }
            .onEnded { value in
                guard isImageReady else {
                    withAnimation(.spring(response: 0.3)) { cardOffset = .zero }
                    return
                }
                let threshold: CGFloat = min(92, UIScreen.main.bounds.width * 0.22)
                let effectiveTranslation = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
                    ? value.predictedEndTranslation.width
                    : value.translation.width

                if effectiveTranslation < -threshold {
                    commitDecision(.delete)
                } else if effectiveTranslation > threshold {
                    commitDecision(.keep)
                } else {
                    withAnimation(.spring(response: 0.3)) { cardOffset = .zero }
                }
            }
    }

    private func commitDecision(_ decision: SwipeDecision) {
        guard isImageReady else { return }
        AppFeedback.commit(style: .rigid)
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
            isImageReady = img != nil
        }
    }

    private func playLivePhoto() {
        guard item.isLivePhoto, isImageReady, !isPreparingLivePhoto else { return }

        if livePhoto != nil {
            AppFeedback.selection()
            livePlaybackToken += 1
            return
        }

        isPreparingLivePhoto = true
        ImageLoaderService.loadLivePhoto(
            for: item.phAsset,
            targetSize: CGSize(width: 1400, height: 1400)
        ) { loaded in
            livePhoto = loaded
            isPreparingLivePhoto = false
            if loaded != nil {
                AppFeedback.selection()
                livePlaybackToken += 1
            } else {
                AppFeedback.error()
            }
        }
    }

    private func decisionPill(title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .overlay {
                Capsule()
                    .fill(color.opacity(0.08))
            }
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.14), lineWidth: 1)
            }
    }
}

// Preview gerçek PHAsset gerektirir; simülatörde galeri ile test edin.

private struct LivePhotoInlineView: UIViewRepresentable {
    typealias UIViewType = PHLivePhotoView

    let livePhoto: PHLivePhoto
    let playbackToken: Int

    func makeUIView(context: Context) -> UIViewType {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.livePhoto = livePhoto
        if context.coordinator.playbackToken != playbackToken {
            context.coordinator.playbackToken = playbackToken
            uiView.startPlayback(with: .full)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var playbackToken = -1
    }
}
