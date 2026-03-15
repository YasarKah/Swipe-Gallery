//
//  ImageLoaderService.swift
//  Swipe Gallery
//
//  Tek paylaşılan PHImageManager ile güvenli görsel yükleme (syscall çakışmasını azaltır).
//

import UIKit
import Photos

/// Uygulama genelinde tek bir image manager kullanır.
enum ImageLoaderService {
    private static let manager = PHCachingImageManager()

    static func loadImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFit,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .highQualityFormat,
        completion: @escaping (UIImage?) -> Void
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .exact

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { image, info in
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                return
            }
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                return
            }
            if let image {
                DispatchQueue.main.async { completion(image) }
                return
            }

            fallbackImage(for: asset) { fallback in
                DispatchQueue.main.async { completion(fallback) }
            }
        }
    }

    static func loadImageSynchronously(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFit,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .fastFormat
    ) -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        options.resizeMode = .exact

        var resultImage: UIImage?

        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: options
        ) { image, info in
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                return
            }
            if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                return
            }
            resultImage = image
        }

        if resultImage == nil {
            resultImage = fallbackImageSynchronously(for: asset)
        }

        return resultImage
    }

    static func loadLivePhoto(
        for asset: PHAsset,
        targetSize: CGSize,
        completion: @escaping (PHLivePhoto?) -> Void
    ) {
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        manager.requestLivePhoto(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { livePhoto, _ in
            DispatchQueue.main.async { completion(livePhoto) }
        }
    }

    private static func fallbackImage(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            completion(data.flatMap(UIImage.init(data:)))
        }
    }

    private static func fallbackImageSynchronously(for asset: PHAsset) -> UIImage? {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = true

        var result: UIImage?
        manager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
            result = data.flatMap(UIImage.init(data:))
        }
        return result
    }
}
