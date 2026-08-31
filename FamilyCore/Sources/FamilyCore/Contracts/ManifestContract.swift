import Foundation

/// Mirrors manifest.json, served alongside the contracts. See
/// ARCHITECTURE_DECISION.md in the API repo for the versioning scheme.
public struct ManifestContract: Codable, Equatable, Sendable {
    public let version: Int
    public let updated: String
    public let etag: String
}

public enum ContractError: Error, Equatable {
    case missingBundledResource(String)
    case manifestFetchFailed
    case validationFailed
}
