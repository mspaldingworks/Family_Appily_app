import FamilyCore
import SwiftUI

/// A child's avatar: the mascot art for the three legend kids (on a light paper
/// disc, since the art was drawn for white), or a coloured monogram of their
/// initial for any parent-added child, who has no mascot. Decorative — hidden
/// from VoiceOver, since the name always sits beside it (§3.4).
struct ChildAvatarView: View {
    let child: Child
    var size: CGFloat = 48

    private var theme: ChildTheme { ChildTheme.theme(for: child) }

    var body: some View {
        Group {
            if child.childID == nil {
                ZStack {
                    Circle().fill(theme.dotFill).shadow(radius: 1)
                    if child.avatarSymbol.isEmpty {
                        Text(initial)
                            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: child.avatarSymbol)
                            .font(.system(size: size * 0.48, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: size, height: size)
            } else {
                Image(child.primaryAvatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size * 0.82, height: size * 0.82)
                    .padding(size * 0.09)
                    .frame(width: size, height: size)
                    .background(Circle().fill(SharedTokens.paper).shadow(radius: 1))
            }
        }
        .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = child.name.trimmingCharacters(in: .whitespaces)
        return String(trimmed.first ?? "?").uppercased()
    }
}
