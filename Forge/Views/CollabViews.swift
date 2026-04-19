import SwiftUI
import UIKit

struct WorkoutWithFriendView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var connectingActive = false
    @State private var shareURL: ShareableURL?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 72))
                .foregroundColor(settings.fgColor)

            Text("Workout with a Friend")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Send a link to a friend who has Forge. When they tap it, you'll both be connected for a joint workout session.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await generateAndCopy() }
                } label: {
                    Label("Copy Link", systemImage: "doc.on.doc.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(settings.fgColor)
                .foregroundColor(.white)
                .cornerRadius(12)

                Button {
                    Task { await generateAndShare() }
                } label: {
                    Label("Share Link", systemImage: "square.and.arrow.up.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .background(settings.fgColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareURL) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
        }
        .navigationDestination(isPresented: $connectingActive) {
            ConnectingView()
                .environmentObject(sessionClient)
                .environmentObject(settings)
        }
    }

    private func generateAndCopy() async {
        await sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        UIPasteboard.general.string = url.absoluteString
        connectingActive = true
    }

    private func generateAndShare() async {
        await sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        shareURL = ShareableURL(url: url)
        connectingActive = true
    }
}

struct ConnectingView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: iconName)
                .font(.system(size: 80))
                .foregroundColor(settings.fgColor)
                .symbolEffect(.pulse, options: .repeating, isActive: !isConnected)

            Text(headerText)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            if let id = sessionClient.sessionId, !isConnected {
                Text(id.uuidString.prefix(8).lowercased() + "…")
                    .font(.caption.monospaced())
                    .foregroundColor(.gray)
            }

            Spacer()

            Button {
                sessionClient.disconnect()
                dismiss()
            } label: {
                Text(isConnected ? "End Session" : "Cancel")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .foregroundColor(.white)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(12)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
    }

    private var isConnected: Bool {
        sessionClient.state == .connected
    }

    private var iconName: String {
        switch sessionClient.state {
        case .connected: return "checkmark.circle.fill"
        case .error, .disconnected: return "exclamationmark.triangle.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var headerText: String {
        switch sessionClient.state {
        case .idle: return "Idle"
        case .creating: return "Creating session…"
        case .connecting: return "Connecting…"
        case .waitingForPeer: return "Waiting for friend…"
        case .connected: return "Connected."
        case .disconnected(let reason): return "Disconnected\n\(reason)"
        case .error(let msg): return "Error\n\(msg)"
        }
    }
}

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
