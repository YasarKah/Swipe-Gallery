import AuthenticationServices
import Foundation

struct UserSession: Codable, Equatable {
    let userID: String
    let email: String?
    let givenName: String?
    let familyName: String?
    let createdAt: Date

    var displayName: String {
        let fullName = [givenName, familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fullName.isEmpty {
            return fullName
        }

        if let email, !email.isEmpty {
            return email
        }

        return userID
    }
}

final class UserIdentityStore: ObservableObject {
    private let sessionKey = "appleIdentity.session"
    private let defaults: UserDefaults

    @Published private(set) var session: UserSession?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: sessionKey),
           let decoded = try? JSONDecoder().decode(UserSession.self, from: data) {
            session = decoded
        } else {
            session = nil
        }
    }

    func update(session: UserSession) {
        self.session = session
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: sessionKey)
    }

    func clear() {
        session = nil
        defaults.removeObject(forKey: sessionKey)
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential

    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Sign in with Apple could not read your account."
        }
    }
}

final class AppleSignInService {
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handle(_ result: Result<ASAuthorization, Error>) throws -> UserSession {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.invalidCredential
        }

        return UserSession(
            userID: credential.user,
            email: credential.email,
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName,
            createdAt: Date()
        )
    }

    func credentialState(for userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
}
