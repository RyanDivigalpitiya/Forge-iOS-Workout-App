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
            autoSubmitIfRejoiningActiveWorkout()
        }
        .onChange(of: sessionClient.workoutInProgress?.id) { _, _ in
            // Welcome may arrive after JoinSessionView appears (still in
            // .connecting when this view first renders). Re-check on
            // change so the auto-submit fires once workoutInProgress shows up.
            autoSubmitIfRejoiningActiveWorkout()
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
            PlanSuggestionView()
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

    /// When the server reports an active workout is in progress for this
    /// session (mid-workout rejoin), and we have a cached profile to
    /// submit, do so automatically so the user doesn't have to tap "Join
    /// Session →" — they tapped a share link with the intent to rejoin
    /// an in-flight workout, the profile form is just a speed bump.
    private func autoSubmitIfRejoiningActiveWorkout() {
        guard sessionClient.workoutInProgress != nil else { return }
        guard !sessionClient.hasSubmittedProfile else { return }
        guard let cached = sessionClient.myProfile else { return }
        let trimmedCachedName = cached.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCachedName.isEmpty else { return }
        sessionClient.submitProfile(cached)
    }
}
