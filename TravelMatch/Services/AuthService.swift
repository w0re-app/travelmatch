import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

/// Apple ile giriş ve oturum yönetimi.
/// App Store kuralları gereği üçüncü parti/e-posta girişi sunan uygulamalarda
/// "Sign in with Apple" seçeneği de bulunmak zorunda — bu yüzden birincil yöntem bu.
final class AuthService {

    static let shared = AuthService()
    private init() {}

    var currentUid: String? { Auth.auth().currentUser?.uid }
    var isSignedIn: Bool { Auth.auth().currentUser != nil }

    private var currentNonce: String?

    /// SwiftUI `SignInWithAppleButton(.signIn) { request in AuthService.shared.configure(request) }`
    func configure(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    /// `onCompletion: { result in ... AuthService.shared.handle(result) }`
    func handle(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idTokenString = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple kimlik bilgisi alınamadı."])
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            try await Auth.auth().signIn(with: firebaseCredential)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Nonce yardımcıları (Apple'ın önerdiği replay-attack koruması)

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
