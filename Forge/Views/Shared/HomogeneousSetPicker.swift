import SwiftUI

/// Three-column wheel picker for editing a homogeneous exercise (all sets identical):
/// sets count × weight × reps. Each column has its own +/- buttons.
///
/// Weight is **stored** as Int lb regardless of the active display unit. In
/// kg mode the wheel renders kg-native steps (2.5 kg / matches gym-plate
/// increments); each kg step's `tag` is its rounded-Int lb equivalent, so
/// selection writes back to the lb-typed binding cleanly. Round-tripping a
/// stored value across a unit toggle is slightly lossy (≤ ~1 lb) — accepted
/// per the unit-toggle plan.
struct HomogeneousSetPicker: View {

    @Binding var sets: Int
    @Binding var weight: Int
    @Binding var reps: Int
    @Binding var breakDuration: Int

    let minSets: Int
    let maxSets: Int
    let minWeight: Int
    let maxWeight: Int
    let weightStep: Int
    let minReps: Int
    let maxReps: Int
    let minBreakDuration: Int
    let maxBreakDuration: Int
    let breakDurationStep: Int
    let onBreakDurationChanged: (Int) -> Void

    @EnvironmentObject var settings: GlobalSettings
    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private let buttonPlusMinusIconSize: CGFloat = 15
    private let buttonPlusMinusWidth: CGFloat = 85
    private let buttonPlusMinusHeight: CGFloat = 30
    private let buttonPlusMinusSize: CGFloat = 5
    private let wheelSelectorSize: CGFloat = 150

    // Picker row width is measured live so the break-timer chip can span
    // exactly from the leftmost +/- button's left edge to the rightmost +/-
    // button's right edge. Each +/- button (85pt wide) is centered in its
    // 100pt picker column, so the chip's horizontal inset on each side is
    // (100 - 85) / 2 = 7.5pt → chip width = pickerRowWidth - 15.
    @State private var pickerRowWidth: CGFloat = 0

    private var setsRange: [Int] { Array((minSets...maxSets).reversed()) }
    private var repsRange: [Int] { Array((minReps...maxReps).reversed()) }

    private var weightOptions: [WeightWheelOption] {
        WeightWheelOption.options(
            unit: settings.weightUnit,
            minLb: minWeight,
            maxLb: maxWeight,
            stepLb: weightStep
        )
    }

    /// Snaps `weight` (in lb) to the closest option for the active unit.
    /// In lb mode this is a no-op when `weight` is already a step multiple;
    /// in kg mode it locks the wheel to a kg-step row even though storage
    /// stays in lb.
    private var snappedSelection: Int {
        WeightWheelOption.snap(lb: weight, to: weightOptions)
    }

    private var weightSelection: Binding<Int> {
        Binding(
            get: { snappedSelection },
            set: { weight = $0 }
        )
    }

    private func decrementWeight() {
        if let next = WeightWheelOption.adjacent(below: snappedSelection, in: weightOptions) {
            weight = next
            feedbackGenerator.impactOccurred()
        }
    }

    private func incrementWeight() {
        if let next = WeightWheelOption.adjacent(above: snappedSelection, in: weightOptions) {
            weight = next
            feedbackGenerator.impactOccurred()
        }
    }

