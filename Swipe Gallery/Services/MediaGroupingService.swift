//
//  MediaGroupingService.swift
//  Swipe Gallery
//
//  Tüm assetleri alıp gruplara böler: Bugün, Son eklenenler, Rastgele, Ay grupları.
//

import Foundation
import Photos
import UIKit

final class MediaGroupingService {
    private struct GroupCacheKey: Hashable {
        let includeVideos: Bool
        let language: AppLanguage
    }

    private let photoLibrary = PhotoLibraryService()
    private let calendar = Calendar.current
    private let compactMonthPhotoThreshold = 150
    private let smartClusterTimeWindow: TimeInterval = 18
    private let smartAspectRatioTolerance: CGFloat = 0.12
    private let smartPixelAreaTolerance: CGFloat = 0.18
    private let smartHashDistanceThreshold = 9

    private struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }

    private struct SmartSignature {
        let perceptualHash: UInt64
        let sharpnessScore: Double
    }

    private static let cacheQueue = DispatchQueue(label: "MediaGroupingService.cache", attributes: .concurrent)
    private static var cachedAllItems: [Bool: [MediaItem]] = [:]
    private static var cachedGroups: [GroupCacheKey: [MediaGroup]] = [:]
    private static var cachedSmartCategories: [GroupCacheKey: [MediaGroup]] = [:]

    /// Galeri izni verilmiş veya sınırlı mı?
    func hasPhotoAccess() -> Bool {
        photoLibrary.isAuthorized
    }

    /// includeVideos: video dahil mi
    /// completedGroupIds: tamamlanmış sayılan grup id'leri (üstü çizili)
    /// Ağır PhotoKit işi ana thread'i bloke etmemesi için DispatchQueue ile arka planda çalışır.
    func fetchGroups(
        includeVideos: Bool,
        completedGroupIds: Set<String> = [],
        language: AppLanguage = .turkish
    ) async -> [MediaGroup] {
        let hasAccess = await photoLibrary.requestAuthorization()
        guard hasAccess else { return [] }

        let cacheKey = GroupCacheKey(includeVideos: includeVideos, language: language)
        if let cached = Self.cachedGroups(for: cacheKey) {
            return applyCompletionState(to: cached, completedIds: completedGroupIds)
        }

        return await withCheckedContinuation { continuation in
            let cal = calendar

            DispatchQueue.global(qos: .userInitiated).async {
                let allItems = self.loadAllItems(includeVideos: includeVideos)
                guard !allItems.isEmpty else {
                    DispatchQueue.main.async { continuation.resume(returning: []) }
                    return
                }

                let today = cal.startOfDay(for: Date())
                var groups: [MediaGroup] = []

                let smartPhotoCount = allItems.filter { !$0.isVideo }.count
                if smartPhotoCount > 1 {
                    groups.append(MediaGroup(
                        id: "smart",
                        title: AppText.value(for: .smartTitle, language: language),
                        type: .smart,
                        photoCount: smartPhotoCount,
                        videoCount: 0
                    ))
                }

                // Bugün
                let todayItems = allItems.filter { item in
                    guard let d = item.creationDate else { return false }
                    return cal.isDate(d, inSameDayAs: today)
                }
                if !todayItems.isEmpty {
                    let (photos, videos) = Self.countPhotosVideos(todayItems)
                    groups.append(MediaGroup(
                        id: "today",
                        title: AppText.value(for: .todayTitle, language: language),
                        dateRange: nil,
                        type: .today,
                        photoCount: photos,
                        videoCount: videos
                    ))
                }

                // Son eklenenler (son 7 gün)
                if let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) {
                    let recent = allItems.filter { ($0.creationDate ?? .distantPast) >= weekAgo }
                    if !recent.isEmpty {
                        let (photos, videos) = Self.countPhotosVideos(recent)
                        groups.append(MediaGroup(
                            id: "recent",
                            title: AppText.value(for: .recentTitle, language: language),
                            dateRange: weekAgo ... Date(),
                            type: .recent,
                            photoCount: photos,
                            videoCount: videos
                        ))
                    }
                }

                // Rastgele
                let (allPhotos, allVideos) = Self.countPhotosVideos(allItems)
                groups.append(MediaGroup(
                    id: "random",
                    title: AppText.value(for: .randomTitle, language: language),
                    dateRange: nil,
                    type: .random,
                    photoCount: allPhotos,
                    videoCount: allVideos
                ))

                // Ay grupları (en yeni → en eski)
                let byMonth = Dictionary(grouping: allItems) { item -> MonthKey in
                    let d = item.creationDate ?? Date()
                    let year = cal.component(.year, from: d)
                    let month = cal.component(.month, from: d)
                    return MonthKey(year: year, month: month)
                }
                let sortedMonths = byMonth.keys.sorted { a, b in
                    if a.year != b.year { return a.year > b.year }
                    return a.month > b.month
                }
                var monthGroups: [MediaGroup] = []
                for key in sortedMonths {
                    let title = DateFormatterHelper.monthYearShort(month: key.month, year: key.year, language: language)
                    let id = "\(key.year)-\(key.month)"
                    let monthItems = byMonth[key] ?? []
                    let (photos, videos) = Self.countPhotosVideos(monthItems)
                    monthGroups.append(MediaGroup(
                        id: id,
                        title: title,
                        dateRange: Self.dateRangeFor(calendar: cal, year: key.year, month: key.month),
                        type: .month(year: key.year, month: key.month),
                        photoCount: photos,
                        videoCount: videos
                    ))
                }

                let compactMonths = monthGroups.filter { $0.photoCount < self.compactMonthPhotoThreshold }
                let regularMonths = monthGroups.filter { $0.photoCount >= self.compactMonthPhotoThreshold }

                groups.append(contentsOf: regularMonths)

                if !compactMonths.isEmpty {
                    let totalPhotos = compactMonths.reduce(0) { $0 + $1.photoCount }
                    let totalVideos = compactMonths.reduce(0) { $0 + $1.videoCount }

                    groups.append(MediaGroup(
                        id: "month-collection-compact",
                        title: AppText.value(for: .smallMonthsTitle, language: language),
                        type: .monthCollection,
                        childGroups: compactMonths,
                        photoCount: totalPhotos,
                        videoCount: totalVideos
                    ))
                }

                Self.storeGroups(groups, for: cacheKey)
                let resolved = self.applyCompletionState(to: groups, completedIds: completedGroupIds)
                DispatchQueue.main.async { continuation.resume(returning: resolved) }
            }
        }
    }

    func fetchSmartCategories(
        includeVideos: Bool,
        completedGroupIds: Set<String> = [],
        language: AppLanguage = .turkish
    ) async -> [MediaGroup] {
        let hasAccess = await photoLibrary.requestAuthorization()
        guard hasAccess else { return [] }

        let cacheKey = GroupCacheKey(includeVideos: includeVideos, language: language)
        if let cached = Self.cachedSmartCategories(for: cacheKey) {
            return applyCompletionState(to: cached, completedIds: completedGroupIds)
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let allItems = self.loadAllItems(includeVideos: includeVideos)
                let categories = self.buildSmartCategories(from: allItems, language: language)
                Self.storeSmartCategories(categories, for: cacheKey)
                let resolved = self.applyCompletionState(to: categories, completedIds: completedGroupIds)
                DispatchQueue.main.async { continuation.resume(returning: resolved) }
            }
        }
    }

    func fetchAllItems(includeVideos: Bool) async -> [MediaItem] {
        let hasAccess = await photoLibrary.requestAuthorization()
        guard hasAccess else { return [] }

        if let cached = Self.cachedAllItems(for: includeVideos) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let items = self.loadAllItems(includeVideos: includeVideos)
                DispatchQueue.main.async {
                    continuation.resume(returning: items)
                }
            }
        }
    }

    /// Belirli bir gruba ait medya listesi. En yeni → en eski.
    func fetchMedia(for group: MediaGroup, includeVideos: Bool) -> [MediaItem] {
        if let cachedItems = Self.cachedAllItems(for: includeVideos) {
            switch group.type {
            case .smart:
                return []

            case .smartCategory:
                let ids = Set(group.assetIdentifiers)
                return cachedItems.filter { ids.contains($0.id) }

            case .smartCluster:
                let ids = Set(group.assetIdentifiers)
                return cachedItems.filter { ids.contains($0.id) }

            case .today:
                let start = calendar.startOfDay(for: Date())
                guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return cachedItems }
                let range = start ... end
                return cachedItems.filter { item in
                    guard let date = item.creationDate else { return false }
                    return range.contains(date)
                }

            case .recent:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return cachedItems }
                let range = weekAgo ... Date()
                return cachedItems.filter { item in
                    guard let date = item.creationDate else { return false }
                    return range.contains(date)
                }

            case .random:
                var items = cachedItems
                items.shuffle()
                return items

            case .month(let year, let month):
                guard let range = dateRangeFor(year: year, month: month) else { return cachedItems }
                return cachedItems.filter { item in
                    guard let date = item.creationDate else { return false }
                    return range.contains(date)
                }

            case .monthCollection:
                return []
            }
        }

        switch group.type {
        case .smart:
            return []

        case .smartCategory:
            return photoLibrary.fetchAssets(localIdentifiers: group.assetIdentifiers)

        case .smartCluster:
            return photoLibrary.fetchAssets(localIdentifiers: group.assetIdentifiers)

        case .today:
            let start = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return photoLibrary.fetchAssets(dateRange: nil, includeVideos: includeVideos)
            }
            let range = start ... end
            return photoLibrary.fetchAssets(dateRange: range, includeVideos: includeVideos)

        case .recent:
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
                return photoLibrary.fetchAssets(dateRange: nil, includeVideos: includeVideos)
            }
            let range = weekAgo ... Date()
            return photoLibrary.fetchAssets(dateRange: range, includeVideos: includeVideos)

        case .random:
            var items = photoLibrary.fetchAssets(dateRange: nil, includeVideos: includeVideos)
            items.shuffle()
            return items

        case .month(let year, let month):
            guard let range = dateRangeFor(year: year, month: month) else {
                return photoLibrary.fetchAssets(dateRange: nil, includeVideos: includeVideos)
            }
            return photoLibrary.fetchAssets(dateRange: range, includeVideos: includeVideos)

        case .monthCollection:
            return []
        }
    }

    private func dateRangeFor(year: Int, month: Int) -> ClosedRange<Date>? {
        Self.dateRangeFor(calendar: calendar, year: year, month: month)
    }

    private static func dateRangeFor(calendar: Calendar, year: Int, month: Int) -> ClosedRange<Date>? {
        guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: nextMonth) else {
            return nil
        }
        return start ... end
    }

    private static func countPhotosVideos(_ items: [MediaItem]) -> (photos: Int, videos: Int) {
        var photos = 0, videos = 0
        for item in items {
            if item.isVideo { videos += 1 } else { photos += 1 }
        }
        return (photos, videos)
    }

    private func buildSmartCategories(from items: [MediaItem], language: AppLanguage) -> [MediaGroup] {
        let photoItems = items.filter { !$0.isVideo && !$0.isScreenshot }
        let screenshotItems = items.filter { $0.isScreenshot }

        var signatureCache: [String: SmartSignature] = [:]
        var categories: [MediaGroup] = []

        let similarGroups = buildSmartSimilarGroups(
            from: photoItems,
            language: language,
            signatureCache: &signatureCache
        )
        if !similarGroups.isEmpty {
            categories.append(MediaGroup(
                id: "smart-similar",
                title: AppText.value(for: .similarTitle, language: language),
                type: .smartCategory(.similar),
                assetIdentifiers: similarGroups.flatMap(\.assetIdentifiers),
                childGroups: similarGroups,
                photoCount: similarGroups.reduce(0) { $0 + $1.photoCount },
                videoCount: 0
            ))
        }

        if !screenshotItems.isEmpty {
            categories.append(MediaGroup(
                id: "smart-screenshots",
                title: AppText.value(for: .screenshotsTitle, language: language),
                type: .smartCategory(.screenshots),
                assetIdentifiers: screenshotItems.map(\.id),
                photoCount: screenshotItems.count,
                videoCount: 0
            ))
        }

        let blurryItems = buildBlurryItems(from: photoItems, signatureCache: &signatureCache)
        if !blurryItems.isEmpty {
            categories.append(MediaGroup(
                id: "smart-blurry",
                title: AppText.value(for: .blurryTitle, language: language),
                type: .smartCategory(.blurry),
                assetIdentifiers: blurryItems.map(\.id),
                photoCount: blurryItems.count,
                videoCount: 0
            ))
        }

        return categories
    }

    private func buildSmartSimilarGroups(
        from photoItems: [MediaItem],
        language: AppLanguage,
        signatureCache: inout [String: SmartSignature]
    ) -> [MediaGroup] {
        guard photoItems.count > 1 else { return [] }

        var result: [MediaGroup] = []
        var currentCluster: [MediaItem] = []

        func flushCluster() {
            guard currentCluster.count >= 2 else {
                currentCluster.removeAll(keepingCapacity: true)
                return
            }

            let cluster = currentCluster.sorted {
                let lhs = signature(for: $0, cache: &signatureCache)?.sharpnessScore ?? .greatestFiniteMagnitude
                let rhs = signature(for: $1, cache: &signatureCache)?.sharpnessScore ?? .greatestFiniteMagnitude
                return lhs < rhs
            }
            let firstDate = cluster.first?.creationDate ?? Date()
            let title = "\(AppText.value(for: .similarTitle, language: language)) • \(DateFormatterHelper.smartClusterTitle(from: firstDate, language: language))"
            let id = "smart-\(cluster.first?.id ?? UUID().uuidString)"

            result.append(MediaGroup(
                id: id,
                title: title,
                type: .smartCluster,
                assetIdentifiers: cluster.map(\.id),
                photoCount: cluster.count,
                videoCount: 0
            ))

            currentCluster.removeAll(keepingCapacity: true)
        }

        for item in photoItems {
            guard let last = currentCluster.last else {
                currentCluster = [item]
                continue
            }

            if isSimilar(item, to: last, cache: &signatureCache) {
                currentCluster.append(item)
            } else {
                flushCluster()
                currentCluster = [item]
            }
        }

        flushCluster()
        return result.sorted {
            if $0.photoCount != $1.photoCount {
                return $0.photoCount > $1.photoCount
            }
            return $0.title < $1.title
        }
    }

    private func buildBlurryItems(
        from items: [MediaItem],
        signatureCache: inout [String: SmartSignature]
    ) -> [MediaItem] {
        let scoredItems = items.compactMap { item -> (item: MediaItem, sharpness: Double)? in
            guard let signature = signature(for: item, cache: &signatureCache) else { return nil }
            return (item, signature.sharpnessScore)
        }
        .sorted { $0.sharpness < $1.sharpness }

        guard scoredItems.count >= 8 else { return [] }

        let limit = min(max(scoredItems.count / 8, 12), 80)
        let thresholdIndex = min(limit - 1, scoredItems.count - 1)
        let threshold = scoredItems[thresholdIndex].sharpness

        return scoredItems
            .filter { $0.sharpness <= threshold }
            .prefix(limit)
            .map(\.item)
    }

    private func isSimilar(_ lhs: MediaItem, to rhs: MediaItem) -> Bool {
        guard let lhsDate = lhs.creationDate, let rhsDate = rhs.creationDate else { return false }
        guard calendar.isDate(lhsDate, inSameDayAs: rhsDate) else { return false }

        let timeDifference = abs(lhsDate.timeIntervalSince(rhsDate))
        guard timeDifference <= smartClusterTimeWindow else { return false }

        let aspectDifference = abs(lhs.displayAspectRatio - rhs.displayAspectRatio)
        guard aspectDifference <= smartAspectRatioTolerance else { return false }

        let lhsPixelArea = CGFloat(lhs.phAsset.pixelWidth * lhs.phAsset.pixelHeight)
        let rhsPixelArea = CGFloat(rhs.phAsset.pixelWidth * rhs.phAsset.pixelHeight)
        let maxPixelArea = max(max(lhsPixelArea, rhsPixelArea), 1)
        let normalizedAreaDifference = abs(lhsPixelArea - rhsPixelArea) / maxPixelArea
        return normalizedAreaDifference <= smartPixelAreaTolerance
    }

    private func isSimilar(
        _ lhs: MediaItem,
        to rhs: MediaItem,
        cache: inout [String: SmartSignature]
    ) -> Bool {
        guard isSimilar(lhs, to: rhs) else { return false }

        guard let lhsSignature = signature(for: lhs, cache: &cache),
              let rhsSignature = signature(for: rhs, cache: &cache) else {
            return false
        }

        return hammingDistance(lhsSignature.perceptualHash, rhsSignature.perceptualHash) <= smartHashDistanceThreshold
    }

    private func signature(
        for item: MediaItem,
        cache: inout [String: SmartSignature]
    ) -> SmartSignature? {
        if let cached = cache[item.id] {
            return cached
        }

        guard let image = ImageLoaderService.loadImageSynchronously(
            for: item.phAsset,
            targetSize: CGSize(width: 48, height: 48),
            contentMode: .aspectFit,
            deliveryMode: .fastFormat
        ),
        let signature = makeSignature(from: image) else {
            return nil
        }

        cache[item.id] = signature
        return signature
    }

    private func makeSignature(from image: UIImage) -> SmartSignature? {
        guard let cgImage = image.cgImage else { return nil }

        let width = 9
        let height = 8
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bitIndex: UInt64 = 0
        var edgeEnergy = 0.0

        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = pixels[(y * width) + x]
                let right = pixels[(y * width) + x + 1]
                if left > right {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
                edgeEnergy += abs(Double(Int(left) - Int(right)))
            }
        }

        let sharpnessScore = edgeEnergy / Double((width - 1) * height)
        return SmartSignature(perceptualHash: hash, sharpnessScore: sharpnessScore)
    }

    private func hammingDistance(_ lhs: UInt64, _ rhs: UInt64) -> Int {
        (lhs ^ rhs).nonzeroBitCount
    }

    private func loadAllItems(includeVideos: Bool) -> [MediaItem] {
        if let cached = Self.cachedAllItems(for: includeVideos) {
            return cached
        }

        let items = photoLibrary.fetchAssets(dateRange: nil, includeVideos: includeVideos)
        Self.storeAllItems(items, for: includeVideos)
        return items
    }

    private func applyCompletionState(to groups: [MediaGroup], completedIds: Set<String>) -> [MediaGroup] {
        groups.map { group in
            var updated = group
            updated.isCompleted = completedIds.contains(group.id)
            if !group.childGroups.isEmpty {
                updated.childGroups = applyCompletionState(to: group.childGroups, completedIds: completedIds)
                if case .monthCollection = group.type {
                    updated.isCompleted = !updated.childGroups.isEmpty && updated.childGroups.allSatisfy(\.isCompleted)
                }
            }
            return updated
        }
    }

    private static func cachedAllItems(for includeVideos: Bool) -> [MediaItem]? {
        cacheQueue.sync { cachedAllItems[includeVideos] }
    }

    private static func storeAllItems(_ items: [MediaItem], for includeVideos: Bool) {
        cacheQueue.async(flags: .barrier) {
            cachedAllItems[includeVideos] = items
        }
    }

    private static func cachedGroups(for key: GroupCacheKey) -> [MediaGroup]? {
        cacheQueue.sync { cachedGroups[key] }
    }

    private static func storeGroups(_ groups: [MediaGroup], for key: GroupCacheKey) {
        cacheQueue.async(flags: .barrier) {
            cachedGroups[key] = groups
        }
    }

    private static func cachedSmartCategories(for key: GroupCacheKey) -> [MediaGroup]? {
        cacheQueue.sync { cachedSmartCategories[key] }
    }

    private static func storeSmartCategories(_ groups: [MediaGroup], for key: GroupCacheKey) {
        cacheQueue.async(flags: .barrier) {
            cachedSmartCategories[key] = groups
        }
    }
}
