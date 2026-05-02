import SwiftUI

/// Per-set editor for an exercise with heterogeneous (unique) sets.
/// Shows one row per set with weight controls, reps controls, till-failure toggle, and a delete button.
/// Also includes the "Add Set" button at the bottom and a "Save" button (the latter is a duplicate of
/// the top-toolbar Save in `ExerciseEditorView`).
struct HeterogeneousSetEditor: View {

    @Binding var weights: [Int]
    @Binding var reps: [Int]
    @Binding var failure: [Bool]

    let minWeight: Int
    let maxWeight: Int
    let weightStep: Int
    let minReps: Int
    let maxReps: Int
    let maxSets: Int

    let isSaveDisabled: Bool
    let onSave: () -> Void

    @EnvironmentObject var settings: GlobalSettings
    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private let fontSize: CGFloat = 21
    private let buttonPlusMinusIconSize: CGFloat = 15
    private let buttonPlusMinusWidth: CGFloat = 85
    private let buttonPlusMinusHeight: CGFloat = 30
    private let buttonPlusMinusSize: CGFloat = 5

    /// Wheel options for the active unit. Recomputed on every body eval —
    /// the array is only ~120 entries and is needed for snap + step in the
    /// ± button handlers.
    private var currentOptions: [WeightWheelOption] {
        WeightWheelOption.options(
            unit: settings.weightUnit,
            minLb: minWeight,
            maxLb: maxWeight,
            stepLb: weightStep
        )
    }

    /// Display label for a stored lb value in the active unit. Snaps to
    /// the nearest wheel option so the on-screen number always matches the
    /// row the wheel/± buttons would land on after the next interaction.
    private func weightLabel(for lb: Int) -> String {
        let snapped = WeightWheelOption.snap(lb: lb, to: currentOptions)
        return currentOptions.first { $0.lbStorage == snapped }?.display ?? "\(lb) lbs"
    }

    var body: some View {
        VStack {
            ForEach(weights.indices, id: \.self) { setIndex in

                // SET ROW
                HStack() {
                    HStack { // internal padding hstack

                        // SET LABEL + DELETE BUTTON
                        VStack {
                            // SET LABEL
                            Text("Set \(setIndex+1)")
                                .foregroundColor(darkGray)
                                .fontWeight(.bold)
                                .font(.system(size: fontSize))
                                .frame(width: 70)

                            // DELETE BUTTON
                            Button(action: {
                                if weights.count > 1 {
                                    weights.remove(at: setIndex)
                                    reps.remove(at: setIndex)
                                    failure.remove(at: setIndex)
                                }
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.black)
                                    .font(.system(size: buttonPlusMinusIconSize))
                                    .bold()
                                    .padding(buttonPlusMinusSize)
                            }
                            .frame(width: 60, height: buttonPlusMinusHeight)
                            .background(settings.fgColor)
                            .cornerRadius(settings.cornerRadiusSmall)
                        }
                        .padding(.trailing, 10)


                        // WEIGHT LABEL + PLUS/MINUS BUTTONS
                        VStack {
                            Text(weightLabel(for: weights[setIndex]))
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .font(.system(size: fontSize))
                                .frame(width: 100)

                            HStack() {
                                // DECREMENT — step "down" in the active unit
                                // (5 lb in lb mode, 2.5 kg in kg mode).
                                Button(action: {
                                    let opts = currentOptions
                                    let snapped = WeightWheelOption.snap(lb: weights[setIndex], to: opts)
                                    if let next = WeightWheelOption.adjacent(below: snapped, in: opts) {
                                        weights[setIndex] = next
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
                                    let opts = currentOptions
                                    let snapped = WeightWheelOption.snap(lb: weights[setIndex], to: opts)
                                    if let next = WeightWheelOption.adjacent(above: snapped, in: opts) {
                                        weights[setIndex] = next
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
                            Rectangle().frame(width: 1, height: buttonPlusMinusHeight)
                                .hidden()
                                .padding(.bottom, 9)
                        }
                        .padding(.horizontal, -5)

                        // REPS LABEL + PLUS/MINUS BUTTONS
                        VStack {
                            if failure[setIndex] {
                                Text("till Failure")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .font(.system(size: fontSize))
                                    .frame(width: 120)
                            } else {
                                Text("\(reps[setIndex]) rep\(reps[setIndex] == 1 ? "" : "s")")
                                    .foregroundColor(.white)
                                    .fontWeight(.bold)
                                    .font(.system(size: fontSize))
                                    .frame(width: 120)
                            }

                            HStack() {
                                // DECREMENT
                                Button(action: {
                                    if reps[setIndex] > minReps {
                                        reps[setIndex] -= 1
                                        feedbackGenerator.impactOccurred()
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .foregroundColor(.black)
                                        .font(.system(size: buttonPlusMinusIconSize))
                                        .bold()
                                        .padding(buttonPlusMinusSize)
                                }
                                .disabled(failure[setIndex])

                                Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                                // INCREMENT
                                Button(action: {
                                    if reps[setIndex] < maxReps {
                                        reps[setIndex] += 1
                                        feedbackGenerator.impactOccurred()
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .foregroundColor(.black)
                                        .font(.system(size: buttonPlusMinusIconSize))
                                        .bold()
                                        .padding(buttonPlusMinusSize)
                                }
                                .disabled(failure[setIndex])

                                Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)

                                // TILL FAILURE (∞) BUTTON
                                Button(action: {
                                    failure[setIndex].toggle()
                                }) {
                                    Image(systemName: "infinity")
                                        .foregroundColor(failure[setIndex] ? .white : .black)
                                        .font(.system(size: buttonPlusMinusIconSize))
                                        .bold()
                                        .padding(buttonPlusMinusSize)
                                }
                            }
                            .frame(width: buttonPlusMinusWidth + 50, height: buttonPlusMinusHeight)
                            .background(settings.fgColor)
                            .cornerRadius(settings.cornerRadiusSmall)
                        }
                    }
                }
                .frame(height: 100)
                .padding(.top, 10)
                .cornerRadius(20)
            }

            // ADD SET BUTTON
            Button(action: {
                guard weights.count < maxSets else { return }
                if let lastWeight = weights.last { weights.append(lastWeight) }
                if let lastReps = reps.last { reps.append(lastReps) }
                if let lastFailure = failure.last { failure.append(lastFailure) }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Set").fontWeight(.bold)
                }
                .frame(height: 20)
                .foregroundColor(settings.fgColor)
            }
            .padding(.top, 20)

            // SAVE BUTTON
            HStack {
                Button(action: {
                    onSave()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                        Text("Save")
                            .fontWeight(.bold)
                    }
                    .padding(EdgeInsets(top: 6, leading: 13, bottom: 6, trailing: 14))
                    .foregroundColor(settings.fgColor)
                    .background(Color(red: 0.17, green: 0.17, blue: 0.18))
                    .cornerRadius(100)
                }
                .disabled(isSaveDisabled)
            }
            .padding(20)
        }
    }
}
