//
//  MediaItem.swift
//  Swipe Gallery
//
//  Tek bir fotoğraf veya video öğesi. PhotoKit PHAsset sarmalayıcısı.
//

import Foundation
import Photos

/// Uygulama katmanında kullanılan medya öğesi
struct MediaItem: Identifiable, Hashable {
    let id: String
    let phAsset: PHAsset
    let creationDate: Date?
    let isVideo: Bool
    /// Canlı fotoğraf (Live Photo) mı
    let isLivePhoto: Bool
    let isScreenshot: Bool

    init(phAsset: PHAsset) {
        self.id = phAsset.localIdentifier
        self.phAsset = phAsset
        self.creationDate = phAsset.creationDate
        self.isVideo = phAsset.mediaType == .video
        self.isLivePhoto = phAsset.mediaSubtypes.contains(.photoLive)
        self.isScreenshot = phAsset.mediaSubtypes.contains(.photoScreenshot)
    }

    var displayAspectRatio: CGFloat {
        let width = max(CGFloat(phAsset.pixelWidth), 1)
        let height = max(CGFloat(phAsset.pixelHeight), 1)
        return min(max(width / height, 0.35), 2.5)
    }

    func fittedSize(in boundingSize: CGSize) -> CGSize {
        guard boundingSize.width > 0, boundingSize.height > 0 else { return .zero }

        let containerAspectRatio = boundingSize.width / boundingSize.height
        if displayAspectRatio > containerAspectRatio {
            return CGSize(
                width: boundingSize.width,
                height: boundingSize.width / displayAspectRatio
            )
        } else {
            return CGSize(
                width: boundingSize.height * displayAspectRatio,
                height: boundingSize.height
            )
        }
    }
}
