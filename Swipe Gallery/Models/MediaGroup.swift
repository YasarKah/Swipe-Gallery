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
    static let backgroundTop = Color(red: 0.07, green: 0.09, blue: 0.18)
    static let backgroundBottom = Color(red: 0.11, green: 0.08, blue: 0.22)
    static let backgroundLiftTop = Color(red: 0.16, green: 0.21, blue: 0.33)
    static let backgroundLiftBottom = Color(red: 0.18, green: 0.14, blue: 0.34)
    static let cardBase = Color(red: 0.10, green: 0.12, blue: 0.20)
    static let surface = Color.white.opacity(0.10)
    static let border = Color.white.opacity(0.12)
    static let softBorder = Color.white.opacity(0.05)
    static let accentBlue = Color(red: 0.33, green: 0.56, blue: 0.98)
    static let accentPurple = Color(red: 0.54, green: 0.37, blue: 0.95)
    static let accentPink = Color(red: 0.84, green: 0.41, blue: 0.87)
    static let success = Color(red: 0.31, green: 0.82, blue: 0.63)
    static let danger = Color(red: 0.98, green: 0.40, blue: 0.51)
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
        case .turkish: return "Turkce"
        case .english: return "English"
        }
    }
}

final class AppPreferences: ObservableObject {
    private let languageKey = "appPreferences.language"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: languageKey)
        language = AppLanguage(rawValue: saved ?? "") ?? .turkish
    }

    func text(_ key: AppTextKey) -> String {
        AppText.value(for: key, language: language)
    }

    func format(_ key: AppTextKey, _ args: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: args)
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
}

