import Foundation
import JobSearchCore
import Security

/// Keychain-backed storage for the Job Search API token. There's no login
/// screen anywhere in Family Appily — this token is provisioned once (by an
/// adult, in Settings) and then just sits in the Keychain, consistent with
/// the rest of the app having no accounts.
enum JobSearchKeychain {
    private static let service = "com.mspaldingworks.FamilyAppily.jobsearch"
    private static let tokenAccount = "api-token"

    static func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum JobSearchConfig {
    static let baseURL = URL(string: "https://jobs.family-appily.com")!

    /// A token baked in at build time via `JOB_SEARCH_API_TOKEN=...` on the
    /// xcodebuild command line, so a fresh install just works instead of asking
    /// for a 40-character paste on a phone keyboard. Nothing secret is stored in
    /// the repo — without the build setting this is empty and the app falls back
    /// to the manual setup screen.
    private static var buildTimeToken: String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "JobSearchAPIToken") as? String,
              !token.isEmpty,
              !token.hasPrefix("$(") // unsubstituted placeholder
        else { return nil }
        return token
    }

    /// Keychain wins, so a token entered or re-entered in the app always beats
    /// whatever was compiled in.
    static func makeClient() -> JobSearchAPIClient? {
        let stored = JobSearchKeychain.loadToken()
        guard let token = (stored?.isEmpty == false ? stored : buildTimeToken) else { return nil }
        return JobSearchAPIClient(configuration: .init(baseURL: baseURL, token: token))
    }
}
