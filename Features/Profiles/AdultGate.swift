import LocalAuthentication
import SwiftUI

/// Gates an adult-only action inline, at the point of the action — never at
/// app launch, and never a separate login system. Per CLAUDE.md §3.5/§4:
/// "Adult-only actions are gated behind a simple PIN or Face ID at the point
/// of the action, not at app launch."
@MainActor
final class AdultGate: ObservableObject {
    @Published var isUnlocked = false

    func requestAccess(reason: String) async -> Bool {
        if isUnlocked { return true }

        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No Face ID/Touch ID/passcode configured on this device — fail closed
            // rather than silently granting adult access.
            return false
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isUnlocked = success
            return success
        } catch {
            return false
        }
    }

    /// Re-lock after leaving the adult-gated area (e.g. when the app backgrounds,
    /// or the user navigates away). Adult access is per-session, not permanent.
    func lock() {
        isUnlocked = false
    }
}

/// Wraps content behind an adult-authentication prompt. Shows a plain "gated"
/// placeholder with an unlock affordance until authentication succeeds.
struct AdultGated<Content: View>: View {
    let reason: String
    @ViewBuilder let content: () -> Content

    @StateObject private var gate = AdultGate()
    @State private var didFail = false

    var body: some View {
        Group {
            if gate.isUnlocked {
                content()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .accessibilityHidden(true)
                    Text("For adults")
                        .font(.title2.weight(.semibold))
                    if didFail {
                        Text("Authentication failed. Try again.")
                            .foregroundStyle(.secondary)
                    }
                    Button("Unlock") {
                        Task {
                            let unlocked = await gate.requestAccess(reason: reason)
                            didFail = !unlocked
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 60, minHeight: 60)
                    .accessibilityLabel("Unlock with Face ID or passcode")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(SharedTokensBackground())
            }
        }
    }
}

private struct SharedTokensBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        (colorScheme == .dark ? Color(white: 0.11) : Color.white)
            .ignoresSafeArea()
    }
}
