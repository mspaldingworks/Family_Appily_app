import FamilyCore
import SwiftData
import SwiftUI

/// The app's entry point. No login, no session — tapping a card is the only
/// way "identity" works in this app. Per CLAUDE.md §3.4/§4: photo-based,
/// name beneath, one tap to switch, current ticket count visible at rest.
public struct ProfilePickerView: View {
    @Query(sort: \Child.name) private var children: [Child]
    @Query private var ticketEntries: [TicketLedgerEntry]

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)], spacing: 16) {
                    ForEach(children) { child in
                        NavigationLink {
                            WeeklyChartView(child: child)
                        } label: {
                            ProfileCard(child: child, ticketBalance: balance(for: child))
                        }
                        .buttonStyle(.plain)
                    }

                    NavigationLink {
                        FamilyRotationView()
                    } label: {
                        FamilyRotationCard()
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("Who's here?")
        }
    }

    private func balance(for child: Child) -> Int {
        ticketEntries.filter { $0.childID == child.id }.reduce(0) { $0 + $1.amount }
    }
}

private struct ProfileCard: View {
    let child: Child
    let ticketBalance: Int

    private var theme: ChildTheme {
        ChildTheme.theme(for: child.childID ?? .finley)
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(child.primaryAvatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            Text(child.name)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(theme.textInk)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .accessibilityHidden(true)
                Text("\(ticketBalance) tickets")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 26).fill(SharedTokens.paper).shadow(radius: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(ticketBalance) tickets")
        .accessibilityHint("Opens \(child.name)'s weekly chore chart")
    }
}

private struct FamilyRotationCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text("Family Rotation")
                .font(.system(.title2, design: .rounded).weight(.bold))
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 26).fill(SharedTokens.paper).shadow(radius: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Family Rotation")
        .accessibilityHint("Opens the shared family chore rotation")
    }
}
