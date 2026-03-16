//
//  MediaGroup.swift
//  Swipe Gallery
//
//  Galeri gruplarını temsil eden model (Bugün, Son Eklenenler, Rastgele, Ay grupları).
//

import Foundation
import SwiftUI

/// Grup türü: özel kategoriler veya ay bazlı
enum SmartCategoryKind: Hashable {
    case similar
    case screenshots
    case blurry
}

enum MediaGroupType: Hashable {
    case smart
    case smartCategory(SmartCategoryKind)
    case smartCluster
    case today
    case recent
    case random
    case month(year: Int, month: Int)
    case monthCollection
}

/// Ana ekranda gösterilen medya grubu kartı
struct MediaGroup: Identifiable, Hashable {
    let id: String
    let title: String
    let dateRange: ClosedRange<Date>?
    let type: MediaGroupType
    var assetIdentifiers: [String]
    var isCompleted: Bool
    var childGroups: [MediaGroup]
    /// Sadece fotoğraf sayısı (video hariç)
    var photoCount: Int
    /// Video sayısı (toggle açıkken anlamlı)
    var videoCount: Int

    init(
        id: String,
        title: String,
        dateRange: ClosedRange<Date>? = nil,
        type: MediaGroupType,
        assetIdentifiers: [String] = [],
        isCompleted: Bool = false,
        childGroups: [MediaGroup] = [],
        photoCount: Int = 0,
        videoCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.dateRange = dateRange
        self.type = type
        self.assetIdentifiers = assetIdentifiers
        self.isCompleted = isCompleted
        self.childGroups = childGroups
        self.photoCount = photoCount
        self.videoCount = videoCount
    }
}

enum AppPalette {
    static let backgroundTop = Color(red: 0.04, green: 0.06, blue: 0.14)
    static let backgroundBottom = Color(red: 0.08, green: 0.07, blue: 0.19)
    static let backgroundLiftTop = Color(red: 0.12, green: 0.16, blue: 0.28)
    static let backgroundLiftBottom = Color(red: 0.14, green: 0.11, blue: 0.28)
    static let cardBase = Color(red: 0.10, green: 0.12, blue: 0.22)
    static let surface = Color.white.opacity(0.08)
    static let glassSurface = Color(red: 0.16, green: 0.20, blue: 0.34).opacity(0.44)
    static let glassSurfaceStrong = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.12)
    static let glassBorder = Color.white.opacity(0.18)
    static let glassHighlight = Color.white.opacity(0.34)
    static let softBorder = Color.white.opacity(0.05)
    static let accentBlue = Color(red: 0.35, green: 0.61, blue: 1.00)
    static let accentPurple = Color(red: 0.59, green: 0.42, blue: 0.99)
    static let accentPink = Color(red: 0.82, green: 0.45, blue: 0.93)
    static let neonBlueGlow = Color(red: 0.42, green: 0.73, blue: 1.00)
    static let neonPurpleGlow = Color(red: 0.67, green: 0.51, blue: 1.00)
    static let success = Color(red: 0.31, green: 0.82, blue: 0.63)
    static let danger = Color(red: 0.99, green: 0.42, blue: 0.58)
    static let shadowDeep = Color.black.opacity(0.28)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.76)
    static let textMuted = Color.white.opacity(0.60)
    static let defaultCardAspectRatio: CGFloat = 3 / 4

    static let rowColors: [Color] = [
        accentBlue,
        accentPurple,
        accentPink,
        Color(red: 0.25, green: 0.69, blue: 0.94),
        Color(red: 0.39, green: 0.46, blue: 0.98),
        Color(red: 0.33, green: 0.75, blue: 0.83),
    ]
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .turkish: return "tr_TR"
        case .english: return "en_US"
        }
    }

    var displayName: String {
        switch self {
        case .turkish: return "Türkçe"
        case .english: return "English"
        }
    }
}

final class AppPreferences: ObservableObject {
    private let repository: PreferencesSnapshotRepository
    var onSnapshotChanged: ((PreferencesSnapshot) -> Void)?

