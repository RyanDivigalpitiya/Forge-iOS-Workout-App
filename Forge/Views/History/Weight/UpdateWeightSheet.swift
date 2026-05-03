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
        // Seed the detent with each mode's natural size so the first
        // frame is correct before the GeometryReader fires. iOS sheets
        // honor the initial detent at presentation time and only smooth
        // small changes afterward, so getting the seed right per-mode
        // matters more than relying on dynamic resize alone.
        _measuredContentHeight = State(initialValue: editingEntry == nil ? 420 : 230)
    }

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var weightLbs: Double = 175.0
    @State private var weightText: String = "175.0"
    @State private var showDeleteConfirm = false
    @State private var measuredContentHeight: CGFloat
    @FocusState private var weightFieldFocused: Bool

    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let buttonCircleBgColor = GlobalSettings.shared.buttonCircleBgColor

    private let buttonPlusMinusIconSize: CGFloat = 15
    private let buttonPlusMinusHeight: CGFloat = 32
    private let buttonPlusMinusSize: CGFloat = 5
    private let buttonPlusMinusGap: CGFloat = 14
    private let wheelSelectorSize: CGFloat = 180
    private let fontTitleSize: CGFloat = 28

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private var screenWidth: CGFloat { UIScreen.main.bounds.width }

    private var isEditing: Bool { editingEntry != nil }

    private var title: String { isEditing ? "Delete Entry" : "Update Weight" }

    /// Wheel bounds + step expressed in the *current* display unit. The
    /// kg ranges roughly mirror the lb ones (50 lb ≈ 22.7 kg, 500 lb ≈
    /// 226.8 kg) but snap to clean kg-native step boundaries.
    private var wheelMin: Double {
        switch settings.weightUnit {
        case .lb: return 50
        case .kg: return 22
        }
    }
    private var wheelMax: Double {
        switch settings.weightUnit {
        case .lb: return 500
        case .kg: return 230
        }
    }
    private var wheelStep: Double {
        switch settings.weightUnit {
        case .lb: return 0.5
        case .kg: return 0.25
        }
    }

    private var weightRange: [Double] {
        var values: [Double] = []
        var v = wheelMax
        while v >= wheelMin - 0.0001 {
            values.append(v)
            v -= wheelStep
        }
        return values
    }

    /// Wheel selection: round-tripped through lb storage, but exposed
    /// to the wheel in the current display unit. Setting through this
    /// binding is the authoritative way the wheel updates `weightLbs`.
    private var wheelSelection: Binding<Double> {
        Binding(
            get: { roundToStep(userUnitValue(weightLbs)) },
            set: { newUnitValue in
                weightLbs = lbsValue(newUnitValue)
            }
        )
    }

    private func userUnitValue(_ lbs: Double) -> Double {
        switch settings.weightUnit {
        case .lb: return lbs
        case .kg: return WeightUnit.lbsToKg(lbs)
        }
    }

    private func lbsValue(_ unitValue: Double) -> Double {
        switch settings.weightUnit {
        case .lb: return unitValue
        case .kg: return WeightUnit.kgToLbs(unitValue)
        }
    }

    var body: some View {
        // ScrollView wrapper mirrors the gap-free top-toolbar layout from
        // ExerciseEditorView. Scrolling is disabled because the detent is
        // sized to the inner content (no overflow to scroll).
        ScrollView {
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
                    if !isEditing {
                        Button {
                            save()
                        } label: {
                            ZStack {
                                Circle()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(buttonCircleBgColor)
                                Image(systemName: "arrow.up")
                                    .resizable()
                                    .frame(width: 13, height: 13)
                                    .fontWeight(.bold)
                                    .foregroundColor(settings.fgColor)
                            }
                        }
                    }
                }
                .frame(width: 0.2 * screenWidth)
            }
            .padding(.top, 20)

            Spacer().frame(height: 10)

            if isEditing {
                deleteContent
            } else {
                addContent
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
        } // end ScrollView
        .scrollDisabled(true)
        .onPreferenceChange(SheetContentHeightKey.self) { newHeight in
            // Discard garbage values from incomplete layout passes
            // (sometimes SwiftUI emits a 0 before the first real
            // measurement). 150pt covers the smaller delete-mode body
            // (~210pt) while still rejecting spurious pre-layout readings.
            let rounded = newHeight.rounded()
            guard rounded > 150 else { return }
            if abs(rounded - measuredContentHeight) > 1 {
                measuredContentHeight = rounded
            }
        }
        .presentationDetents([.height(measuredContentHeight)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            let initial = initialWeight()
            weightLbs = initial
            weightText = formatForField(userUnitValue(initial))
        }
        .onChange(of: weightLbs) { _, newValue in
            // Wheel scroll or ± tap → reflect step-aligned value in
            // field. Compare in user-unit so the loop guard is
            // accurate after a unit toggle.
            let inUnit = userUnitValue(newValue)
            if Double(weightText) != inUnit {
                weightText = formatForField(inUnit)
            }
        }
        .onChange(of: weightText) { _, newText in
            // User typing → parse as user-unit, convert to lb, push into
            // weightLbs. Skip update mid-edit (empty / partial /
            // out-of-range) so the wheel doesn't jump to nonsense.
            guard let parsed = Double(newText),
                  parsed >= wheelMin,
                  parsed <= wheelMax
            else { return }
            let asLbs = lbsValue(parsed)
            if abs(asLbs - weightLbs) > 0.001 {
                weightLbs = asLbs
            }
        }
        .onChange(of: settings.weightUnit) { _, _ in
            // Unit toggle → re-render the text field in the new unit
            // without changing weightLbs (the source of truth).
            weightText = formatForField(userUnitValue(weightLbs))
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

    // MARK: - mode-specific content

    /// Add-mode body: weight input field + wheel + ± buttons.
    @ViewBuilder
    private var addContent: some View {
        VStack(spacing: 8) {

            // Numeric text field — accepts arbitrary decimal lbs
            // (e.g. 175.23). Wheel and ± below overwrite this with
            // step-aligned values; typing here overrides them.
            HStack(spacing: 8) {
                TextField("0", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(settings.fgColor)
                    .focused($weightFieldFocused)
                    .fixedSize(horizontal: true, vertical: false)
                Text(settings.weightUnit.pluralLabel)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(darkGray)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            Picker(selection: wheelSelection, label: Text("Weight")) {
                ForEach(weightRange, id: \.self) { value in
                    Text("\(formatForField(value)) \(settings.weightUnit.shortLabel)")
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
                    let current = userUnitValue(weightLbs)
                    if current > wheelMin {
                        weightLbs = lbsValue(roundToStep(current - wheelStep))
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
                    let current = userUnitValue(weightLbs)
                    if current < wheelMax {
                        weightLbs = lbsValue(roundToStep(current + wheelStep))
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
        }
    }

    /// Delete-mode body: read-only entry summary + a single destructive
    /// action. No editing controls — past entries can be removed but not
    /// modified, so the user re-logs from scratch if they need to fix one.
    @ViewBuilder
    private var deleteContent: some View {
        if let entry = editingEntry {
            VStack(spacing: 12) {
                Spacer().frame(height: 18)

                Text(WeightUnit.formatWeight(lbs: entry.weightLbs, in: settings.weightUnit))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(settings.fgColor)

                Text(entryDateLabel(for: entry.date))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(darkGray)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Delete Entry")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 28)
                    .background(settings.fgColor, in: Capsule())
                }
                .padding(.top, 18)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// "Today" / "Yesterday" / "N days ago" / "Mar 15, 2026" — same family
    /// as the timeline label but with a year suffix for the deletion
    /// confirmation context, where ambiguity matters more.
    private func entryDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        if let day = components.day, day > 0, day < 30 {
            return "\(day) days ago"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    // MARK: - actions

    private func save() {
        // Save is only reachable in add mode — the toolbar's save button
        // is hidden when an entry is being targeted for deletion.
        bodyWeight.addEntry(weightLbs: weightLbs)
        dismiss()
    }

    private func performDelete() {
        guard let editingEntry else { return }
        bodyWeight.deleteEntry(id: editingEntry.id)
        dismiss()
    }

    private func initialWeight() -> Double {
        // Add-mode preselection: the most recent entry, or 175 lb on
        // first run. Edit-mode never reaches the wheel — its body uses a
        // read-only summary instead.
        if let latest = bodyWeight.entries.first {
            return latest.weightLbs
        }
        return 175.0
    }

    /// Snap a *user-unit* value to the wheel's step grid (0.5 lb / 0.25 kg).
    private func roundToStep(_ unitValue: Double) -> Double {
        let step = wheelStep
        return (unitValue / step).rounded() * step
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
