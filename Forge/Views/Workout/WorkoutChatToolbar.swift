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
            CollabChatPanel(showAvatarHeader: true)
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
                    Text(buttonLabel).fontWeight(.bold)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .foregroundColor(settings.fgColor)
            }
        }
    }
}
