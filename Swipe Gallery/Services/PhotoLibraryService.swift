//
//  PhotoLibraryService.swift
//  Swipe Gallery
//
//  PhotoKit ile asset çekme: tarih aralığı ve video dahil/hariç filtreleri.
//

import Foundation
import Photos

final class PhotoLibraryService {
    /// İzin verilmiş veya sınırlı mı?
    var isAuthorized: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return status == .authorized || status == .limited
    }

    /// Photo Library erişim ister; izin verilene kadar bekler (async). Tamamlanma ana thread'de.
    func requestAuthorization() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited { return true }
        if status == .denied || status == .restricted { return false }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                let granted = newStatus == .authorized || newStatus == .limited
                DispatchQueue.main.async {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    /// Verilen tarih aralığındaki medyayı getirir. En yeni → en eski sıralı.
    /// - Parameters:
    ///   - dateRange: Filtre için tarih aralığı (nil ise tüm zamanlar)
    ///   - includeVideos: false ise sadece fotoğraflar
    func fetchAssets(
        dateRange: ClosedRange<Date>? = nil,
        includeVideos: Bool = false
    ) -> [MediaItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = predicate(dateRange: dateRange, includeVideos: includeVideos)

        let fetchResult = PHAsset.fetchAssets(with: options)
        return mediaItems(from: fetchResult)
    }

    func fetchAssets(localIdentifiers: [String]) -> [MediaItem] {
        guard !localIdentifiers.isEmpty else { return [] }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        let items = mediaItems(from: fetchResult)
        let order = Dictionary(uniqueKeysWithValues: localIdentifiers.enumerated().map { ($1, $0) })

        return items.sorted {
            (order[$0.id] ?? .max) < (order[$1.id] ?? .max)
        }
    }

    private func mediaItems(from fetchResult: PHFetchResult<PHAsset>) -> [MediaItem] {
        var list: [MediaItem] = []
        list.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            list.append(MediaItem(phAsset: asset))
        }
        return list
    }

    private func predicate(dateRange: ClosedRange<Date>?, includeVideos: Bool) -> NSPredicate? {
        var predicates: [NSPredicate] = []

        if !includeVideos {
            predicates.append(NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue))
        }

        if let range = dateRange {
            predicates.append(
                NSPredicate(
                    format: "creationDate >= %@ AND creationDate <= %@",
                    range.lowerBound as NSDate,
                    range.upperBound as NSDate
                )
            )
        }

        guard !predicates.isEmpty else { return nil }
        if predicates.count == 1 { return predicates[0] }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
