import SwiftUI

struct UpdateWeightSheet: View {

    /// nil → creating a new entry. non-nil → editing the supplied entry
    /// (Save updates that row's weight; Delete removes it). Date is
    /// preserved on edit so the timeline order doesn't shift.
    let editingEntry: BodyWeightEntry?

    init(editingEntry: BodyWeightEntry? = nil) {
        self.editingEntry = editingEntry
    }

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var weightLbs: Double = 175.0
    @State private var showDeleteConfirm = false

    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let buttonCircleBgColor = GlobalSettings.shared.buttonCircleBgColor

    private let minWeight: Double = 50.0
    private let maxWeight: Double = 500.0
    private let weightStep: Double = 0.5

    private let buttonPlusMinusIconSize: CGFloat = 15
    private let buttonPlusMinusHeight: CGFloat = 32
    private let buttonPlusMinusSize: CGFloat = 5
    private let buttonPlusMinusGap: CGFloat = 14
    private let wheelSelectorSize: CGFloat = 180
    private let fontTitleSize: CGFloat = 28

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private var screenWidth: CGFloat { UIScreen.main.bounds.width }

    private var isEditing: Bool { editingEntry != nil }

    private var title: String { isEditing ? "Edit Weight" : "Update Weight" }

    private var weightRange: [Double] {
        let step = weightStep
        var values: [Double] = []
        var v = maxWeight
        while v >= minWeight - 0.0001 {
            values.append(v)
            v -= step
        }
        return values
    }

    var body: some View {
        VStack(spacing: 0) {

            // TOP TOOLBAR — X | title | up-arrow (mirrors ExerciseEditorView)
            HStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .frame(width: 28, height: 28)
                                .foregroundColor(buttonCircleBgColor)
                            Image(systemName: "xmark")
                                .resizable()
                                .frame(width: 11, height: 11)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(width: 0.2 * screenWidth)

                HStack {
                    Text(title)
                        .font(.system(size: fontTitleSize))
                        .foregroundColor(settings.fgColor)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: 0.6 * screenWidth)

                HStack {
                    Button {
                        save()
                    } label: {
                        ZStack {
                            Circle()
                                .frame(width: 28, height: 28)
                                .foregroundColor(buttonCircleBgColor)
                            Image(systemName: isEditing ? "checkmark" : "arrow.up")
                                .resizable()
                                .frame(width: 13, height: 13)
                                .fontWeight(.bold)
                                .foregroundColor(settings.fgColor)
                        }
                    }
                }
                .frame(width: 0.2 * screenWidth)
            }
            .padding(.top, 18)

            Spacer().frame(height: 10)

            // WEIGHT WHEEL
            VStack(spacing: 8) {
                Picker(selection: $weightLbs, label: Text("Weight")) {
                    ForEach(weightRange, id: \.self) { value in
                        Text(WeightUnit.formatLbs(value))
                            .foregroundColor(settings.fgColor)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: wheelSelectorSize)
                .frame(width: 200)

                // ± buttons (copy of HomogeneousSetPicker pattern, with
                // symmetric horizontal spacing around both glyphs).
                HStack(spacing: buttonPlusMinusGap) {
                    Button {
                        if weightLbs > minWeight {
                            weightLbs = roundToStep(weightLbs - weightStep)
                            feedbackGenerator.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "minus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }

                    Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                    Button {
                        if weightLbs < maxWeight {
                            weightLbs = roundToStep(weightLbs + weightStep)
                            feedbackGenerator.impactOccurred()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }
                }
                .padding(.horizontal, buttonPlusMinusGap)
                .frame(height: buttonPlusMinusHeight)
                .background(settings.fgColor)
                .cornerRadius(settings.cornerRadiusSmall)

                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .bold))
                            Text("Delete Entry")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 10)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(isEditing ? 440 : 380)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            weightLbs = initialWeight()
        }
        .alert("Delete this entry?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { performDelete() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This weight log will be permanently removed.")
        }
    }

    // MARK: - actions

    private func save() {
        if let editingEntry {
            bodyWeight.updateEntry(id: editingEntry.id, weightLbs: weightLbs)
        } else {
            bodyWeight.addEntry(weightLbs: weightLbs)
        }
        dismiss()
    }

    private func performDelete() {
        guard let editingEntry else { return }
        bodyWeight.deleteEntry(id: editingEntry.id)
        dismiss()
    }

    private func initialWeight() -> Double {
        if let editingEntry {
            return roundToStep(editingEntry.weightLbs)
        }
        if let latest = bodyWeight.entries.first {
            return roundToStep(latest.weightLbs)
        }
        return 175.0
    }

    private func roundToStep(_ value: Double) -> Double {
        let step = weightStep
        return (value / step).rounded() * step
    }
}

#Preview("New entry — first time (default 175)") {
    UpdateWeightSheet()
        .environmentObject(BodyWeightViewModel(mockEntries: []))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("New entry — preselects most recent") {
    let vm = BodyWeightViewModel(mockEntries: [
        BodyWeightEntry(date: Date(), weightLbs: 182.5)
    ])
    return UpdateWeightSheet()
        .environmentObject(vm)
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Edit existing entry (delete visible)") {
    let entry = BodyWeightEntry(date: Date().addingTimeInterval(-3 * 86_400), weightLbs: 174.0)
    let vm = BodyWeightViewModel(mockEntries: [entry])
    return UpdateWeightSheet(editingEntry: entry)
        .environmentObject(vm)
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}
