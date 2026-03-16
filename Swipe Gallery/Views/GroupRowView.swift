//
//  GroupRowView.swift
//  Swipe Gallery
//
//  Ana ekrandaki tek bir grup kartı. Renkli blok, başlık, 📷/🎬 sayıları, ilerleme çubuğu, tamamlanmışsa üstü çizili.
//

import SwiftUI

struct GroupRowView: View {
    @EnvironmentObject private var preferences: AppPreferences
    let group: MediaGroup
    var includeVideos: Bool = false
    var progressViewed: Int = 0
    var progressTotal: Int = 0
    var rowIndex: Int = 0
    var onTap: (() -> Void)?

    private var progressPercent: Double {
        guard progressTotal > 0 else { return 0 }
        return min(1, Double(progressViewed) / Double(progressTotal))
    }

    var body: some View {
        Button(action: { onTap?() }) {
            cardContent
        }
        .buttonStyle(.plain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                iconView
                titleView
                Spacer()
                if group.isCompleted {
                    completedBadge
                }
                countBadges
                chevronView
            }
            .padding()
            if progressTotal > 0 && progressViewed < progressTotal {
                progressBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(blockColor.opacity(group.isCompleted ? 0.22 : 0.16), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 10, y: 5)
        .overlay {
            if group.isCompleted {
                completionOverlay
            }
        }
        .saturation(group.isCompleted ? 0.72 : 1)
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(AppPalette.textPrimary)
            .frame(width: 46, height: 46)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [blockColor.opacity(0.20), AppPalette.cardBase.opacity(0.96)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Circle()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.20), lineWidth: 1)
            }
            .clipShape(Circle())
    }

    private var titleView: some View {
        Text(group.title)
            .font(titleFont)
            .foregroundStyle(group.isCompleted ? AppPalette.textSecondary : AppPalette.textPrimary)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
    }

    private var countBadges: some View {
        HStack(spacing: 8) {
            if let extraBadgeText {
                countBadge(text: extraBadgeText)
            }
            countBadge(text: "📷 \(group.photoCount)")
            if includeVideos && group.videoCount > 0 {
                countBadge(text: "🎬 \(group.videoCount)")
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(AppPalette.glassBorder.opacity(0.48))
                    .frame(height: 5)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [blockColor.opacity(0.96), AppPalette.neonBlueGlow.opacity(0.82)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressPercent, height: 5)
                    .shadow(color: blockColor.opacity(0.24), radius: 10, y: 0)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
            .foregroundStyle(AppPalette.textSecondary)
    }

    private var iconName: String {
        switch group.type {
        case .smart: return "sparkles"
        case .smartCategory(let kind):
            switch kind {
            case .similar: return "square.stack.3d.down.right.fill"
            case .screenshots: return "rectangle.on.rectangle"
            case .blurry: return "camera.aperture"
            }
        case .smartCluster: return "square.stack.3d.down.right.fill"
        case .today: return "sun.max.fill"
        case .recent: return "clock.fill"
        case .random: return "shuffle"
        case .month: return "calendar"
        case .monthCollection: return "folder.fill"
        }
    }

    private var blockColor: Color {
        switch group.type {
        case .smart: return AppPalette.accentPink
        case .smartCategory(let kind):
            switch kind {
            case .similar: return Color(red: 0.40, green: 0.42, blue: 0.95)
            case .screenshots: return Color(red: 0.29, green: 0.66, blue: 0.94)
            case .blurry: return Color(red: 0.51, green: 0.39, blue: 0.91)
            }
        case .smartCluster: return Color(red: 0.40, green: 0.42, blue: 0.95)
        case .today: return AppPalette.accentBlue
        case .recent: return Color(red: 0.29, green: 0.45, blue: 0.97)
        case .random: return AppPalette.accentPurple
        case .month: return AppPalette.rowColors[rowIndex % AppPalette.rowColors.count]
        case .monthCollection: return Color(red: 0.32, green: 0.40, blue: 0.88)
        }
    }

    private var extraBadgeText: String? {
        switch group.type {
        case .smart:
            return preferences.format(.groupCountFormat, group.childGroups.count)
        case .smartCategory(.similar):
            return preferences.format(.clusterCountFormat, group.childGroups.count)
        case .smartCategory(.screenshots):
            return "📱 \(preferences.text(.quickCleanup))"
        case .smartCategory(.blurry):
            return "🌫️ \(preferences.text(.weakFrames))"
        case .smartCluster:
            return preferences.format(.allSimilarsCountFormat, group.photoCount)
        case .monthCollection:
            return preferences.format(.monthCountFormat, group.childGroups.count)
        default:
            return nil
        }
    }

    private var titleFont: Font {
        switch group.type {
        case .smartCluster:
            return .headline.weight(.semibold)
        default:
            return .title2.weight(.semibold)
        }
    }

    private var completedBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [blockColor.opacity(0.18), AppPalette.cardBase.opacity(0.96)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(blockColor)
        }
        .frame(width: 34, height: 34)
        .overlay {
            Circle()
                .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
        }
    }

    private func countBadge(text: String) -> some View {
        AccentBadge(text: text, accent: blockColor, useMaterial: false)
    }

    private var completionOverlay: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(blockColor.opacity(0.28), lineWidth: 1.2)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.white.opacity(0.03))
            }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                AppPalette.cardBase.opacity(0.98),
                blockColor.opacity(group.isCompleted ? 0.10 : 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Previews

struct GroupRowView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GroupRowView(
                group: MediaGroup(id: "1", title: "Bugün", type: .today, photoCount: 12, videoCount: 2),
                includeVideos: true,
                progressViewed: 3,
                progressTotal: 14,
                rowIndex: 0
            )
            .padding()
            .environmentObject(AppPreferences())
            .previewDisplayName("Grup karti")

            GroupRowView(
                group: MediaGroup(id: "2", title: "OCA '25", type: .month(year: 2025, month: 1), isCompleted: true, photoCount: 80, videoCount: 4),
                includeVideos: true,
                progressViewed: 84,
                progressTotal: 84,
                rowIndex: 4
            )
            .padding()
            .environmentObject(AppPreferences())
            .previewDisplayName("Tamamlanmis kart")
        }
    }
}
