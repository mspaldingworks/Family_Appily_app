import Foundation

/// Synchronous access to the app's current best-known copy of the three
/// contracts. Always succeeds from a local file (bundled, or a previously
/// validated cached download) — the network is never a dependency for this
/// call, per CLAUDE.md §3.6 (must work fully in airplane mode).
public protocol ContractSource: Sendable {
    func loadFamily() throws -> FamilyContract
    func loadRotation() throws -> RotationContract
    func loadTickets() throws -> TicketsContract
}

/// Reads directly from the bundled JSON shipped in the app. Used as the seed
/// for `CachingContractSource` and directly in tests.
public struct BundledContractSource: ContractSource {
    public init() {}

    public func loadFamily() throws -> FamilyContract { try Self.decode("family") }
    public func loadRotation() throws -> RotationContract { try Self.decode("rotation") }
    public func loadTickets() throws -> TicketsContract { try Self.decode("tickets") }

    static func decode<T: Decodable>(_ name: String) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ContractError.missingBundledResource(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// Reads from a cache directory (seeded from the bundle on first launch),
/// which `ContractRefresher` may update in the background. Falls back to the
/// bundled copy if a cached file is missing or fails to decode.
public struct CachingContractSource: ContractSource {
    private let cacheDirectory: URL
    private let bundled = BundledContractSource()

    public init(cacheDirectory: URL) {
        self.cacheDirectory = cacheDirectory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    public func loadFamily() throws -> FamilyContract { try load("family", fallback: bundled.loadFamily) }
    public func loadRotation() throws -> RotationContract { try load("rotation", fallback: bundled.loadRotation) }
    public func loadTickets() throws -> TicketsContract { try load("tickets", fallback: bundled.loadTickets) }

    private func load<T: Decodable>(_ name: String, fallback: () throws -> T) throws -> T {
        let cachedURL = cacheDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: cachedURL),
              let decoded = try? JSONDecoder().decode(T.self, from: data) else {
            return try fallback()
        }
        return decoded
    }
}

/// Background, at-most-once-daily check for newer contracts, per
/// ARCHITECTURE_DECISION.md: fetch the manifest, and only if its version is
/// higher than what's cached, fetch and validate the three contracts before
/// committing them. Any validation failure keeps the existing contracts —
/// never partially applies a bad fetch. This is purely an optimization; the
/// app is fully usable via `CachingContractSource` if this never runs.
public actor ContractRefresher {
    private let baseURL: URL
    private let cacheDirectory: URL
    private let session: URLSession
    private let lastCheckKey = "FamilyCore.ContractRefresher.lastCheckDate"
    private let cachedVersionKey = "FamilyCore.ContractRefresher.cachedVersion"
    private let userDefaults: UserDefaults

    public init(
        baseURL: URL,
        cacheDirectory: URL,
        session: URLSession = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.baseURL = baseURL
        self.cacheDirectory = cacheDirectory
        self.session = session
        self.userDefaults = userDefaults
    }

    public func refreshIfNeeded(now: Date = .now) async {
        if let lastCheck = userDefaults.object(forKey: lastCheckKey) as? Date,
           now.timeIntervalSince(lastCheck) < 86400 {
            return
        }
        defer { userDefaults.set(now, forKey: lastCheckKey) }

        do {
            let manifest: ManifestContract = try await fetchJSON("manifest.json")
            let cachedVersion = userDefaults.integer(forKey: cachedVersionKey)
            guard manifest.version > cachedVersion else { return }

            // Fetch and validate all three before writing any of them — never
            // partially apply a fetch that fails halfway through.
            let family: FamilyContract = try await fetchJSON("family.json")
            let rotation: RotationContract = try await fetchJSON("rotation.json")
            let tickets: TicketsContract = try await fetchJSON("tickets.json")

            try write(family, to: "family.json")
            try write(rotation, to: "rotation.json")
            try write(tickets, to: "tickets.json")
            userDefaults.set(manifest.version, forKey: cachedVersionKey)
        } catch {
            // Network or validation failure: keep whatever's already cached/bundled.
        }
    }

    private func fetchJSON<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent(path))
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ContractError.manifestFetchFailed
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ContractError.validationFailed
        }
    }

    private func write(_ value: some Encodable, to filename: String) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: cacheDirectory.appendingPathComponent(filename), options: .atomic)
    }
}
