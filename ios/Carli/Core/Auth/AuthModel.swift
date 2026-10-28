import Foundation
import Observation
import WidgetKit

struct Credentials: Encodable {
    var email: String
    var password: String
    var deviceName = "carli iOS"
    var code: String?
    var recoveryCode: String?
}

enum LoginResult {
    case signedIn
    case twoFactorRequired
}

/// Session state for the whole app; the root view switches on `state`.
@Observable
final class AuthModel {
    enum State: Equatable {
        case unknown
        case signedOut(expired: Bool)
        /// `user` is nil when the token exists but the server could not be reached.
        case signedIn(CurrentUser?)

        var isSignedIn: Bool { if case .signedIn = self { true } else { false } }
    }

    private(set) var state: State = .unknown
    let api: APIClient
    private let tokens: TokenStore

    init(tokens: TokenStore = TokenStore()) {
        self.tokens = tokens
        self.api = APIClient(tokens: tokens)
        api.onUnauthorized = { [weak self] in self?.handleUnauthorized() }
    }

    var user: CurrentUser? {
        if case .signedIn(let user) = state { user } else { nil }
    }

    func restore() async {
        guard tokens.read() != nil else {
            state = .signedOut(expired: false)
            return
        }
        do {
            state = .signedIn(try await me())
        } catch let error as APIError where error.status == 401 {
            tokens.clear()
            state = .signedOut(expired: false)
        } catch {
            state = .signedIn(nil)
        }
    }

    func login(_ credentials: Credentials) async throws -> LoginResult {
        struct Response: Decodable {
            var twoFactor: Bool?
            var token: String?
            var user: CurrentUser?
        }
        let response: Response = try await api.post("v1/auth/token", body: credentials)
        if response.twoFactor == true { return .twoFactorRequired }
        guard let token = response.token else { throw APIError(status: 500) }
        tokens.write(token)
        WidgetCenter.shared.reloadAllTimelines()
        state = .signedIn(response.user)
        return .signedIn
    }

    /// Replaces the signed-in user after a profile or preference change.
    func updateUser(_ user: CurrentUser) {
        guard case .signedIn = state else { return }
        state = .signedIn(user)
    }

    func refreshUser() async {
        guard case .signedIn = state, let user = try? await me() else { return }
        state = .signedIn(user)
    }

    func logout() async {
        await PushManager.shared.forget()
        try? await api.delete("v1/auth/token")
        tokens.clear()
        WidgetCenter.shared.reloadAllTimelines()
        state = .signedOut(expired: false)
    }

    private func me() async throws -> CurrentUser {
        struct Envelope: Decodable { var data: CurrentUser }
        let envelope: Envelope = try await api.get("v1/me")
        return envelope.data
    }

    private func handleUnauthorized() {
        guard case .signedIn = state else { return }
        tokens.clear()
        state = .signedOut(expired: true)
    }
}