    @Published var language: AppLanguage {
        didSet {
            persist()
        }
    }

    init(repository: PreferencesSnapshotRepository = LocalPreferencesRepository()) {
        self.repository = repository
        let snapshot = repository.loadSnapshot()
        language = snapshot.language
    }

    func text(_ key: AppTextKey) -> String {
        AppText.value(for: key, language: language)
    }

    func format(_ key: AppTextKey, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: args)
    }

    func snapshot(
        sourceBundleIdentifier: String = Bundle.main.bundleIdentifier ?? AppMigrationConfig.currentBundleIdentifier
    ) -> PreferencesSnapshot {
        PreferencesSnapshot(
            languageCode: language.rawValue,
            updatedAt: Date(),
            sourceBundleIdentifier: sourceBundleIdentifier,
            migrationVersion: AppMigrationConfig.migrationVersion
        )
    }

    func replace(with snapshot: PreferencesSnapshot, notify: Bool = true) {
        language = snapshot.language
        repository.saveSnapshot(snapshot)
        if notify {
            onSnapshotChanged?(self.snapshot())
        }
    }

    private func persist() {
        let currentSnapshot = snapshot()
        repository.saveSnapshot(currentSnapshot)
        onSnapshotChanged?(currentSnapshot)
    }
}

enum AppTextKey {
    case appTitle
    case loadingGallery
    case accessRequired
    case noPhotosFound
    case noPhotosDescription
    case groupsTitle
    case resumeTitle
    case resumeMessage
    case continueFromWhereLeft
    case restartFromBeginning
    case cancel
    case settings
    case settingsDescription
    case includeVideos
    case includeVideosDescription
    case language
    case languageDescription
    case legal
    case legalDescription
    case privacyPolicy
    case termsOfUse
    case support
    case supportDescription
    case sort
    case sortNewestFirst
    case sortOldestFirst
    case sortLargestFirst
    case sortSmallestFirst
    case loading
    case noMedia
    case noMediaDescription
    case exitPromptTitle
    case exitPromptMessage
    case saveAndExit
    case exitWithoutSaving
    case deleteNow
    case keep
    case delete
    case live
    case finalReview
    case close
    case noItemsToDelete
    case noItemsToDeleteDescription
    case deletingCountFormat
    case deletedCountFormat
    case viewedPercentFormat
    case deleteAllFormat
    case deleting
    case error
    case ok
    case deleteFailedFormat
    case smartDescription
    case monthCollectionDescription
    case similarDescription
    case allSimilar
    case screenshotsTitle
    case blurryTitle
    case smartTitle
    case todayTitle
    case recentTitle
    case randomTitle
    case smallMonthsTitle
    case similarTitle
    case quickCleanup
    case weakFrames
    case monthCountFormat
    case groupCountFormat
    case clusterCountFormat
    case allSimilarsCountFormat
    case guidedCleanupTitle
    case guidedCleanupHomeTitle
    case guidedCleanupHomeSubtitle
    case guidedCleanupHomeDetail
    case guidedCleanupDescription
    case guidedCleanupAllCaughtUp
    case guidedRecentMonthsTitle
    case guidedRecentMonthsSubtitle
    case guidedRecentMonthsDetail
    case guidedCurrentYearTitle
    case guidedCurrentYearSubtitle
    case guidedCurrentYearDetail
    case guidedLastYearTitle
    case guidedLastYearSubtitle
    case guidedLastYearDetail
    case guidedOlderYearsTitle
    case guidedOlderYearsSubtitle
    case guidedOlderYearsDetail
    case guidedYearTitleFormat
    case guidedYearSubtitle
    case guidedYearDetailFormat
    case guidedCurrentMonthSubtitle
    case guidedMonthSubtitle
    case guidedMonthDetailPhotosFormat
    case guidedMonthDetailWithVideosFormat
    case guidedStepCountFormat
    case undo
    case info
    case photoInfoDescription
    case featureUnavailable
    case featureUnavailableDescription
    case preparingLivePhoto
    case status
    case unknown
    case type
    case size
    case fileExtension
    case file
    case resolution
    case duration
    case date
    case location
    case photo
    case livePhotoType
    case remove
    case completed
}

