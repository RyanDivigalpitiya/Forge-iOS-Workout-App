import SwiftUI

/// Plumbs the content VStack's measured height up to the sheet so we
/// can pin a `.height(measured)` detent that hugs the actual content.
/// Avoids the wasted 50% lower half of the default `.medium` detent.
private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

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
    @State private var weightText: String = "175.0"
    @State private var showDeleteConfirm = false
    @State private var measuredContentHeight: CGFloat = 420
    @FocusState private var weightFieldFocused: Bool

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

            // WEIGHT INPUT (above wheel) + WHEEL + ± buttons
            VStack(spacing: 8) {

                // Numeric text field — accepts arbitrary decimal lbs
                // (e.g. 175.23). Wheel and ± below overwrite this with
                // step-aligned values; typing here overrides them.
                HStack(spacing: 8) {
                    TextField("", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(settings.fgColor)
                        .focused($weightFieldFocused)
                        .frame(width: 140)
                    Text("lbs")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(darkGray)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

                Picker(selection: $weightLbs, label: Text("Weight")) {
                    ForEach(weightRange, id: \.self) { value in
                        Text(WeightUnit.formatLbs(value))
                            .foregroundColor(settings.fgColor)
                            .tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 200, height: wheelSelectorSize)

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
                        Text("Delete Entry")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(settings.fgColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 10)
                }
            }

            Spacer().frame(height: 16)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SheetContentHeightKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(SheetContentHeightKey.self) { newHeight in
            // Discard garbage values from incomplete layout passes
            // (sometimes SwiftUI emits a 0 before the first real
            // measurement). 200pt is well below any plausible content
            // height for this sheet — anything smaller is a spurious
            // pre-layout reading.
            let rounded = newHeight.rounded()
            guard rounded > 200 else { return }
            if abs(rounded - measuredContentHeight) > 1 {
                measuredContentHeight = rounded
            }
        }
        .presentationDetents([.height(measuredContentHeight)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            let initial = initialWeight()
            weightLbs = initial
            weightText = formatForField(initial)
        }
        .onChange(of: weightLbs) { _, newValue in
            // Wheel scroll or ± tap → reflect step-aligned value in field.
            // Guard against the loop where text-driven changes already
            // produced this same number.
            if Double(weightText) != newValue {
                weightText = formatForField(newValue)
            }
        }
        .onChange(of: weightText) { _, newText in
            // User typing → push parsed value into weightLbs. Skip update
            // mid-edit (empty / partial / out-of-range) so the wheel
            // doesn't jump to nonsense before the user finishes typing.
            guard let parsed = Double(newText),
                  parsed >= minWeight,
                  parsed <= maxWeight,
                  parsed != weightLbs
            else { return }
            weightLbs = parsed
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { weightFieldFocused = false }
                    .fontWeight(.bold)
            }
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

    /// Bare numeric string for the text field. Strips a trailing ".0"
    /// for whole numbers but keeps any other decimal part the user
    /// might have typed in.
    private func formatForField(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
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
