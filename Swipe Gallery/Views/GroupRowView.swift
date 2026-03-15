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
                countBadges
                chevronView
            }
            .padding()
            if progressTotal > 0 && progressViewed < progressTotal {
                progressBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockGradient)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 20, y: 10)
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 46, height: 46)
            .background(.white.opacity(0.16))
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
            .clipShape(Circle())
    }

    private var titleView: some View {
        Text(group.title)
            .font(titleFont)
            .foregroundStyle(.white)
            .strikethrough(group.isCompleted, color: .white.opacity(0.8))
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
                    .fill(.white.opacity(0.18))
                    .frame(height: 5)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.92), .white.opacity(0.66)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progressPercent, height: 5)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var chevronView: some View {
        Image(systemName: "chevron.right")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
    }

    private var blockGradient: some View {
        LinearGradient(
            colors: [blockColor, blockColor.opacity(0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private func countBadge(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14))
            .clipShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Grup kartı") {
    GroupRowView(
        group: MediaGroup(id: "1", title: "Bugün", type: .today, photoCount: 12, videoCount: 2),
        includeVideos: true,
        progressViewed: 3,
        progressTotal: 14,
        rowIndex: 0
    )
    .padding()
    .environmentObject(AppPreferences())
}

#Preview("Tamamlanmış kart") {
    GroupRowView(
        group: MediaGroup(id: "2", title: "OCA '25", type: .month(year: 2025, month: 1), isCompleted: true, photoCount: 80, videoCount: 4),
        includeVideos: true,
        progressViewed: 84,
        progressTotal: 84,
        rowIndex: 4
    )
    .padding()
    .environmentObject(AppPreferences())
}
