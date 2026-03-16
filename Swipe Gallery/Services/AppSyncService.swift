import CloudKit
import Combine
import Foundation
import AuthenticationServices

enum AppMigrationConfig {
    static let migrationVersion = 1
    static let currentBundleIdentifier = "com.yasarkah.smartswipe"
    static let legacyBundleIdentifier = "yasarkah.Swipe-Gallery"
    static let sharedAppGroupIdentifier = "group.com.yasarkah.smartswipe.shared"
    static let cloudContainerIdentifier = "iCloud.com.yasarkah.smartswipe"
    static let appGroupPayloadKey = "migration.shared.payload"

    static var isLegacyExporterBuild: Bool {
        Bundle.main.bundleIdentifier == legacyBundleIdentifier
    }
}

struct ProgressSnapshot: Codable, Equatable {
    var completedGroupIds: Set<String>
    var groupProgress: [String: GroupProgress]
    var updatedAt: Date
    var sourceBundleIdentifier: String
    var migrationVersion: Int

    var hasContent: Bool {
        !completedGroupIds.isEmpty || !groupProgress.isEmpty
    }
}

struct PreferencesSnapshot: Codable, Equatable {
    var languageCode: String
    var updatedAt: Date
    var sourceBundleIdentifier: String
    var migrationVersion: Int

    var language: AppLanguage {
        get { AppLanguage(rawValue: languageCode) ?? .turkish }
        set { languageCode = newValue.rawValue }
    }
}

struct MigrationPayload: Codable, Equatable {
    var progress: ProgressSnapshot
    var preferences: PreferencesSnapshot
    var exportedAt: Date
    var sourceBundleIdentifier: String
    var appleUserID: String?

    var hasContent: Bool {
        progress.hasContent
    }
}

protocol PreferencesSnapshotRepository {
    func loadSnapshot() -> PreferencesSnapshot
    func saveSnapshot(_ snapshot: PreferencesSnapshot)
}

final class LocalPreferencesRepository: PreferencesSnapshotRepository {
    static let languageKey = "appPreferences.language"
    static let languageUpdatedAtKey = "appPreferences.languageUpdatedAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSnapshot() -> PreferencesSnapshot {
        let languageCode = defaults.string(forKey: Self.languageKey) ?? AppLanguage.turkish.rawValue
        let updatedAt = defaults.object(forKey: Self.languageUpdatedAtKey) as? Date ?? .distantPast
        return PreferencesSnapshot(
            languageCode: languageCode,
            updatedAt: updatedAt,
            sourceBundleIdentifier: Bundle.main.bundleIdentifier ?? AppMigrationConfig.currentBundleIdentifier,
            migrationVersion: AppMigrationConfig.migrationVersion
        )
    }

    func saveSnapshot(_ snapshot: PreferencesSnapshot) {
        defaults.set(snapshot.languageCode, forKey: Self.languageKey)
        defaults.set(snapshot.updatedAt, forKey: Self.languageUpdatedAtKey)
    }
}

final class AppGroupMigrationStore {
    private let defaults: UserDefaults?

    init(suiteName: String = AppMigrationConfig.sharedAppGroupIdentifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    func loadPayload() -> MigrationPayload? {
        guard let defaults,
              let data = defaults.data(forKey: AppMigrationConfig.appGroupPayloadKey) else {
            return nil
        }
        return try? JSONDecoder().decode(MigrationPayload.self, from: data)
    }

    func savePayload(_ payload: MigrationPayload) {
        guard let defaults,
              let data = try? JSONEncoder().encode(payload) else {
            return
        }
        defaults.set(data, forKey: AppMigrationConfig.appGroupPayloadKey)
    }

    func clearPayload() {
        defaults?.removeObject(forKey: AppMigrationConfig.appGroupPayloadKey)
    }
}

protocol CloudSyncRepository {
    func loadPayload(for appleUserID: String) async throws -> MigrationPayload?
    func savePayload(_ payload: MigrationPayload, for appleUserID: String) async throws
}

final class CloudKitProgressRepository: CloudSyncRepository {
    private let database: CKDatabase

    init(containerIdentifier: String = AppMigrationConfig.cloudContainerIdentifier) {
        let container = CKContainer(identifier: containerIdentifier)
        database = container.privateCloudDatabase
    }

