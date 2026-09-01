import Foundation
import JobSearchCore
import OSLog
import Security

private let logger = Logger(subsystem: "com.mspaldingworks.FamilyAppily", category: "JobSearch")

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
    static var buildTimeToken: String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "JobSearchAPIToken") as? String,
              !token.isEmpty,
              !token.hasPrefix("$(") // unsubstituted placeholder
        else { return nil }
        return token
    }

    /// Keychain wins, so a token entered or re-entered in the app always beats
    /// whatever was compiled in.
    static var resolvedToken: String? {
        let stored = JobSearchKeychain.loadToken()
        return stored?.isEmpty == false ? stored : buildTimeToken
    }

    /// Always returns a client, even with no token. The Job Feed is the whole
    /// point of this tab and must open straight to the list — a missing token
    /// is an error to show inside the feed, not a wall in front of it.
    static func makeClient() -> JobSearchAPIClient {
        // Never logs the token itself — just which source won, which is the only
        // thing needed to diagnose "why is it asking me to connect again?".
        let stored = JobSearchKeychain.loadToken()
        logger.debug("""
            token source: \(stored?.isEmpty == false ? "keychain" : (buildTimeToken != nil ? "build-time" : "none"), privacy: .public)
            """)
        return JobSearchAPIClient(configuration: .init(baseURL: baseURL, token: resolvedToken ?? ""))
    }
}
