import SwiftUI
import UIKit
import PhotosUI

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
                    generateAndCopy()
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
                    generateAndShare()
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

    private func generateAndCopy() {
        sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        UIPasteboard.general.string = url.absoluteString
        connectingActive = true
    }

    private func generateAndShare() {
        sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        shareURL = ShareableURL(url: url)
        connectingActive = true
    }
}

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
            if newState == .connected {
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    if sessionClient.state == .connected {
                        joinSessionActive = true
                    }
                }
            }
        }
        .onAppear {
            if sessionClient.state == .connected {
                Task {
                    try? await Task.sleep(for: .seconds(0.6))
                    if sessionClient.state == .connected {
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
        case .connecting: return "Connecting…"
        case .waitingForPeer: return "Waiting for friend…"
        case .connected: return "Connected."
        case .disconnected: return "Reconnecting…"
        case .error(let msg): return "Error\n\(msg)"
        }
    }
}

struct JoinSessionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var name: String = ""
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var planSuggestionActive = false

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedName.isEmpty && !sessionClient.hasSubmittedProfile
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            Text("Join Session")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

            peerBanner
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Spacer().frame(height: 32)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                avatar(data: photoData, fallbackInitial: initial(from: trimmedName), diameter: 120)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(settings.fgColor))
                            .offset(x: 4, y: 4)
                    }
            }

            Text("Tap to change photo")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 8)

            Spacer().frame(height: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR NAME")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                TextField("", text: $name, prompt: Text("Required").foregroundColor(.gray))
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(white: 0.15))
                    .cornerRadius(10)
                    .disabled(sessionClient.hasSubmittedProfile)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                submit()
            } label: {
                HStack {
                    if sessionClient.hasSubmittedProfile {
                        ProgressView()
                            .tint(.white)
                        Text("Waiting for friend…")
                    } else {
                        Text("Join Session →")
                    }
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .background(canSubmit || sessionClient.hasSubmittedProfile ? settings.fgColor : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .disabled(!canSubmit)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarBackButtonHidden(sessionClient.hasSubmittedProfile)
        .onAppear {
            if name.isEmpty {
                name = sessionClient.myProfile?.name ?? ""
            }
            if photoData == nil {
                photoData = sessionClient.myProfile?.photoData
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data)
                else { return }
                let resized = resizeImage(uiImage, maxSide: 256)
                photoData = resized.jpegData(compressionQuality: 0.7)
            }
        }
        .onChange(of: sessionClient.bothProfilesSubmitted) { _, submitted in
            if submitted { planSuggestionActive = true }
        }
        .navigationDestination(isPresented: $planSuggestionActive) {
            PlanSuggestionPlaceholderView()
                .environmentObject(sessionClient)
                .environmentObject(settings)
        }
    }

    @ViewBuilder
    private var peerBanner: some View {
        HStack(spacing: 14) {
            avatar(data: peerProfile?.photoData, fallbackInitial: initial(from: peerProfile?.name ?? "?"), diameter: 44)

            VStack(alignment: .leading, spacing: 2) {
                if let peerProfile {
                    Text(peerProfile.name)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text("Ready ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Friend")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                    Text("Entering their info…")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    private func submit() {
        let profile = Profile(name: trimmedName, photoData: photoData)
        sessionClient.submitProfile(profile)
    }
}

struct PlanSuggestionPlaceholderView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            HStack(spacing: 40) {
                VStack(spacing: 10) {
                    avatar(
                        data: sessionClient.myProfile?.photoData,
                        fallbackInitial: initial(from: sessionClient.myProfile?.name ?? "?"),
                        diameter: 80
                    )
                    Text(sessionClient.myProfile?.name ?? "You")
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Text("+")
                    .font(.largeTitle)
                    .fontWeight(.light)
                    .foregroundColor(settings.fgColor)

                VStack(spacing: 10) {
                    avatar(
                        data: peerProfile?.photoData,
                        fallbackInitial: initial(from: peerProfile?.name ?? "?"),
                        diameter: 80
                    )
                    Text(peerProfile?.name ?? "Friend")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }

            Text("Plan Suggestion")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Stage 3 — coming soon")
                .font(.subheadline)
                .foregroundColor(.gray)

            Spacer()

            Button {
                sessionClient.disconnect()
            } label: {
                Text("End Session")
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
}

// MARK: - Shared helpers

@ViewBuilder
func avatar(data: Data?, fallbackInitial: String, diameter: CGFloat) -> some View {
    if let data, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    } else {
        ZStack {
            Circle()
                .fill(Color(white: 0.2))
            Text(fallbackInitial)
                .font(.system(size: diameter * 0.45, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

func initial(from name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return "?" }
    return String(first).uppercased()
}

func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let size = image.size
    let longestSide = max(size.width, size.height)
    guard longestSide > maxSide else { return image }
    let scale = maxSide / longestSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
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
