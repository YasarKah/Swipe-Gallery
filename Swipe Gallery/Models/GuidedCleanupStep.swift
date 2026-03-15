import Foundation

enum GuidedCleanupStepKind: Hashable {
    case recentMonths
    case currentYearRemainder
    case lastYear
    case olderYears
    case year(Int)
    case month(year: Int, month: Int)
}

enum GuidedCleanupStepStyle: Hashable {
    case hero
    case highlight
    case neutral
    case archive
}

struct GuidedCleanupStep: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let detail: String
    let kind: GuidedCleanupStepKind
    let style: GuidedCleanupStepStyle
    let dateRange: ClosedRange<Date>?
    let photoCount: Int
    let videoCount: Int
    let childSteps: [GuidedCleanupStep]

    var isLeaf: Bool {
        childSteps.isEmpty
    }

    var totalCount: Int {
        photoCount + videoCount
    }

    func makeMediaGroup() -> MediaGroup? {
        guard case let .month(year, month) = kind else { return nil }
        return MediaGroup(
            id: id,
            title: title,
            dateRange: dateRange,
            type: .month(year: year, month: month),
            photoCount: photoCount,
            videoCount: videoCount
        )
    }
}