    func loadPayload(for appleUserID: String) async throws -> MigrationPayload? {
        let recordID = CKRecord.ID(recordName: appleUserID)
        return try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let payloadData = record?["payload"] as? Data else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    let payload = try JSONDecoder().decode(MigrationPayload.self, from: payloadData)
                    continuation.resume(returning: payload)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func savePayload(_ payload: MigrationPayload, for appleUserID: String) async throws {
        let recordID = CKRecord.ID(recordName: appleUserID)
        let data = try JSONEncoder().encode(payload)
        let record = CKRecord(recordType: "ProgressSnapshot", recordID: recordID)
        record["payload"] = data as CKRecordValue
        record["updatedAt"] = payload.exportedAt as CKRecordValue
        record["sourceBundleIdentifier"] = payload.sourceBundleIdentifier as CKRecordValue

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.save(record) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum MigrationPayloadMerger {
    static func merge(
        local: MigrationPayload?,
        shared: MigrationPayload?,
        cloud: MigrationPayload?
    ) -> MigrationPayload? {
        let candidates = [local, shared, cloud].compactMap { $0 }.filter(\.hasContent)
        guard var merged = candidates.first else { return nil }

        for candidate in candidates.dropFirst() {
            merged.progress = mergeProgress(merged.progress, candidate.progress)
            merged.preferences = mergePreferences(merged.preferences, candidate.preferences)
            merged.exportedAt = max(merged.exportedAt, candidate.exportedAt)
            if merged.appleUserID == nil {
                merged.appleUserID = candidate.appleUserID
            }
        }

        return merged
    }

    static func mergeProgress(_ lhs: ProgressSnapshot, _ rhs: ProgressSnapshot) -> ProgressSnapshot {
        let allKeys = Set(lhs.groupProgress.keys).union(rhs.groupProgress.keys)
        var mergedProgress: [String: GroupProgress] = [:]

        for key in allKeys {
            switch (lhs.groupProgress[key], rhs.groupProgress[key]) {
            case let (.some(left), .some(right)):
                mergedProgress[key] = preferredProgress(left, right)
            case let (.some(left), .none):
                mergedProgress[key] = left
            case let (.none, .some(right)):
                mergedProgress[key] = right
            case (.none, .none):
                break
            }
        }

        return ProgressSnapshot(
            completedGroupIds: lhs.completedGroupIds.union(rhs.completedGroupIds),
            groupProgress: mergedProgress,
            updatedAt: max(lhs.updatedAt, rhs.updatedAt),
            sourceBundleIdentifier: rhs.updatedAt >= lhs.updatedAt ? rhs.sourceBundleIdentifier : lhs.sourceBundleIdentifier,
            migrationVersion: max(lhs.migrationVersion, rhs.migrationVersion)
        )
    }

    static func mergePreferences(_ lhs: PreferencesSnapshot, _ rhs: PreferencesSnapshot) -> PreferencesSnapshot {
        rhs.updatedAt >= lhs.updatedAt ? rhs : lhs
    }

    private static func preferredProgress(_ lhs: GroupProgress, _ rhs: GroupProgress) -> GroupProgress {
        if lhs.isComplete != rhs.isComplete {
            return lhs.isComplete ? lhs : rhs
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
        }

        if lhs.viewed != rhs.viewed {
            return lhs.viewed >= rhs.viewed ? lhs : rhs
        }

        return lhs.total >= rhs.total ? lhs : rhs
    }
}

@MainActor
final class MigrationSyncCoordinator: ObservableObject {
    @Published private(set) var session: UserSession?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var hasSharedMigrationData = false
    @Published var statusMessage: String?
    @Published var noticeMessage: String?
    @Published var errorMessage: String?

    let identityStore: UserIdentityStore
    let appleSignInService: AppleSignInService

    private let cloudRepository: CloudSyncRepository
    private let appGroupStore: AppGroupMigrationStore

    init(
        identityStore: UserIdentityStore = UserIdentityStore(),
        appleSignInService: AppleSignInService = AppleSignInService(),
        cloudRepository: CloudSyncRepository = CloudKitProgressRepository(),
        appGroupStore: AppGroupMigrationStore = AppGroupMigrationStore()
    ) {
        self.identityStore = identityStore
        self.appleSignInService = appleSignInService
        self.cloudRepository = cloudRepository
        self.appGroupStore = appGroupStore
        session = identityStore.session
        hasSharedMigrationData = appGroupStore.loadPayload() != nil
    }

    func bootstrap(progressStore: GroupProgressStore, preferences: AppPreferences) async {
        session = identityStore.session
        hasSharedMigrationData = appGroupStore.loadPayload() != nil

        if AppMigrationConfig.isLegacyExporterBuild {
            await exportLegacyPayload(progressStore: progressStore, preferences: preferences, syncToCloud: session != nil)
            return
        }

        if session != nil && (!progressStore.hasAnyProgress || hasSharedMigrationData) {
            await restore(progressStore: progressStore, preferences: preferences, force: false)
        }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appleSignInService.configure(request)
    }

    func handleAppleSignInResult(
        _ result: Result<ASAuthorization, Error>,
        progressStore: GroupProgressStore,
        preferences: AppPreferences
    ) async {
        do {
            let session = try appleSignInService.handle(result)
            identityStore.update(session: session)
            self.session = session
            await restore(progressStore: progressStore, preferences: preferences, force: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportLegacyPayload(
        progressStore: GroupProgressStore,
        preferences: AppPreferences,
        syncToCloud: Bool
    ) async {
        let payload = buildPayload(progressStore: progressStore, preferences: preferences)
        appGroupStore.savePayload(payload)
        hasSharedMigrationData = true
        statusMessage = localized("Eski uygulama ilerlemesi bu cihaz için hazırlandı.", "Legacy progress was prepared on this device.")

        guard syncToCloud, let userID = session?.userID else { return }
        await saveToCloud(payload: payload, userID: userID)
    }

    func restore(progressStore: GroupProgressStore, preferences: AppPreferences, force: Bool) async {
        guard let session else {
            statusMessage = localized("İlerlemeyi geri yüklemek için Apple ile giriş yap.", "Sign in with Apple to restore progress.")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let localPayload = force || !progressStore.hasAnyProgress ? nil : buildPayload(progressStore: progressStore, preferences: preferences)
        let sharedPayload = appGroupStore.loadPayload()
        let cloudPayload: MigrationPayload?

        do {
            cloudPayload = try await cloudRepository.loadPayload(for: session.userID)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = localized("iCloud verisi okunamadı.", "Failed to read iCloud progress.")
            return
        }

        guard let mergedPayload = MigrationPayloadMerger.merge(local: localPayload, shared: sharedPayload, cloud: cloudPayload) else {
            statusMessage = localized("Geri getirilecek bir ilerleme bulunamadı.", "No stored progress was found.")
            return
        }

        progressStore.replace(with: mergedPayload.progress, notify: false)
        preferences.replace(with: mergedPayload.preferences, notify: false)
        noticeMessage = localized("İlerlemen geri yüklendi.", "Your progress was restored.")
        statusMessage = localized("İlerleme eşitlendi.", "Progress is up to date.")
        lastSyncedAt = Date()

        if sharedPayload != nil {
            appGroupStore.clearPayload()
            hasSharedMigrationData = false
        }

        await saveToCloud(payload: buildPayload(progressStore: progressStore, preferences: preferences), userID: session.userID)
    }

    func syncCurrentState(progressStore: GroupProgressStore, preferences: AppPreferences) async {
        guard let session else { return }
        await saveToCloud(payload: buildPayload(progressStore: progressStore, preferences: preferences), userID: session.userID)
    }

    func handleLocalMutation(progressStore: GroupProgressStore, preferences: AppPreferences) async {
        if AppMigrationConfig.isLegacyExporterBuild {
            await exportLegacyPayload(progressStore: progressStore, preferences: preferences, syncToCloud: session != nil)
        } else {
            await syncCurrentState(progressStore: progressStore, preferences: preferences)
        }
    }

    func clearNotice() {
        noticeMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func markSignedOut() {
        identityStore.clear()
        session = nil
        statusMessage = localized("iCloud eşitlemesi durduruldu.", "iCloud sync has been turned off.")
    }

    private func saveToCloud(payload: MigrationPayload, userID: String) async {
        do {
            try await cloudRepository.savePayload(payload, for: userID)
            lastSyncedAt = Date()
            statusMessage = localized("İlerleme iCloud ile eşitlendi.", "Progress synced with iCloud.")
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = localized("iCloud eşitlemesi başarısız oldu.", "iCloud sync failed.")
        }
    }

    private func buildPayload(progressStore: GroupProgressStore, preferences: AppPreferences) -> MigrationPayload {
        MigrationPayload(
            progress: progressStore.snapshot(),
            preferences: preferences.snapshot(),
            exportedAt: Date(),
            sourceBundleIdentifier: Bundle.main.bundleIdentifier ?? AppMigrationConfig.currentBundleIdentifier,
            appleUserID: session?.userID
        )
    }

    private func localized(_ turkish: String, _ english: String) -> String {
        LocalPreferencesRepository().loadSnapshot().language == .turkish ? turkish : english
    }
}