enum AppText {
    static func value(for key: AppTextKey, language: AppLanguage) -> String {
        switch language {
        case .turkish:
            switch key {
            case .appTitle: return "GalleryCleaner"
            case .loadingGallery: return "Galeri yukleniyor..."
            case .accessRequired: return "Erisim gerekli"
            case .noPhotosFound: return "Fotograf bulunamadi"
            case .noPhotosDescription: return "Galeri erisimi verilmedi veya secilen fotograf yok. Ayarlar'dan uygulama icin Fotograflar erisimini acin."
            case .groupsTitle: return "Temizlik gruplari"
            case .resumeTitle: return "Devam etmek ister misin?"
            case .resumeMessage: return "Bu tarihte daha once yarim kalmissin. Kaldigin yerden devam edebilir ya da basa donebilirsin."
            case .continueFromWhereLeft: return "Kaldigin yerden devam et"
            case .restartFromBeginning: return "Bastan basla"
            case .cancel: return "Iptal"
            case .settings: return "Ayarlar"
            case .settingsDescription: return "Temizlik akisini ve uygulama dilini buradan yonetebilirsin."
            case .includeVideos: return "Videolari dahil et"
            case .includeVideosDescription: return "Gruplar fotograf ve videolari birlikte gostersin"
            case .language: return "Dil"
            case .languageDescription: return "Uygulama metinlerini degistir"
            case .sort: return "Siralama"
            case .sortNewestFirst: return "Yeniden eskiye"
            case .sortOldestFirst: return "Eskiden yeniye"
            case .sortLargestFirst: return "Buyukten kucuge"
            case .sortSmallestFirst: return "Kucukten buyuge"
            case .loading: return "Yukleniyor..."
            case .noMedia: return "Medya yok"
            case .noMediaDescription: return "Bu grupta fotograf veya video bulunamadi."
            case .exitPromptTitle: return "Cikmak istiyor musun?"
            case .exitPromptMessage: return "Istersen kaldigin yeri saklayabilir, yaptigin silme secimlerini hemen uygulayabilir ya da hicbir seyi kaydetmeden cikabilirsin."
            case .saveAndExit: return "Kaydet ve cik"
            case .exitWithoutSaving: return "Kaydetmeden cik"
            case .deleteNow: return "Sil"
            case .keep: return "Tut"
            case .delete: return "Sil"
            case .live: return "Canli"
            case .finalReview: return "Son kontrol"
            case .close: return "Kapat"
            case .noItemsToDelete: return "Silinecek oge yok"
            case .noItemsToDeleteDescription: return "Tum fotograflari tuttun veya listeden cikardin."
            case .deletingCountFormat: return "%d oge silinecek"
            case .deletedCountFormat: return "Silinen: %d"
            case .viewedPercentFormat: return "Goruntulenen: %% %d"
            case .deleteAllFormat: return "Hepsini sil (%d)"
            case .deleting: return "Siliniyor..."
            case .error: return "Hata"
            case .ok: return "Tamam"
            case .deleteFailedFormat: return "Silme basarisiz: %@"
            case .smartDescription: return "Smart alani benzer cekimleri, ekran goruntulerini ve zayif kareleri senin icin ayirir. En hizli temizlik akisi icin once buradan baslayabilirsin."
            case .monthCollectionDescription: return "Bu grupta daha az fotograftan olusan aylar birlikte tutulur. Icine girince aylari tek tek inceleyebilirsin."
            case .similarDescription: return "Bu bolumde birbirine cok benzeyen kareler bir araya getirilir. Genelde ayni anin tekrarlarini hizlica azaltmak icin en iyi alan burasi."
            case .allSimilar: return "Tum benzerler"
            case .screenshotsTitle: return "Ekran Goruntuleri"
            case .blurryTitle: return "Bulaniklar"
            case .smartTitle: return "Smart"
            case .todayTitle: return "Bugun"
            case .recentTitle: return "Son eklenenler"
            case .randomTitle: return "Rastgele"
            case .smallMonthsTitle: return "Daha az fotografli aylar"
            case .similarTitle: return "Benzerler"
            case .quickCleanup: return "hizli temizlik"
            case .weakFrames: return "zayif kareler"
            case .monthCountFormat: return "🗂️ %d ay"
            case .groupCountFormat: return "✨ %d grup"
            case .clusterCountFormat: return "🧠 %d kume"
            case .allSimilarsCountFormat: return "📚 %d benzer"
            case .guidedCleanupTitle: return "Guided Cleanup"
            case .guidedCleanupHomeTitle: return "Guided Cleanup"
            case .guidedCleanupHomeSubtitle: return "Nereden baslayacagini sistem secsin"
            case .guidedCleanupHomeDetail: return "En yeni aydan eski yillara dogru ilerleyen rehberli bir akisla daha az dusunerek daha hizli temizlik yap."
            case .guidedCleanupDescription: return "Bu alan galerini yakindan eskiye dogru mantikli adimlara ayirir. Her adimda neden buradan baslaman gerektigini gorebilir, aylara inip tek tek temizleyebilirsin."
            case .guidedRecentMonthsTitle: return "Son aylar"
            case .guidedRecentMonthsSubtitle: return "En yeni karmasa"
            case .guidedRecentMonthsDetail: return "Hatirasi en taze olan tekrarlar genelde burada birikir. Ilk olarak son aylari temizlemek karar vermeyi kolaylastirir."
            case .guidedCurrentYearTitle: return "Bu yilin geri kalani"
            case .guidedCurrentYearSubtitle: return "Yila hizlica toparlan"
            case .guidedCurrentYearDetail: return "Son aylardan sonra bu yilin diger aylarini tek tek gecerek galerini temiz bir cizgiye getirebilirsin."
            case .guidedLastYearTitle: return "Gecen yil"
            case .guidedLastYearSubtitle: return "Artik daha kolay vedalasabilecegin kareler"
            case .guidedLastYearDetail: return "Bir yil onceki fotograflarda gereksiz tekrarlar daha net gorunur. Aylara ayrilmis akista guvenli ilerleyebilirsin."
            case .guidedOlderYearsTitle: return "Daha eski yillar"
            case .guidedOlderYearsSubtitle: return "Arsivi parcalara ayir"
            case .guidedOlderYearsDetail: return "Eski arsivi once yillara, sonra aylara bolmek buyuk galerilerde bunalmayi azaltir."
            case .guidedYearTitleFormat: return "%d"
            case .guidedYearSubtitle: return "Bir yili ay ay temizle"
            case .guidedYearDetailFormat: return "Bu yilda %d ay var. Ilerledikce eski arsiv daha yonetilebilir hale gelir."
            case .guidedCurrentMonthSubtitle: return "Su an cektiklerin"
            case .guidedMonthSubtitle: return "Tek ay odagi"
            case .guidedMonthDetailPhotosFormat: return "%d fotograf iceren tek bir ay. Dikkatin dagilmadan temizleyebilirsin."
            case .guidedMonthDetailWithVideosFormat: return "%d fotograf ve %d video iceren tek bir ay. Kararlari bolmeden ilerleyebilirsin."
            case .undo: return "Geri al"
            case .info: return "Fotograf Bilgileri"
            case .photoInfoDescription: return "Bu ekranda fotografa ait teknik detaylari gorebilirsin."
            case .featureUnavailable: return "Bu ozellik kullanilamiyor"
            case .featureUnavailableDescription: return "Bu fotografin acilabilecek ekstra bir ozelligi bulunamadi."
            case .preparingLivePhoto: return "Canli fotograf hazirlaniyor..."
            case .status: return "Durum"
            case .unknown: return "Bilinmiyor"
            case .type: return "Tur"
            case .size: return "Boyut"
            case .fileExtension: return "Uzanti"
            case .file: return "Dosya"
            case .resolution: return "Cozunurluk"
            case .duration: return "Sure"
            case .date: return "Tarih"
            case .location: return "Konum"
            case .photo: return "Fotograf"
            case .livePhotoType: return "Canli Fotograf"
            case .remove: return "Geri al"
            }
        case .english:
            switch key {
            case .appTitle: return "GalleryCleaner"
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
            }
        }
    }
}
