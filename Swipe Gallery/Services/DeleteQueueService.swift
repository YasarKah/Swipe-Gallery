//
//  DeleteQueueService.swift
//  Swipe Gallery
//
//  Silinecek fotoğrafları tutar. Silme işlemi hemen yapılmaz; ReviewDeleteView'da onaylanır.
//

import Foundation
import Photos

/// Silinecek medya kuyruğu. ObservableObject ile UI güncellemesi.
final class DeleteQueueService: ObservableObject {
    @Published private(set) var items: [MediaItem] = []

    func add(_ item: MediaItem) {
        guard !items.contains(where: { $0.id == item.id }) else { return }
        items.append(item)
    }

    func remove(_ item: MediaItem) {
        items.removeAll { $0.id == item.id }
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
    }

    func clear() {
        items.removeAll()
    }

    /// PhotoKit ile kuyruktaki tüm öğeleri siler. performChanges kullanır.
    func deleteAll() async throws {
        let assetsToDelete = items.map(\.phAsset)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "DeleteQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: "Silme başarısız"]))
                    }
                }
            }
        }
        await MainActor.run { clear() }
    }
}
