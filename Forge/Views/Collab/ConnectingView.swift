import SwiftUI

struct ConnectingView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) var dismiss

    @State private var joinSessionActive = false

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
        .onChange(of: sessionClient.state) { _, newState in
            if case .paired = newState {
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    if sessionClient.isPaired {
                        joinSessionActive = true
                    }
                }
            }
        }
        .onAppear {
            if sessionClient.isPaired {
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    if sessionClient.isPaired {
                        joinSessionActive = true
                    }
                }
            }
        }
        .navigationDestination(isPresented: $joinSessionActive) {
            JoinSessionView()
                .environmentObject(sessionClient)
                .environmentObject(settings)
        }
    }

    private var isConnected: Bool {
        sessionClient.isPaired
    }

    private var iconName: String {
        switch sessionClient.state {
        case .paired: return "checkmark.circle.fill"
        case .error, .disconnected: return "exclamationmark.triangle.fill"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var headerText: String {
        switch sessionClient.state {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .waitingForPeer: return "Waiting for friend…"
        case .paired: return "Connected."
        case .disconnected: return "Reconnecting…"
        case .error(let msg): return "Error\n\(msg)"
        }
    }
}

// MARK: - Previews

#Preview("Connecting") {
    NavigationStack {
        ConnectingView()
            .environmentObject(MockSessionClient.connecting())
            .environmentObject(GlobalSettings.shared)
    }
    .preferredColorScheme(.dark)
}

#Preview("Waiting for peer") {
    NavigationStack {
        ConnectingView()
            .environmentObject(MockSessionClient.waitingForPeer())
            .environmentObject(GlobalSettings.shared)
    }
    .preferredColorScheme(.dark)
}

#Preview("Reconnecting") {
    NavigationStack {
        ConnectingView()
            .environmentObject(MockSessionClient.disconnected())
            .environmentObject(GlobalSettings.shared)
    }
    .preferredColorScheme(.dark)
}
