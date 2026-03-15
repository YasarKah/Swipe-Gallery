import Foundation

final class GuidedCleanupService {
    private struct CacheKey: Hashable {
        let includeVideos: Bool
        let language: AppLanguage
    }

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    private let groupingService = MediaGroupingService()
    private let calendar = Calendar.current

    private static let cacheQueue = DispatchQueue(label: "GuidedCleanupService.cache", attributes: .concurrent)
    private static var cachedRootSteps: [CacheKey: [GuidedCleanupStep]] = [:]

    func fetchRootSteps(includeVideos: Bool, language: AppLanguage) async -> [GuidedCleanupStep] {
        let cacheKey = CacheKey(includeVideos: includeVideos, language: language)
        if let cached = Self.cachedRootSteps(for: cacheKey) {
            return cached
        }

        let items = await groupingService.fetchAllItems(includeVideos: includeVideos)
        let steps = buildRootSteps(from: items, includeVideos: includeVideos, language: language)
        Self.storeRootSteps(steps, for: cacheKey)
        return steps
    }

    private func buildRootSteps(
        from items: [MediaItem],
        includeVideos: Bool,
        language: AppLanguage
    ) -> [GuidedCleanupStep] {
        let monthSteps = buildMonthSteps(from: items, includeVideos: includeVideos, language: language)
        guard !monthSteps.isEmpty else { return [] }

        let currentYear = calendar.component(.year, from: Date())
        let recentMonths = Array(monthSteps.prefix(3))
        let remainingMonths = Array(monthSteps.dropFirst(recentMonths.count))

        let currentYearRemainder = remainingMonths.filter {
            if case let .month(year, _) = $0.kind {
                return year == currentYear
            }
            return false
        }

        let lastYearMonths = remainingMonths.filter {
            if case let .month(year, _) = $0.kind {
                return year == currentYear - 1
            }
            return false
        }

        let olderMonths = remainingMonths.filter {
            if case let .month(year, _) = $0.kind {
                return year < currentYear - 1
            }
            return false
        }

        var steps: [GuidedCleanupStep] = []
        if !recentMonths.isEmpty {
            steps.append(
                makeContainerStep(
                    id: "guided-\(stepModeToken(includeVideos: includeVideos))-recent-months",
                    title: AppText.value(for: .guidedRecentMonthsTitle, language: language),
                    subtitle: AppText.value(for: .guidedRecentMonthsSubtitle, language: language),
                    detail: AppText.value(for: .guidedRecentMonthsDetail, language: language),
                    kind: .recentMonths,
                    style: .hero,
                    children: recentMonths
                )
            )
        }

        if !currentYearRemainder.isEmpty {
            steps.append(
                makeContainerStep(
                    id: "guided-\(stepModeToken(includeVideos: includeVideos))-current-year",
                    title: AppText.value(for: .guidedCurrentYearTitle, language: language),
                    subtitle: AppText.value(for: .guidedCurrentYearSubtitle, language: language),
                    detail: AppText.value(for: .guidedCurrentYearDetail, language: language),
                    kind: .currentYearRemainder,
                    style: .highlight,
                    children: currentYearRemainder
                )
            )
        }

        if !lastYearMonths.isEmpty {
            steps.append(
                makeContainerStep(
                    id: "guided-\(stepModeToken(includeVideos: includeVideos))-last-year",
                    title: AppText.value(for: .guidedLastYearTitle, language: language),
                    subtitle: AppText.value(for: .guidedLastYearSubtitle, language: language),
                    detail: AppText.value(for: .guidedLastYearDetail, language: language),
                    kind: .lastYear,
                    style: .neutral,
                    children: lastYearMonths
                )
            )
        }

        let olderYearSteps = buildYearSteps(from: olderMonths, includeVideos: includeVideos, language: language)
        if !olderYearSteps.isEmpty {
            steps.append(
                makeContainerStep(
                    id: "guided-\(stepModeToken(includeVideos: includeVideos))-older-years",
                    title: AppText.value(for: .guidedOlderYearsTitle, language: language),
                    subtitle: AppText.value(for: .guidedOlderYearsSubtitle, language: language),
                    detail: AppText.value(for: .guidedOlderYearsDetail, language: language),
                    kind: .olderYears,
                    style: .archive,
                    children: olderYearSteps
                )
            )
        }

        return steps
    }

    private func buildMonthSteps(
        from items: [MediaItem],
        includeVideos: Bool,
        language: AppLanguage
    ) -> [GuidedCleanupStep] {
        let grouped = Dictionary(grouping: items) { item -> MonthKey in
            let date = item.creationDate ?? Date.distantPast
            return MonthKey(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date)
            )
        }