enum AppText {
    static func value(for key: AppTextKey, language: AppLanguage) -> String {
        switch language {
        case .turkish:
            switch key {
            case .appTitle: return "Smart Swipe"
            case .loadingGallery: return "Galeri yükleniyor..."
            case .accessRequired: return "Erişim gerekli"
            case .noPhotosFound: return "Fotoğraf bulunamadı"
            case .noPhotosDescription: return "Galeri erişimi verilmedi veya seçilen fotoğraf yok. Ayarlar'dan uygulama için Fotoğraflar erişimini açın."
            case .groupsTitle: return "Temizlik grupları"
            case .resumeTitle: return "Devam etmek ister misin?"
            case .resumeMessage: return "Bu tarihte daha önce yarım kalmışsın. Kaldığın yerden devam edebilir ya da başa dönebilirsin."
            case .continueFromWhereLeft: return "Kaldığın yerden devam et"
            case .restartFromBeginning: return "Baştan başla"
            case .cancel: return "İptal"
            case .settings: return "Ayarlar"
            case .settingsDescription: return "Temizlik akışını ve uygulama dilini buradan yönetebilirsin."
            case .includeVideos: return "Videoları dahil et"
            case .includeVideosDescription: return "Gruplar fotoğraf ve videoları birlikte göstersin"
            case .language: return "Dil"
            case .languageDescription: return "Uygulama metinlerini değiştir"
            case .legal: return "Yasal ve Destek"
            case .legalDescription: return "Gizlilik politikası, kullanım şartları ve destek sayfasına buradan ulaşabilirsin."
            case .privacyPolicy: return "Gizlilik Politikası"
            case .termsOfUse: return "Kullanım Şartları"
            case .support: return "Destek"
            case .supportDescription: return "Sorular, geri bildirimler ve yayın bağlantıları için destek sayfasını aç."
            case .sort: return "Sıralama"
            case .sortNewestFirst: return "Yeniden eskiye"
            case .sortOldestFirst: return "Eskiden yeniye"
            case .sortLargestFirst: return "Büyükten küçüğe"
            case .sortSmallestFirst: return "Küçükten büyüğe"
            case .loading: return "Yükleniyor..."
            case .noMedia: return "Medya yok"
            case .noMediaDescription: return "Bu grupta fotoğraf veya video bulunamadı."
            case .exitPromptTitle: return "Çıkmak istiyor musun?"
            case .exitPromptMessage: return "İstersen kaldığın yeri saklayabilir, yaptığın silme seçimlerini hemen uygulayabilir ya da hiçbir şeyi kaydetmeden çıkabilirsin."
            case .saveAndExit: return "Kaydet ve çık"
            case .exitWithoutSaving: return "Kaydetmeden çık"
            case .deleteNow: return "Sil"
            case .keep: return "Tut"
            case .delete: return "Sil"
            case .live: return "Canlı"
            case .finalReview: return "Son Kontrol"
            case .close: return "Kapat"
            case .noItemsToDelete: return "Silinecek öğe yok"
            case .noItemsToDeleteDescription: return "Tüm fotoğrafları tuttun veya listeden çıkardın."
            case .deletingCountFormat: return "%d öğe silinecek"
            case .deletedCountFormat: return "Silinen: %d"
            case .viewedPercentFormat: return "Görüntülenen: %% %d"
            case .deleteAllFormat: return "Hepsini sil (%d)"
            case .deleting: return "Siliniyor..."
            case .error: return "Hata"
            case .ok: return "Tamam"
            case .deleteFailedFormat: return "Silme başarısız: %@"
            case .smartDescription: return "Smart alanı benzer çekimleri, ekran görüntülerini ve zayıf kareleri senin için ayırır. En hızlı temizlik akışı için önce buradan başlayabilirsin."
            case .monthCollectionDescription: return "Bu grupta daha az fotoğraftan oluşan aylar birlikte tutulur. İçine girince ayları tek tek inceleyebilirsin."
            case .similarDescription: return "Bu bölümde birbirine çok benzeyen kareler bir araya getirilir. Genelde aynı anın tekrarlarını hızlıca azaltmak için en iyi alan burası."
            case .allSimilar: return "Tüm benzerler"
            case .screenshotsTitle: return "Ekran Görüntüleri"
            case .blurryTitle: return "Bulanıklar"
            case .smartTitle: return "Smart"
            case .todayTitle: return "Bugün"
            case .recentTitle: return "Son eklenenler"
            case .randomTitle: return "Rastgele"
            case .smallMonthsTitle: return "Daha az fotoğraflı aylar"
            case .similarTitle: return "Benzerler"
            case .quickCleanup: return "hızlı temizlik"
            case .weakFrames: return "zayıf kareler"
            case .monthCountFormat: return "🗂️ %d ay"
            case .groupCountFormat: return "✨ %d grup"
            case .clusterCountFormat: return "🧠 %d küme"
            case .allSimilarsCountFormat: return "📚 %d benzer"
            case .guidedCleanupTitle: return "Guided Cleanup"
            case .guidedCleanupHomeTitle: return "Guided Cleanup"
            case .guidedCleanupHomeSubtitle: return "Nereden başlayacağını sistem seçsin"
            case .guidedCleanupHomeDetail: return "En yeni aydan eski yıllara doğru ilerleyen rehberli bir akışla daha az düşünerek daha hızlı temizlik yap."
            case .guidedCleanupDescription: return "Bu alan galerini yakından eskiye doğru mantıklı adımlara ayırır. Her adımda neden buradan başlaman gerektiğini görebilir, aylara inip tek tek temizleyebilirsin."
            case .guidedCleanupAllCaughtUp: return "Rehberli temizlikte önerilecek yeni bir tarih kalmadı. İstersen normal gruplardan devam edebilirsin."
            case .guidedRecentMonthsTitle: return "Son aylar"
            case .guidedRecentMonthsSubtitle: return "En yeni karmaşa"
            case .guidedRecentMonthsDetail: return "Hatırası en taze olan tekrarlar genelde burada birikir. İlk olarak son ayları temizlemek karar vermeyi kolaylaştırır."
            case .guidedCurrentYearTitle: return "Bu yılın geri kalanı"
            case .guidedCurrentYearSubtitle: return "Yılı hızlıca toparla"
            case .guidedCurrentYearDetail: return "Son aylardan sonra bu yılın diğer aylarını tek tek geçerek galerini temiz bir çizgiye getirebilirsin."
            case .guidedLastYearTitle: return "Geçen yıl"
            case .guidedLastYearSubtitle: return "Artık daha kolay vedalaşabileceğin kareler"
            case .guidedLastYearDetail: return "Bir yıl önceki fotoğraflarda gereksiz tekrarlar daha net görünür. Aylara ayrılmış akışta güvenli ilerleyebilirsin."
            case .guidedOlderYearsTitle: return "Daha eski yıllar"
            case .guidedOlderYearsSubtitle: return "Arşivi parçalara ayır"
            case .guidedOlderYearsDetail: return "Eski arşivi önce yıllara, sonra aylara bölmek büyük galerilerde bunalmayı azaltır."
            case .guidedYearTitleFormat: return "%d"
            case .guidedYearSubtitle: return "Bir yılı ay ay temizle"
            case .guidedYearDetailFormat: return "Bu yılda %d ay var. İlerledikçe eski arşiv daha yönetilebilir hâle gelir."
            case .guidedCurrentMonthSubtitle: return "Şu an çektiklerin"
            case .guidedMonthSubtitle: return "Tek ay odağı"
            case .guidedMonthDetailPhotosFormat: return "%d fotoğraf içeren tek bir ay. Dikkatin dağılmadan temizleyebilirsin."
            case .guidedMonthDetailWithVideosFormat: return "%d fotoğraf ve %d video içeren tek bir ay. Kararları bölmeden ilerleyebilirsin."
            case .guidedStepCountFormat: return "🪜 %d adım"
            case .undo: return "Geri al"
            case .info: return "Fotoğraf Bilgileri"
            case .photoInfoDescription: return "Bu ekranda fotoğrafa ait teknik detayları görebilirsin."
            case .featureUnavailable: return "Bu özellik kullanılamıyor"
            case .featureUnavailableDescription: return "Bu fotoğrafın açılabilecek ekstra bir özelliği bulunamadı."
            case .preparingLivePhoto: return "Canlı fotoğraf hazırlanıyor..."
            case .status: return "Durum"
            case .unknown: return "Bilinmiyor"
            case .type: return "Tür"
            case .size: return "Boyut"
            case .fileExtension: return "Uzantı"
            case .file: return "Dosya"
            case .resolution: return "Çözünürlük"
            case .duration: return "Süre"
            case .date: return "Tarih"
            case .location: return "Konum"
            case .photo: return "Fotoğraf"
            case .livePhotoType: return "Canlı Fotoğraf"
            case .remove: return "Geri al"
            case .completed: return "Tamamlandı"
            }
        case .english:
            switch key {
            case .appTitle: return "Smart Swipe"
            case .loadingGallery: return "Loading your library..."
            case .accessRequired: return "Access required"
            case .noPhotosFound: return "No photos found"
            case .noPhotosDescription: return "Photo access is missing or there are no matching items. Enable Photos access for the app in Settings."
            case .groupsTitle: return "Cleanup groups"
            case .resumeTitle: return "Resume where you left off?"
            case .resumeMessage: return "You already started this group before. You can continue from the saved position or restart from the beginning."
            case .continueFromWhereLeft: return "Continue"
            case .restartFromBeginning: return "Start over"
            case .cancel: return "Cancel"
            case .settings: return "Settings"
            case .settingsDescription: return "Control cleanup behavior and app language here."
            case .includeVideos: return "Include videos"
            case .includeVideosDescription: return "Show photos and videos together in groups"
            case .language: return "Language"
            case .languageDescription: return "Change the app language"
            case .legal: return "Legal & Support"
            case .legalDescription: return "Open the privacy policy, terms of use, and support page from here."
            case .privacyPolicy: return "Privacy Policy"
            case .termsOfUse: return "Terms of Use"
            case .support: return "Support"
            case .supportDescription: return "Open the support page for questions, feedback, and publication links."
            case .sort: return "Sort"
            case .sortNewestFirst: return "Newest to oldest"
            case .sortOldestFirst: return "Oldest to newest"
            case .sortLargestFirst: return "Largest to smallest"
            case .sortSmallestFirst: return "Smallest to largest"
            case .loading: return "Loading..."
            case .noMedia: return "No media"
            case .noMediaDescription: return "No photos or videos were found in this group."
            case .exitPromptTitle: return "Leave this screen?"
            case .exitPromptMessage: return "You can save your progress, apply your delete choices now, or leave without saving anything."
            case .saveAndExit: return "Save and leave"
            case .exitWithoutSaving: return "Leave without saving"
            case .deleteNow: return "Delete now"
            case .keep: return "Keep"
            case .delete: return "Delete"
            case .live: return "Live"
            case .finalReview: return "Final review"
            case .close: return "Close"
            case .noItemsToDelete: return "Nothing to delete"
            case .noItemsToDeleteDescription: return "You kept everything or removed all items from the queue."
            case .deletingCountFormat: return "%d items ready to delete"
            case .deletedCountFormat: return "Deleted: %d"
            case .viewedPercentFormat: return "Viewed: %% %d"
            case .deleteAllFormat: return "Delete all (%d)"
            case .deleting: return "Deleting..."
            case .error: return "Error"
            case .ok: return "OK"
            case .deleteFailedFormat: return "Delete failed: %@"
            case .smartDescription: return "Smart separates similar shots, screenshots, and weak frames for you. Start here for the fastest cleanup flow."
            case .monthCollectionDescription: return "Months with fewer photos are grouped together here. Open the group to keep reviewing each month one by one."
            case .similarDescription: return "This section groups very similar shots together. It is the best place to quickly trim repeated moments."
            case .allSimilar: return "All similars"
            case .screenshotsTitle: return "Screenshots"
            case .blurryTitle: return "Blurry shots"
            case .smartTitle: return "Smart"
            case .todayTitle: return "Today"
            case .recentTitle: return "Recently added"
            case .randomTitle: return "Random"
            case .smallMonthsTitle: return "Smaller months"
            case .similarTitle: return "Similars"
            case .quickCleanup: return "quick cleanup"
            case .weakFrames: return "weak frames"
            case .monthCountFormat: return "🗂️ %d months"
            case .groupCountFormat: return "✨ %d groups"
            case .clusterCountFormat: return "🧠 %d clusters"
            case .allSimilarsCountFormat: return "📚 %d similar"
            case .guidedCleanupTitle: return "Guided Cleanup"
            case .guidedCleanupHomeTitle: return "Guided Cleanup"
            case .guidedCleanupHomeSubtitle: return "Let the app choose where to start"
            case .guidedCleanupHomeDetail: return "Move from recent months into older years with a guided flow that reduces decision fatigue and helps you clean faster."
            case .guidedCleanupDescription: return "This area breaks your library into sensible steps from recent to old. Each step explains why it matters, then lets you drill down month by month."
            case .guidedCleanupAllCaughtUp: return "There are no new guided date suggestions left right now. You can continue from the regular cleanup groups if you want."
            case .guidedRecentMonthsTitle: return "Recent months"
            case .guidedRecentMonthsSubtitle: return "Newest clutter first"
            case .guidedRecentMonthsDetail: return "The easiest decisions are usually in your freshest months. Start here to trim repeats while the moments still feel familiar."
            case .guidedCurrentYearTitle: return "Rest of this year"
            case .guidedCurrentYearSubtitle: return "Tighten up the current year"
            case .guidedCurrentYearDetail: return "After the recent months, keep going through the rest of this year one month at a time to quickly restore order."
            case .guidedLastYearTitle: return "Last year"
            case .guidedLastYearSubtitle: return "Cleaner choices with more distance"
            case .guidedLastYearDetail: return "Older duplicates stand out more clearly after a year. This step keeps the cleanup focused and safe."
            case .guidedOlderYearsTitle: return "Older years"
            case .guidedOlderYearsSubtitle: return "Break the archive down"
            case .guidedOlderYearsDetail: return "Splitting the archive into years and then months makes very large libraries feel far less overwhelming."
            case .guidedYearTitleFormat: return "%d"
            case .guidedYearSubtitle: return "Review this year month by month"
            case .guidedYearDetailFormat: return "This year contains %d months. Smaller steps keep deep archive cleanup manageable."
            case .guidedCurrentMonthSubtitle: return "What you captured lately"
            case .guidedMonthSubtitle: return "Single month focus"
            case .guidedMonthDetailPhotosFormat: return "A single month with %d photos so you can clean without splitting your attention."
            case .guidedMonthDetailWithVideosFormat: return "A single month with %d photos and %d videos so you can clean without splitting your attention."
            case .guidedStepCountFormat: return "🪜 %d steps"
            case .undo: return "Undo"
            case .info: return "Photo Info"
            case .photoInfoDescription: return "You can see technical details about this photo on this screen."
            case .featureUnavailable: return "This feature is unavailable"
            case .featureUnavailableDescription: return "There is no extra interactive feature available for this photo."
            case .preparingLivePhoto: return "Preparing Live Photo..."
            case .status: return "Status"
            case .unknown: return "Unknown"
            case .type: return "Type"
            case .size: return "Size"
            case .fileExtension: return "Extension"
            case .file: return "File"
            case .resolution: return "Resolution"
            case .duration: return "Duration"
            case .date: return "Date"
            case .location: return "Location"
            case .photo: return "Photo"
            case .livePhotoType: return "Live Photo"
            case .remove: return "Restore"
            case .completed: return "Completed"
            }
        }
    }
}
