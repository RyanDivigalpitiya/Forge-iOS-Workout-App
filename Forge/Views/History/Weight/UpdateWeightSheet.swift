import SwiftUI

struct UpdateWeightSheet: View {

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var weightLbs: Double = 175.0

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
                    Text("Update Weight")
                        .font(.system(size: fontTitleSize))
                        .foregroundColor(settings.fgColor)
                        .fontWeight(.bold)
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
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            weightLbs = mostRecentOrDefault()
        }
    }

    private func save() {
        bodyWeight.addEntry(weightLbs: weightLbs)
        dismiss()
    }

    private func mostRecentOrDefault() -> Double {
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

#Preview("First entry (default 175)") {
    UpdateWeightSheet()
        .environmentObject(BodyWeightViewModel(mockEntries: []))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("With prior entry (preselects last)") {
    let vm = BodyWeightViewModel(mockEntries: [
        BodyWeightEntry(date: Date(), weightLbs: 182.5)
    ])
    return UpdateWeightSheet()
        .environmentObject(vm)
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}