        return grouped.keys.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            return lhs.month > rhs.month
        }
        .compactMap { key in
            guard let monthItems = grouped[key], !monthItems.isEmpty else { return nil }
            let counts = countPhotosVideos(in: monthItems)
            let dateRange = Self.monthDateRange(calendar: calendar, year: key.year, month: key.month)
            let id = "guided-\(stepModeToken(includeVideos: includeVideos))-month-\(key.year)-\(key.month)"
            let title = DateFormatterHelper.monthYearShort(month: key.month, year: key.year, language: language)
            let isCurrentMonth = key.year == calendar.component(.year, from: Date()) &&
                key.month == calendar.component(.month, from: Date())
            let subtitleKey: AppTextKey = isCurrentMonth ? .guidedCurrentMonthSubtitle : .guidedMonthSubtitle
            let detailFormatKey: AppTextKey = includeVideos ? .guidedMonthDetailWithVideosFormat : .guidedMonthDetailPhotosFormat

            return GuidedCleanupStep(
                id: id,
                title: title,
                subtitle: AppText.value(for: subtitleKey, language: language),
                detail: String(
                    format: AppText.value(for: detailFormatKey, language: language),
                    locale: Locale(identifier: language.localeIdentifier),
                    counts.photos,
                    counts.videos
                ),
                kind: .month(year: key.year, month: key.month),
                style: .neutral,
                dateRange: dateRange,
                photoCount: counts.photos,
                videoCount: counts.videos,
                childSteps: []
            )
        }
    }

    private func buildYearSteps(
        from monthSteps: [GuidedCleanupStep],
        includeVideos: Bool,
        language: AppLanguage
    ) -> [GuidedCleanupStep] {
        let groupedByYear = Dictionary(grouping: monthSteps) { step -> Int in
            guard case let .month(year, _) = step.kind else { return 0 }
            return year
        }

        return groupedByYear.keys.sorted(by: >).compactMap { year in
            guard let children = groupedByYear[year], !children.isEmpty else { return nil }
            let counts = aggregateCounts(for: children)
            return GuidedCleanupStep(
                id: "guided-\(stepModeToken(includeVideos: includeVideos))-year-\(year)",
                title: String(
                    format: AppText.value(for: .guidedYearTitleFormat, language: language),
                    locale: Locale(identifier: language.localeIdentifier),
                    year
                ),
                subtitle: AppText.value(for: .guidedYearSubtitle, language: language),
                detail: String(
                    format: AppText.value(for: .guidedYearDetailFormat, language: language),
                    locale: Locale(identifier: language.localeIdentifier),
                    children.count
                ),
                kind: .year(year),
                style: .archive,
                dateRange: nil,
                photoCount: counts.photos,
                videoCount: counts.videos,
                childSteps: children
            )
        }
    }

    private func makeContainerStep(
        id: String,
        title: String,
        subtitle: String,
        detail: String,
        kind: GuidedCleanupStepKind,
        style: GuidedCleanupStepStyle,
        children: [GuidedCleanupStep]
    ) -> GuidedCleanupStep {
        let counts = aggregateCounts(for: children)
        return GuidedCleanupStep(
            id: id,
            title: title,
            subtitle: subtitle,
            detail: detail,
            kind: kind,
            style: style,
            dateRange: nil,
            photoCount: counts.photos,
            videoCount: counts.videos,
            childSteps: children
        )
    }

    private func countPhotosVideos(in items: [MediaItem]) -> (photos: Int, videos: Int) {
        items.reduce(into: (photos: 0, videos: 0)) { partial, item in
            if item.isVideo {
                partial.videos += 1
            } else {
                partial.photos += 1
            }
        }
    }

    private func aggregateCounts(for steps: [GuidedCleanupStep]) -> (photos: Int, videos: Int) {
        steps.reduce(into: (photos: 0, videos: 0)) { partial, step in
            partial.photos += step.photoCount
            partial.videos += step.videoCount
        }
    }

    private func stepModeToken(includeVideos: Bool) -> String {
        includeVideos ? "mixed" : "photos"
    }

    private static func monthDateRange(calendar: Calendar, year: Int, month: Int) -> ClosedRange<Date>? {
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) else {
            return nil
        }
        return start ... end
    }

    private static func cachedRootSteps(for key: CacheKey) -> [GuidedCleanupStep]? {
        cacheQueue.sync { cachedRootSteps[key] }
    }

    private static func storeRootSteps(_ steps: [GuidedCleanupStep], for key: CacheKey) {
        cacheQueue.async(flags: .barrier) {
            cachedRootSteps[key] = steps
        }
    }
}
