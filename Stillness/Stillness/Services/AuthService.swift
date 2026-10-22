import AuthenticationServices
import Observation

/// Optional Sign in with Apple. Everything works without an account; signing in
/// gives you a stable user ID for when you add a backend and sync.
@Observable @MainActor
final class AuthService {
    private(set) var userID: String? = UserDefaults.standard.string(forKey: Keys.appleUserID)
    private(set) var displayName: String? = UserDefaults.standard.string(forKey: Keys.displayName)

    var isSignedIn: Bool { userID != nil }

    /// Handles the result of `SignInWithAppleButton`. Returns true when signed in.
    @discardableResult
    func handle(_ result: Result<ASAuthorization, Error>) -> Bool {
        guard case .success(let authorization) = result,
              let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return false }
        userID = credential.user
        UserDefaults.standard.set(credential.user, forKey: Keys.appleUserID)
        // Apple only sends the name the first time someone signs in.
        if let givenName = credential.fullName?.givenName, !givenName.isEmpty {
            displayName = givenName
            UserDefaults.standard.set(givenName, forKey: Keys.displayName)
        }
        return true
    }

    func refreshCredentialState() async {
        guard let userID else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound {
            signOut()
        }
    }

    func signOut() {
        userID = nil
        displayName = nil
        UserDefaults.standard.removeObject(forKey: Keys.appleUserID)
        UserDefaults.standard.removeObject(forKey: Keys.displayName)
    }
}
