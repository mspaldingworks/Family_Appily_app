import SwiftUI

/// One-time API token entry — shared by both the iOS tab and the Mac app's
/// root view. Not a login screen: just a Keychain-backed token paste, since
/// Family Appily has no accounts anywhere.
struct JobSearchSetupView: View {
    let onSave: (String) -> Void
    @State private var token = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text("Connect Job Search")
                .font(.title2.weight(.semibold))
            Text("Enter the API token generated for this device. This is a one-time setup, not an account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SecureField("API token", text: $token)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            Button("Save") { onSave(token) }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .disabled(token.isEmpty)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
