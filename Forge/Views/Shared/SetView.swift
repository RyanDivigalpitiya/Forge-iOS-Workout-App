import SwiftUI

struct SetView: View {

    enum Content {
        // Renders one set with its index: "Set 1 • 100 lb × 12 reps"
        case individual(set: Set, index: Int)
        // Renders a count summary: "3 sets × 100 lb × 12 reps"
        case summary(count: Int, firstSet: Set?)
    }

    enum Appearance {
        case standard                               // PlanEditor: solid accent-color label, dark text
        case muted                                  // History: buttonCircleBgColor label, white text
        case workoutActive(isCompleted: Bool)       // Workout: animated strikethrough + dimmed when completed
        case workoutActiveCollab(isCompleted: Bool) // Joint workout: weight/reps rendered as grey label chips so the compressed horizontal budget still fits
    }

    let content: Content
    let appearance: Appearance

    @EnvironmentObject var settings: GlobalSettings
    private let bgColor = GlobalSettings.shared.bgColor
    private let setsFontSize = GlobalSettings.shared.setsFontSize
    private let setsSpacing = GlobalSettings.shared.setsSpacing

    var body: some View {
        let labelText: String
        let labelCount: Int  // for width threshold (number to render)
        let weight: Float?
        let reps: Int?
        let tillFailure: Bool

        switch content {
        case .individual(let set, let index):
            labelText = "Set \(index + 1)"
            labelCount = index + 1
            weight = set.weight
            reps = set.reps
            tillFailure = set.tillFailure
        case .summary(let count, let firstSet):
            labelText = "\(count) set\(count == 1 ? "" : "s")"
            labelCount = count
            weight = firstSet?.weight
            reps = firstSet?.reps
            tillFailure = false
        }

        let isCompleted: Bool = {
            switch appearance {
            case .workoutActive(let c), .workoutActiveCollab(let c): return c
            default: return false
            }
        }()

        let isCollabActive: Bool = {
            if case .workoutActiveCollab = appearance { return true }
            return false
        }()

        let isWorkoutActiveMode: Bool = {
            switch appearance {
            case .workoutActive, .workoutActiveCollab: return true
            default: return false
            }
        }()

        let labelWidth: CGFloat = {
            if isCollabActive {
                return labelCount > 9 ? 54 : 46
            } else {
                return labelCount > 9 ? 67 : 58
            }
        }()

        let labelBg: Color = {
            switch appearance {
            case .standard, .workoutActive, .workoutActiveCollab: return settings.fgColor
            case .muted: return GlobalSettings.shared.buttonCircleBgColor
            }
        }()

        let labelTextColor: Color = {
            switch appearance {
            case .standard, .workoutActive, .workoutActiveCollab: return bgColor
            case .muted: return .white
            }
        }()

        let setLabelFontSize: CGFloat = isCollabActive ? 13 : 16

        return ZStack {
            HStack {
                Text(labelText)
                    .font(.system(size: setLabelFontSize))
                    .foregroundColor(labelTextColor)
                    .frame(width: labelWidth, height: 28)
                    .background(labelBg)
                    .cornerRadius(settings.cornerRadiusSmall)
                    .padding(.trailing, setsSpacing + 2)
                    .opacity(isCompleted ? 0.5 : 1)

                if let weight, let reps {
                    let weightString = WeightUnit.formatWeight(lbs: Double(weight), in: settings.weightUnit)
                    if isCollabActive {
                        let detail: String = tillFailure
                            ? "\(weightString) x Until Failure"
                            : "\(weightString) x \(reps) rep\(reps == 1 ? "" : "s")"
                        collabChip(detail, isCompleted: isCompleted)
                    } else {
                        Text(weightString)
                            .foregroundColor(.white)
                            .padding(.trailing, setsSpacing)
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 10, height: 10)
                            .padding(.top, 3)
                            .foregroundColor(.gray)
                            .opacity(0.6)
                            .padding(.trailing, setsSpacing)

                        if tillFailure {
                            Text("Until Failure").foregroundColor(.gray).opacity(0.6)
                        } else {
                            Text("\(reps) rep\(reps == 1 ? "" : "s")").foregroundColor(.gray).opacity(0.6)
                        }
                    }
                } else {
                    Text("No sets")
                        .foregroundColor(.gray)
                        .opacity(0.6)
                }
                Spacer()
            }
            .fontWeight(.bold)
            .font(.system(size: setsFontSize))
            .opacity(isCompleted ? 0.3 : 1)

            // Strikethrough overlay — emitted for both workoutActive variants.
            // Conditional values preserve the original animation: width 0→∞,
            // opacity 0→1, offset -20→-10 all interpolate together when the
            // parent's withAnimation block toggles `isCompleted`.
            if isWorkoutActiveMode {
                HStack {
                    Rectangle()
                        .frame(width: isCompleted ? .infinity : 0, height: 2)
                        .opacity(isCompleted ? 1 : 0)
                    Spacer()
                }
                .offset(x: isCompleted ? -10 : -20, y: 0)
            }
        }
    }

    /// Collab-mode weight / reps chip — same shape as the "Set N" label but
    /// smaller font and grey background so two narrow chips fit in the
    /// compressed horizontal budget of a joint-mode set row.
    private func collabChip(_ text: String, isCompleted: Bool) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.white)
            .lineLimit(1)
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(GlobalSettings.shared.buttonCircleBgColor)
            .cornerRadius(settings.cornerRadiusSmall)
            .padding(.trailing, setsSpacing)
            .opacity(isCompleted ? 0.5 : 1)
    }
}

struct SetView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSet = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
        VStack(spacing: 20) {
            SetView(content: .individual(set: mockSet, index: 0), appearance: .standard)
            SetView(content: .individual(set: mockSet, index: 0), appearance: .muted)
            SetView(content: .individual(set: mockSet, index: 0), appearance: .workoutActive(isCompleted: false))
            SetView(content: .individual(set: mockSet, index: 0), appearance: .workoutActive(isCompleted: true))
            SetView(content: .summary(count: 3, firstSet: mockSet), appearance: .standard)
        }
        .padding()
        .background(GlobalSettings.shared.bgColor)
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
    }
}
