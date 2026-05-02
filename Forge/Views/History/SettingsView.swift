ximport SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    @EnvironmentObject var sessionClient: SessionClient

    // Local mirrors of the persisted collab profile, edited in this screen.
    // Synced from sessionClient.myProfile on appear; written back via
    // sessionClient.submitProfile(...) on Save (which persists to UserDefaults
    // AND broadcasts the new profile if a session is currently active).
    @State private var profileName: String = ""
    @State private var profilePhotoData: Data? = nil
    @State private var profilePhotoItem: PhotosPickerItem? = nil
    @State private var showClearProfileConfirm: Bool = false

    // Local mirrors of the persisted height. Saved via `saveHeight()` →
    // `settings.heightCm`. Two-field (ft/in) when weightUnit is lb,
    // single (cm) when kg — fields are kept in sync with whatever the
    // current preference is, so toggling units mid-edit doesn't lose
    // the typed value.
    @State private var heightFeetText: String = ""
    @State private var heightInchesText: String = ""
    @State private var heightCmText: String = ""

    private var profileTrimmedName: String {
        profileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var profileHasUnsavedChanges: Bool {
        let savedName = sessionClient.myProfile?.name ?? ""
        let savedPhoto = sessionClient.myProfile?.photoData
        let nameChanged = profileTrimmedName != savedName
        let photoChanged = profilePhotoData != savedPhoto
        return (nameChanged || photoChanged) && !profileTrimmedName.isEmpty
    }

    /// Parses the active height field(s) into cm. Returns nil if the
    /// fields are empty or invalid (so the Save button stays disabled).
    private var heightDraftCm: Double? {
        switch settings.weightUnit {
        case .lb:
            guard let feet = Int(heightFeetText), feet >= 0 else { return nil }
            let inches = Double(heightInchesText) ?? 0
            let cm = WeightUnit.feetInchesToCm(feet: feet, inches: inches)
            return cm > 0 ? cm : nil
        case .kg:
            guard let cm = Double(heightCmText), cm > 0 else { return nil }
            return cm
        }
    }

    private var heightHasUnsavedChanges: Bool {
        guard let draft = heightDraftCm else { return false }
        if let saved = settings.heightCm {
            // 0.1 cm tolerance — round-trip via ft/in conversion can
            // drift fractions of a millimetre and we don't want a
            // permanently-active Save button after a successful save.
            return abs(draft - saved) > 0.1
        }
        return true
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    PhotosPicker(selection: $profilePhotoItem, matching: .images, photoLibrary: .shared()) {
                        avatar(
                            data: profilePhotoData,
                            fallbackInitial: initial(from: profileTrimmedName.isEmpty ? "?" : profileTrimmedName),
                            diameter: 56
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Circle().fill(settings.fgColor))
                                .offset(x: 2, y: 2)
                        }
                    }

                    TextField(
                        "",
                        text: $profileName,
                        prompt: Text("Your name").foregroundColor(.gray)
                    )
                    .font(.body)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)

                    Button {
                        saveProfile()
                    } label: {
                        Text("Save")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(profileHasUnsavedChanges ? settings.fgColor : Color.gray.opacity(0.3))
                            .cornerRadius(settings.cornerRadiusMedium)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!profileHasUnsavedChanges)
                }
                .listRowBackground(GlobalSettings.shared.bgColor)

                if sessionClient.myProfile != nil {
                    Button(role: .destructive) {
                        showClearProfileConfirm = true
                    } label: {
                        Text("Clear Profile")
                    }
                    .listRowBackground(GlobalSettings.shared.bgColor)
                }
            } header: {
                Text("Collaboration Profile")
            } footer: {
                Text("Shown to friends when you join or host a collab session.")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
            }

            Section {
                NavigationLink {
                    WeightHistoryView()
                } label: {
                    Label("Weight History", systemImage: "scalemass")
                        .foregroundColor(.white)
                }
                .listRowBackground(GlobalSettings.shared.bgColor)

                NavigationLink {
                    ProgressPhotosView()
                } label: {
                    Label("Progress Photos", systemImage: "photo.on.rectangle.angled")
                        .foregroundColor(.white)
                }
                .listRowBackground(GlobalSettings.shared.bgColor)
            } header: {
                Text("Progress Tracking")
            }

            Section {
                Picker("", selection: $settings.weightUnit) {
                    Text("Pounds (lb)").tag(WeightUnit.lb)
                    Text("Kilograms (kg)").tag(WeightUnit.kg)
                }
                .pickerStyle(.segmented)
                .listRowBackground(GlobalSettings.shared.bgColor)
            } header: {
                Text("Units")
            } footer: {
                Text("Applies to body weight and exercise weights everywhere in the app.")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
            }

            Section {
                heightInputRow
                    .listRowBackground(GlobalSettings.shared.bgColor)

                if settings.heightCm != nil {
                    Button(role: .destructive) {
                        clearHeight()
                    } label: {
                        Text("Clear Height")
                    }
                    .listRowBackground(GlobalSettings.shared.bgColor)
                }
            } header: {
                Text("Personal Metrics")
            } footer: {
                Text("Height is used to compute your BMI on the body weight log.")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
            }

            Section {
                HStack(spacing: 0) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        Button {
                            settings.colorTheme = theme
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 36, height: 36)
                                    if settings.colorTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                Text(theme.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(GlobalSettings.shared.bgColor)
            } header: {
                Text("Accent Color")
            }


            Section {
                let plansWithDate = planViewModel.workoutPlans.filter { $0.lastCompleted != nil }
                if plansWithDate.isEmpty {
                    Text("No plans with completion dates")
                        .foregroundColor(GlobalSettings.shared.editorDarkGray)
                        .listRowBackground(GlobalSettings.shared.bgColor)
                } else {
                    ForEach(plansWithDate) { plan in
                        if let index = planViewModel.workoutPlans.firstIndex(where: { $0.id == plan.id }),
                           let date = plan.lastCompleted {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plan.name)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text(completedWorkoutsViewModel.numberOfDaysString(from: date))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button {
                                    planViewModel.workoutPlans[index].lastCompleted = nil
                                    planViewModel.savePlans()
                                } label: {
                                    Text("Reset")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(settings.fgColor)
                                        .cornerRadius(settings.cornerRadiusMedium)
                                }
                                .buttonStyle(.borderless)
                            }
                            .listRowBackground(GlobalSettings.shared.bgColor)
                        }
                    }
                }
            } header: {
                Text("Reset Last Completed")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.black)
        .navigationTitle("Settings")
        .navigationBarTitleTextColor(settings.fgColor)
        .onAppear {
            // Hydrate the local form from the cached profile. Don't overwrite
            // a typed-but-unsaved edit if the user navigates away and back.
            if profileName.isEmpty {
                profileName = sessionClient.myProfile?.name ?? ""
            }
            if profilePhotoData == nil {
                profilePhotoData = sessionClient.myProfile?.photoData
            }
            hydrateHeightFields()
        }
        .onChange(of: settings.weightUnit) { _, _ in
            // When the user toggles units, re-derive the alternate input
            // fields from the saved height so the new mode shows the
            // same value (not a stale or empty draft).
            hydrateHeightFields()
        }
        .onChange(of: profilePhotoItem) { _, newItem in
            Task {
                guard let item = newItem,
                      let data = try? await item.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data)
                else { return }
                let resized = resizeImage(uiImage, maxSide: 256)
                profilePhotoData = resized.jpegData(compressionQuality: 0.7)
            }
        }
        .alert("Clear Profile?", isPresented: $showClearProfileConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) { clearProfile() }
        } message: {
            Text("Removes your saved name and photo. You'll be prompted to enter them again next time you join a collab session.")
        }
    }

    private func saveProfile() {
        let trimmed = profileTrimmedName
        guard !trimmed.isEmpty else { return }
        sessionClient.submitProfile(Profile(name: trimmed, photoData: profilePhotoData))
    }

    @ViewBuilder
    private var heightInputRow: some View {
        HStack(spacing: 10) {
            switch settings.weightUnit {
            case .lb:
                TextField("Feet", text: $heightFeetText)
                    .keyboardType(.numberPad)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                Text("ft")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
                TextField("Inches", text: $heightInchesText)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                Text("in")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
            case .kg:
                TextField("Centimeters", text: $heightCmText)
                    .keyboardType(.decimalPad)
                    .frame(width: 100)
                    .multilineTextAlignment(.center)
                Text("cm")
                    .foregroundColor(GlobalSettings.shared.editorDarkGray)
            }
            Spacer()
            Button {
                saveHeight()
            } label: {
                Text("Save")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(heightHasUnsavedChanges ? settings.fgColor : Color.gray.opacity(0.3))
                    .cornerRadius(settings.cornerRadiusMedium)
            }
            .buttonStyle(.borderless)
            .disabled(!heightHasUnsavedChanges)
        }
        .foregroundColor(.white)
    }

    private func saveHeight() {
        guard let cm = heightDraftCm else { return }
        settings.heightCm = cm
        // Re-derive the field text from the just-saved value so any
        // rounding (e.g. 5 ft 11.0 in → 180.34 cm → "180.3 cm") is
        // reflected immediately rather than waiting for next appear.
        hydrateHeightFields()
    }

    private func clearHeight() {
        settings.heightCm = nil
        heightFeetText = ""
        heightInchesText = ""
        heightCmText = ""
    }

    private func hydrateHeightFields() {
        guard let cm = settings.heightCm else {
            heightFeetText = ""
            heightInchesText = ""
            heightCmText = ""
            return
        }
        let split = WeightUnit.cmToFeetInches(cm)
        heightFeetText = String(split.feet)
        heightInchesText = formatInchesField(split.inches)
        heightCmText = formatCmField(cm)
    }

    private func formatInchesField(_ inches: Double) -> String {
        if inches.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(inches))
        }
        return String(format: "%.1f", inches)
    }

    private func formatCmField(_ cm: Double) -> String {
        if cm.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(cm))
        }
        return String(format: "%.1f", cm)
    }

    private func clearProfile() {
        sessionClient.clearProfile()
        profileName = ""
        profilePhotoData = nil
        profilePhotoItem = nil
    }
}

struct SettingsView_Previews: PreviewProvider {
    @MainActor static var previews: some View {
        // Env objects attached to the NavigationStack so they propagate
        // to NavigationLink destinations in the canvas. (When attached
        // inside the stack, Xcode previews don't carry them across push.)
        NavigationStack {
            SettingsView()
        }
        .environmentObject(GlobalSettings.shared)
        .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
        .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
        .environmentObject(BodyWeightViewModel(mockEntries: mockBodyWeightEntries))
        .environmentObject(makeMockProgressPhotosVM())
        .environmentObject(SessionClient())
        .preferredColorScheme(.dark)
    }
}
