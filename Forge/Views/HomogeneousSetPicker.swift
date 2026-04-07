import SwiftUI

/// Three-column wheel picker for editing a homogeneous exercise (all sets identical):
/// sets count × weight × reps. Each column has its own +/- buttons.
struct HomogeneousSetPicker: View {

    @Binding var sets: Int
    @Binding var weight: Int
    @Binding var reps: Int

    let minSets: Int
    let maxSets: Int
    let minWeight: Int
    let maxWeight: Int
    let weightStep: Int
    let minReps: Int
    let maxReps: Int

    private let fgColor = GlobalSettings.shared.fgColor
    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    private let buttonPlusMinusIconSize: CGFloat = 15
    private let buttonPlusMinusWidth: CGFloat = 85
    private let buttonPlusMinusHeight: CGFloat = 30
    private let buttonPlusMinusSize: CGFloat = 5
    private let wheelSelectorSize: CGFloat = 150

    private var setsRange: [Int] { Array((minSets...maxSets).reversed()) }
    private var weightRange: [Int] { Array(stride(from: maxWeight, through: minWeight, by: -weightStep)) }
    private var repsRange: [Int] { Array((minReps...maxReps).reversed()) }

    var body: some View {
        HStack {

            // SETS SELECTOR
            VStack {
                Picker(selection: $sets, label: Text("Sets")) {
                    ForEach(setsRange, id: \.self) { value in
                        Text("\(value) sets")
                            .foregroundColor(fgColor)
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
                .background(fgColor)
                .cornerRadius(5)
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
                Picker(selection: $weight, label: Text("Weight")) {
                    ForEach(weightRange, id: \.self) { value in
                        Text("\(value) lbs")
                            .foregroundColor(fgColor)
                            .tag(value)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(maxHeight: wheelSelectorSize)
                .frame(width: 100)

                HStack() {
                    // DECREMENT
                    Button(action: {
                        if weight > minWeight {
                            weight -= weightStep
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
                        if weight < maxWeight {
                            weight += weightStep
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
                .background(fgColor)
                .cornerRadius(5)
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
                        Text("\(value) reps")
                            .foregroundColor(fgColor)
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
                .background(fgColor)
                .cornerRadius(5)
            }
        }
    }
}
