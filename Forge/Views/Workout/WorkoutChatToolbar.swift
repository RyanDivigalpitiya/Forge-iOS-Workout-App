import SwiftUI

/// Mid-workout chat container — the chat panel + Open/Minimize Chat row
/// + divider, with its own blur background and animated rounded top
/// corners. Rendered as a SEPARATE sibling of `WorkoutBottomToolbarView`
/// in `WorkoutInProgressView`'s ZStack so it can rise with the keyboard
/// while the 3-button toolbar stays anchored at the bottom (via
/// `.ignoresSafeArea(.keyboard)` on the latter, omitted here).
///
/// `chatPanelHeight` animates from 0 (collapsed) to its open target,
/// growing this container's blur background upward. `chatPanelVisible`
/// fades the panel content in/out. `chatPanelCornerRadius` rounds the
/// top edges during expansion. All three are driven from the parent
/// inside one withAnimation.
struct WorkoutChatToolbar: View {
    let isChatOpen: Bool
    let onChatToggleTapped: () -> Void
    let chatPanelHeight: CGFloat
    let chatPanelVisible: Bool
    let chatPanelCornerRadius: CGFloat
    let unreadCount: Int

    @EnvironmentObject var settings: GlobalSettings
    private let chatRowHeight: CGFloat = 50

    private var buttonLabel: String {
        if isChatOpen { return "Minimize Chat" }
        switch unreadCount {
        case 0:  return "Open Chat"
        case 1:  return "Open Chat (1 New Message)"
        default: return "Open Chat (\(unreadCount) New Messages)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CollabChatPanel(showAvatarHeader: true, translucentInputBackground: true)
                .opacity(chatPanelVisible ? 1 : 0)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .frame(height: chatPanelHeight)
                .clipped()
            chatToggleRow
                .frame(height: chatRowHeight)
            Divider()
                .padding(.horizontal, 54)
        }
        .background(BlurView(style: .systemChromeMaterial))
        .clipShape(
            .rect(
                topLeadingRadius: chatPanelCornerRadius,
                topTrailingRadius: chatPanelCornerRadius
            )
        )
    }

    private var chatToggleRow: some View {
        HStack {
            Button(action: { onChatToggleTapped() }) {
                HStack {
                    Image(systemName: isChatOpen ? "xmark.bubble.fill" : "bubble.left.fill")
                    if !isChatOpen && unreadCount > 0 {
                        shimmeringLabel(buttonLabel)
                    } else {
                        Text(buttonLabel).fontWeight(.bold)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .foregroundColor(settings.fgColor)
            }
        }
    }

    /// Shimmer treatment for the unread-state label. LinearGradient endpoints
    /// can't be animated via `withAnimation`, so phase is driven from a
    /// `TimelineView(.animation)` re-rendering each frame — same pattern +
    /// 2.5s cycle as `PlanSuggestionView.shimmeringSuggestedName`.
    private func shimmeringLabel(_ text: String) -> some View {
        TimelineView(.animation) { context in
            let phase = shimmerPhase(at: context.date)
            Text(text)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: settings.fgColor, location: 0),
                            .init(color: .white, location: 0.5),
                            .init(color: settings.fgColor, location: 1),
                        ],
                        startPoint: UnitPoint(x: phase, y: 0.5),
                        endPoint: UnitPoint(x: phase + 1, y: 0.5)
                    )
                )
        }
    }

    private func shimmerPhase(at date: Date) -> CGFloat {
        let cycle: Double = 2.5
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycle) / cycle
        return CGFloat(progress * 3.0 - 1.5)
    }
}
