import SwiftUI

/// Small overlay shown at the top of joint-mode views (PlanSuggestionView,
/// WorkoutInProgressView) when the collab session is in any non-healthy
/// state — peer disconnected, local socket dropped, reconnecting, or
/// errored. Hidden when state is .connected or .idle.
///
/// In .waitingForPeer specifically (peer dropped, my socket healthy), a
/// "Re-invite" button presents a share sheet with the current sessionId
/// URL — letting the user invite the same friend back or invite someone
/// new without ending the session. Critical: shareLinkURL() reads the
/// existing sessionId — we do NOT call createSession() here, which would
/// tear down the live pairing.
struct CollabStatusBanner: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @State private var shareItem: ShareableURL? = nil
    /// Last state value the user dismissed via swipe-up. Suppresses the
    /// banner until state CHANGES — a fresh non-healthy state re-shows
    /// the banner.
    @State private var dismissedForState: SessionClient.State? = nil

    var body: some View {
        Group {
            if let message = bannerMessage, !isDismissed {
                HStack(spacing: 10) {
                    if showsSpinner {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    Text(message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if showsReinvite {
                        Button(action: presentShare) {
                            Text("Re-invite")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(settings.fgColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color(white: 0.28)))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(white: 0.18)))
                .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                .transition(.move(edge: .top).combined(with: .opacity))
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            // Swipe up dismisses; reappears when state next changes.
                            if value.translation.height < -20 {
                                dismissedForState = sessionClient.state
                            }
                        }
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessionClient.state)
        .animation(.easeInOut(duration: 0.25), value: isDismissed)
        .sheet(item: $shareItem) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
        }
    }

    private var isDismissed: Bool {
        guard let dismissedForState else { return false }
        return dismissedForState == sessionClient.state
    }

    private var bannerMessage: String? {
        switch sessionClient.state {
        case .paired, .idle:
            return nil
        case .waitingForPeer:
            return "Friend disconnected"
        case .disconnected:
            return "Reconnecting…"
        case .connecting:
            return "Connecting…"
        case .error(let msg):
            return msg
        }
    }

    /// Spinner during transient connectivity states; static peer-question
    /// icon when we're actively waiting for the peer to come back.
    private var showsSpinner: Bool {
        switch sessionClient.state {
        case .disconnected, .connecting: return true
        default: return false
        }
    }

    private var showsReinvite: Bool {
        if case .waitingForPeer = sessionClient.state { return true }
        return false
    }

    private func presentShare() {
        if let url = sessionClient.shareLinkURL() {
            shareItem = ShareableURL(url: url)
        }
    }
}