    var body: some View {
        VStack(spacing: 16) {
        HStack {

            // SETS SELECTOR
            VStack {
                Picker(selection: $sets, label: Text("Sets")) {
                    ForEach(setsRange, id: \.self) { value in
                        Text("\(value) set\(value == 1 ? "" : "s")")
                            .foregroundColor(settings.fgColor)
                            .tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 100)
                .frame(maxHeight: wheelSelectorSize)

                HStack() {
                    // DECREMENT
                    Button(action: {
                        if sets > minSets {
                            sets -= 1
                            feedbackGenerator.impactOccurred()
                        }
                    }) {
                        Image(systemName: "minus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }

                    Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                    // INCREMENT
                    Button(action: {
                        if sets < maxSets {
                            sets += 1
                            feedbackGenerator.impactOccurred()
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }
                }
                .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                .background(settings.fgColor)
                .cornerRadius(settings.cornerRadiusSmall)
            }

            // "X"
            VStack {
                Image(systemName: "xmark")
                    .foregroundColor(darkGray)
                    .bold()
                Rectangle().frame(width: 1, height: buttonPlusMinusHeight).hidden()
            }

            // WEIGHT SELECTOR
            VStack {
                Picker(selection: weightSelection, label: Text("Weight")) {
                    ForEach(weightOptions, id: \.lbStorage) { opt in
                        Text(opt.display)
                            .foregroundColor(settings.fgColor)
                            .tag(opt.lbStorage)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxHeight: wheelSelectorSize)
                .frame(width: 100)

                HStack() {
                    // DECREMENT
                    Button(action: { decrementWeight() }) {
                        Image(systemName: "minus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }

                    Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                    // INCREMENT
                    Button(action: { incrementWeight() }) {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }
                }
                .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                .background(settings.fgColor)
                .cornerRadius(settings.cornerRadiusSmall)
            }

            // "X"
            VStack {
                Image(systemName: "xmark")
                    .foregroundColor(darkGray)
                    .bold()
                Rectangle().frame(width: 1, height: buttonPlusMinusHeight).hidden()
            }

            // REPS SELECTOR
            VStack {
                Picker(selection: $reps, label: Text("Reps")) {
                    ForEach(repsRange, id: \.self) { value in
                        Text("\(value) rep\(value == 1 ? "" : "s")")
                            .foregroundColor(settings.fgColor)
                            .tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxHeight: wheelSelectorSize)
                .frame(width: 100)

                HStack() {
                    // DECREMENT
                    Button(action: {
                        if reps > minReps {
                            reps -= 1
                            feedbackGenerator.impactOccurred()
                        }
                    }) {
                        Image(systemName: "minus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }

                    Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                    // INCREMENT
                    Button(action: {
                        if reps < maxReps {
                            reps += 1
                            feedbackGenerator.impactOccurred()
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .font(.system(size: buttonPlusMinusIconSize))
                            .bold()
                            .padding(buttonPlusMinusSize)
                    }
                }
                .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                .background(settings.fgColor)
                .cornerRadius(settings.cornerRadiusSmall)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: HomoPickerRowWidthKey.self, value: geo.size.width)
            }
        )

        // BREAK TIMER ROW: [ - | "60s Break Timer" | + ]
        HStack(spacing: 0) {
            // DECREMENT
            Button(action: {
                if breakDuration - breakDurationStep >= minBreakDuration {
                    breakDuration -= breakDurationStep
                    feedbackGenerator.impactOccurred()
                    onBreakDurationChanged(breakDuration)
                }
            }) {
                Image(systemName: "minus")
                    .foregroundColor(.black)
                    .font(.system(size: buttonPlusMinusIconSize))
                    .bold()
                    .frame(width: 42, height: buttonPlusMinusHeight)
            }

            Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

            // LABEL
            Text("\(breakDuration)s Break Timer")
                .foregroundColor(.black)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)

            Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

            // INCREMENT
            Button(action: {
                if breakDuration + breakDurationStep <= maxBreakDuration {
                    breakDuration += breakDurationStep
                    feedbackGenerator.impactOccurred()
                    onBreakDurationChanged(breakDuration)
                }
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.black)
                    .font(.system(size: buttonPlusMinusIconSize))
                    .bold()
                    .frame(width: 42, height: buttonPlusMinusHeight)
            }
        }
        .frame(width: max(0, pickerRowWidth - 15), height: buttonPlusMinusHeight)
        .background(settings.fgColor)
        .cornerRadius(settings.cornerRadiusSmall)
        }
        .onPreferenceChange(HomoPickerRowWidthKey.self) { newValue in
            pickerRowWidth = newValue
        }
    }
}

/// Captures the homogeneous picker row's measured width so the break-timer
/// chip below can size itself to span exactly the leftmost +/- button's
/// left edge to the rightmost +/- button's right edge.
private struct HomoPickerRowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// One row of an exercise weight wheel, factored out so `HomogeneousSetPicker`
/// and `HeterogeneousSetEditor` share the unit-aware option generation +
/// snapping logic.
struct WeightWheelOption {
    /// What the picker stores in its `Binding<Int>` (always lb).
    let lbStorage: Int
    /// User-facing label, e.g. "100 lbs" or "45 kg" / "2.5 kg".
    let display: String

    /// Build the wheel's option list for the active unit. Options are
    /// returned in descending order to match the existing wheel layout
    /// (heaviest at the top of the list, which the picker reverses
    /// vertically for the wheel UI).
    static func options(unit: WeightUnit, minLb: Int, maxLb: Int, stepLb: Int) -> [WeightWheelOption] {
        switch unit {
        case .lb:
            return stride(from: maxLb, through: minLb, by: -stepLb).map {
                WeightWheelOption(lbStorage: $0, display: "\($0) lbs")
            }
        case .kg:
            // Keep the lb bounds intact; iterate kg-native steps within the
            // span and project each to its rounded-Int lb storage value.
            // 2.5-kg steps yield distinct lb integers across the entire
            // [-100, 500] lb range, so option tags stay unique.
            let kgStep = 2.5
            let minKg = (Double(minLb) / WeightUnit.lbsPerKg / kgStep).rounded(.up) * kgStep
            let maxKg = (Double(maxLb) / WeightUnit.lbsPerKg / kgStep).rounded(.down) * kgStep
            var values: [Double] = []
            var v = maxKg
            while v >= minKg - 0.0001 {
                values.append(v)
                v -= kgStep
            }
            return values.map { kg in
                let lb = Int((kg * WeightUnit.lbsPerKg).rounded())
                return WeightWheelOption(lbStorage: lb, display: kgLabel(kg))
            }
        }
    }

    /// Find the option whose stored lb value is closest to the supplied lb.
    /// Used to align the wheel with a stored value that wasn't authored in
    /// the active unit (e.g. 7 lb stored, kg mode → snaps to nearest 2.5-kg
    /// row's lb int).
    static func snap(lb: Int, to options: [WeightWheelOption]) -> Int {
        guard !options.isEmpty else { return lb }
        return options.min(by: { abs($0.lbStorage - lb) < abs($1.lbStorage - lb) })?.lbStorage ?? lb
    }

    /// Step "down" in user-unit (one row toward smaller weight). Returns
    /// nil at the lower bound. Options are descending, so the next-smaller
    /// row is at index + 1.
    static func adjacent(below current: Int, in options: [WeightWheelOption]) -> Int? {
        guard let idx = options.firstIndex(where: { $0.lbStorage == current }),
              idx + 1 < options.count else { return nil }
        return options[idx + 1].lbStorage
    }

    /// Step "up" in user-unit. Returns nil at the upper bound.
    static func adjacent(above current: Int, in options: [WeightWheelOption]) -> Int? {
        guard let idx = options.firstIndex(where: { $0.lbStorage == current }),
              idx - 1 >= 0 else { return nil }
        return options[idx - 1].lbStorage
    }

    private static func kgLabel(_ kg: Double) -> String {
        if kg.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(kg)) kg"
        }
        return String(format: "%.1f kg", kg)
    }
}
