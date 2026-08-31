import FamilyCore
import SwiftUI

/// The hand-drawn-feeling check struck over completed chore text — not an SF
/// Symbol, not a circle, not a strikethrough. Exact path from PHASE0_PROMPT.md,
/// viewBox 0 0 120 104: `M10 44C24 42 34 60 47 88 61 62 84 24 110 10`.
///
/// Per CLAUDE.md §7.3/§3.2: this mark alone is never the only signal of
/// completion — pair it with the card background/border state change and an
/// accessibility value of "completed". It must stay full-opacity black even
/// as the completed text fades, which is why this is a separate layer, not
/// text styling.
private struct CompletionMarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        // Native box is 120x104; scale proportionally into the given rect.
        let scaleX = rect.width / 120
        let scaleY = rect.height / 104

        var path = Path()
        path.move(to: CGPoint(x: 10 * scaleX, y: 44 * scaleY))
        path.addCurve(
            to: CGPoint(x: 47 * scaleX, y: 88 * scaleY),
            control1: CGPoint(x: 24 * scaleX, y: 42 * scaleY),
            control2: CGPoint(x: 34 * scaleX, y: 60 * scaleY)
        )
        path.addCurve(
            to: CGPoint(x: 110 * scaleX, y: 10 * scaleY),
            control1: CGPoint(x: 61 * scaleX, y: 62 * scaleY),
            control2: CGPoint(x: 84 * scaleX, y: 24 * scaleY)
        )
        return path
    }
}

public struct CompletionMark: View {
    let isComplete: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var trimEnd: CGFloat = 0
    @State private var crossFadeOpacity: Double = 0

    public init(isComplete: Bool) {
        self.isComplete = isComplete
    }

    public var body: some View {
        CompletionMarkPath()
            .trim(from: 0, to: reduceMotion ? 1 : trimEnd)
            .stroke(SharedTokens.completionMark, style: StrokeStyle(lineWidth: 13, lineCap: .round, lineJoin: .round))
            .rotationEffect(.degrees(-8))
            .opacity(reduceMotion ? crossFadeOpacity : 1)
            .accessibilityHidden(true) // the parent chore row's accessibility value carries "completed"
            .onAppear { syncAnimationState() }
            .onChange(of: isComplete) { syncAnimationState() }
    }

    private func syncAnimationState() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.3)) {
                crossFadeOpacity = isComplete ? 1 : 0
            }
        } else {
            if isComplete {
                trimEnd = 0
                withAnimation(.easeOut(duration: 0.35)) { trimEnd = 1 }
            } else {
                trimEnd = 0
            }
        }
    }
}

#Preview("Complete") {
    CompletionMark(isComplete: true)
        .frame(width: 120, height: 104)
        .padding()
}

#Preview("Incomplete") {
    CompletionMark(isComplete: false)
        .frame(width: 120, height: 104)
        .padding()
}

#Preview("Dark mode") {
    CompletionMark(isComplete: true)
        .frame(width: 120, height: 104)
        .padding()
        .preferredColorScheme(.dark)
}
