import SwiftUI

/// Bottom sheet for entering / clearing the user's height (the input that
/// powers the BMI parenthetical in `WeightHistoryView`). Dual mode based
/// on the active weight unit: ft + in fields in lb mode, cm field in kg
/// mode. Source-of-truth is `settings.heightCm` — fields are local mirrors
/// hydrated on appear and on unit toggle.
private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct EditHeightSheet: View {

    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var feetText: String = ""
    @State private var inchesText: String = ""
    @State private var cmText: String = ""
    @State private var measuredContentHeight: CGFloat = 320

    @FocusState private var focusedField: Field?
    private enum Field { case feet, inches, cm }

    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let buttonCircleBgColor = GlobalSettings.shared.buttonCircleBgColor
    private let fontTitleSize: CGFloat = 26

    private var screenWidth: CGFloat { UIScreen.main.bounds.width }

    private var draftCm: Double? {
        switch settings.weightUnit {
        case .lb:
            guard let feet = Int(feetText), feet >= 0 else { return nil }
            let inches = Double(inchesText) ?? 0
            let cm = WeightUnit.feetInchesToCm(feet: feet, inches: inches)
            return cm > 0 ? cm : nil
        case .kg:
            guard let cm = Double(cmText), cm > 0 else { return nil }
            return cm
        }
    }

    private var hasUnsavedChanges: Bool {
        guard let draft = draftCm else { return false }
        if let saved = settings.heightCm {
            // 0.1 cm tolerance — round-trip ft/in → cm conversion can drift
            // sub-millimetre amounts, and we don't want a permanently-active
            // Save button after a successful save.
            return abs(draft - saved) > 0.1
        }
        return true
    }

    private var canSave: Bool { draftCm != nil && hasUnsavedChanges }

    var body: some View {
        VStack(spacing: 0) {

            // TOP TOOLBAR — X | title | up-arrow (matches UpdateWeightSheet)
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
                    Text("Height")
                        .font(.system(size: fontTitleSize))
                        .foregroundColor(settings.fgColor)
                        .fontWeight(.bold)
                        .lineLimit(1)
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
                            Image(systemName: "arrow.up")
                                .resizable()
                                .frame(width: 13, height: 13)
                                .fontWeight(.bold)
                                .foregroundColor(canSave ? settings.fgColor : darkGray)
                        }
                    }
                    .disabled(!canSave)
                }
                .frame(width: 0.2 * screenWidth)
            }
            .padding(.top, 18)

            Spacer().frame(height: 24)

            // INPUT FIELD(S)
            VStack(spacing: 12) {
                inputFields

                Text("Used to calculate BMI on your weight log.")
                    .font(.system(size: 12))
                    .foregroundColor(darkGray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                if settings.heightCm != nil {
                    Button(role: .destructive) {
                        clear()
                    } label: {
                        Text("Clear Height")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(settings.fgColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 20)
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
            let rounded = newHeight.rounded()
            guard rounded > 200 else { return }
            if abs(rounded - measuredContentHeight) > 1 {
                measuredContentHeight = rounded
            }
        }
        .presentationDetents([.height(measuredContentHeight)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            hydrateFields()
            // Auto-focus the first field — small delay so the sheet
            // present transition completes before focus assignment
            // (otherwise iOS silently drops the request).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField = settings.weightUnit == .lb ? .feet : .cm
            }
        }
        .onChange(of: settings.weightUnit) { _, _ in
            hydrateFields()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .fontWeight(.bold)
            }
        }
    }

    @ViewBuilder
    private var inputFields: some View {
        HStack(spacing: 10) {
            switch settings.weightUnit {
            case .lb:
                TextField("0", text: $feetText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(settings.fgColor)
                    .focused($focusedField, equals: .feet)
                    .frame(width: 60)
                Text("ft")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(darkGray)
                TextField("0", text: $inchesText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(settings.fgColor)
                    .focused($focusedField, equals: .inches)
                    .frame(width: 80)
                Text("in")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(darkGray)
            case .kg:
                TextField("0", text: $cmText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(settings.fgColor)
                    .focused($focusedField, equals: .cm)
                    .frame(width: 120)
                Text("cm")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(darkGray)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard let cm = draftCm else { return }
        settings.heightCm = cm
        dismiss()
    }

    private func clear() {
        settings.heightCm = nil
        dismiss()
    }

    private func hydrateFields() {
        guard let cm = settings.heightCm else {
            feetText = ""
            inchesText = ""
            cmText = ""
            return
        }
        let split = WeightUnit.cmToFeetInches(cm)
        feetText = String(split.feet)
        inchesText = formatField(split.inches)
        cmText = formatField(cm)
    }

    private func formatField(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

#Preview("No height set") {
    Color.black.sheet(isPresented: .constant(true)) {
        EditHeightSheet()
            .environmentObject(GlobalSettings.shared)
            .environment(\.colorScheme, .dark)
    }
}

#Preview("Height set (lb mode)") {
    let settings = GlobalSettings.shared
    settings.weightUnit = .lb
    settings.heightCm = 180.34
    return Color.black.sheet(isPresented: .constant(true)) {
        EditHeightSheet()
            .environmentObject(settings)
            .environment(\.colorScheme, .dark)
    }
}
