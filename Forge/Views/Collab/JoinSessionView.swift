import SwiftUI
import UIKit
import PhotosUI

struct JoinSessionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var name: String = ""
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var planSuggestionActive = false
    @State private var showEndSessionConfirm = false

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    /// Peer's name with whitespace trimmed. Empty when the peer hasn't
    /// broadcast a name yet (either no profile at all, or a photo-only
    /// in-progress edit). Used to drive the friend-side caption fallback
    /// to "Entering their info…" without rendering blank.
    private var peerProfileTrimmedName: String {
        peerProfile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer().frame(height: 50)

            avatarPairRow

            Spacer().frame(height: 40)

            nameField

            Spacer()

            joinButton
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showEndSessionConfirm = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("End")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(settings.fgColor)
                }
            }
        }
        .alert("End Session?", isPresented: $showEndSessionConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { sessionClient.disconnect() }
        }
        .onAppear {
            if name.isEmpty {
                name = sessionClient.myProfile?.name ?? ""
            }
            if photoData == nil {
                photoData = sessionClient.myProfile?.photoData
            }
            autoSubmitIfCachedProfile()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data)
                else { return }
                let resized = resizeImage(uiImage, maxSide: 256)
                photoData = resized.jpegData(compressionQuality: 0.7)
                // Photo just finished loading — push it to the peer so
                // they see the avatar update live, without locking the
                // form (the user might still want to type/correct their
                // name afterwards).
                broadcastInProgressEdit()
            }
        }
        .onChange(of: sessionClient.bothProfilesSubmitted) { _, submitted in
            if submitted { planSuggestionActive = true }
        }
        .navigationDestination(isPresented: $planSuggestionActive) {
            PlanSuggestionView()
                .environmentObject(sessionClient)
                .environmentObject(settings)
        }
    }

    /// User photo + connector + friend photo, side-by-side, with status
    /// captions under each. Mirrors the avatarRow pattern from
    /// `PlanSuggestionView` so the two collab screens feel cohesive.
    private var avatarPairRow: some View {
        HStack(alignment: .top, spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    avatar(
                        data: photoData,
                        fallbackInitial: initial(from: trimmedName.isEmpty ? "?" : trimmedName),
                        diameter: 80
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(settings.fgColor))
                            .offset(x: 2, y: 2)
                    }
                }
                Text(trimmedName.isEmpty ? "You" : trimmedName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trimmedName.isEmpty ? .gray : .white)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            }

            avatarConnector
                .padding(.horizontal, 16)
                .padding(.top, 36)   // visually centered against the 80pt avatar above the caption

            VStack(spacing: 12) {
                avatar(
                    data: peerProfile?.photoData,
                    fallbackInitial: initial(from: peerProfileTrimmedName.isEmpty ? "?" : peerProfileTrimmedName),
                    diameter: 80
                )
                Text(peerProfileTrimmedName.isEmpty ? "Entering their info…" : peerProfileTrimmedName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(peerProfileTrimmedName.isEmpty ? .gray : .white)
                    .lineLimit(1)
                    .frame(maxWidth: 100)
            }

            Spacer()
        }
    }

    private var avatarConnector: some View {
        HStack(spacing: 0) {
            Circle().frame(width: 8, height: 8)
            Rectangle().frame(width: 40, height: 1)
            Circle().frame(width: 8, height: 8)
        }
        .foregroundColor(GlobalSettings.shared.darkGray)
    }

    private var nameField: some View {
        TextField(
            "",
            text: $name,
            prompt: Text("Enter Your Name Here").foregroundColor(.gray)
        )
        .font(.body)
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color(white: 0.15))
        .cornerRadius(settings.cornerRadiusMedium)
        .frame(maxWidth: 240)
        .disabled(sessionClient.hasSubmittedProfile)
        .textInputAutocapitalization(.words)
        .submitLabel(.done)
        // Tap Done on the keyboard → broadcast the current name+photo to
        // the peer so they see live progress without us yet committing
        // to "Join Session →".
        .onSubmit { broadcastInProgressEdit() }
    }

    private var joinButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if sessionClient.hasSubmittedProfile {
                    ProgressView()
                        .tint(.white)
                    Text("Waiting for friend…")
                } else {
                    Text("Join Session →")
                }
            }
            .fontWeight(.semibold)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .background(canSubmit || sessionClient.hasSubmittedProfile ? settings.fgColor : Color.gray.opacity(0.3))
        .foregroundColor(.white)
        .cornerRadius(settings.cornerRadiusMedium)
        .disabled(!canSubmit)
    }

    private func submit() {
        let profile = Profile(name: trimmedName, photoData: photoData)
        sessionClient.submitProfile(profile)
    }

    /// Live-broadcast the current edit state to the peer without committing
    /// (i.e., without setting `hasSubmittedProfile`). Skipped if the user
    /// has already tapped Join Session → (form is locked) or hasn't made
    /// any edit at all (don't send a totally-blank profile that just
    /// overwrites the "Entering their info…" placeholder with nothing).
    /// A name-only OR photo-only edit DOES broadcast — the receiver-side
    /// caption logic below treats an empty name as "still entering" so
    /// the peer sees the avatar update without a blank caption.
    private func broadcastInProgressEdit() {
        guard !sessionClient.hasSubmittedProfile else { return }
        if trimmedName.isEmpty && photoData == nil { return }
        sessionClient.updateProfile(Profile(name: trimmedName, photoData: photoData))
    }

    /// If the user has a cached profile from a prior session (loaded into
    /// `myProfile` from UserDefaults at SessionClient init time), submit
    /// it automatically so the peer sees the user's name + photo without
    /// the user needing to tap "Join Session →". Profile editing now
    /// lives in Settings → Collaboration Profile, so the form-on-every-
    /// session step is redundant for returning users. First-time users
    /// (no cached profile) still see the form and submit manually.
    ///
    /// Idempotent via the `!hasSubmittedProfile` guard — safe to call
    /// from anywhere that might re-trigger the flow.
    private func autoSubmitIfCachedProfile() {
        guard !sessionClient.hasSubmittedProfile else { return }
        guard let cached = sessionClient.myProfile else { return }
        let trimmedCachedName = cached.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCachedName.isEmpty else { return }
        sessionClient.submitProfile(cached)
    }
}
