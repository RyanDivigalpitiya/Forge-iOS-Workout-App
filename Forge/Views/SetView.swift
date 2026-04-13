import SwiftUI

struct SetView: View {

    enum Content {
        // Renders one set with its index: "Set 1 • 100 lb × 12 reps"
        case individual(set: Set, index: Int)
        // Renders a count summary: "3 sets × 100 lb × 12 reps"
        case summary(count: Int, firstSet: Set?)
    }

    enum Appearance {
        case standard                           // PlanEditor: solid fgColor label, dark text
        case muted                              // History: buttonCircleBgColor label, white text
        case workoutActive(isCompleted: Bool)   // Workout: animated strikethrough + dimmed when completed
    }

    let content: Content
    let appearance: Appearance

    private let fgColor = GlobalSettings.shared.fgColor
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
            if case .workoutActive(let completed) = appearance { return completed }
            return false
        }()

        let labelWidth: CGFloat = labelCount > 9 ? 67 : 58

        let labelBg: Color = {
            switch appearance {
            case .standard, .workoutActive: return fgColor
            case .muted: return GlobalSettings.shared.buttonCircleBgColor
            }
        }()

        let labelTextColor: Color = {
            switch appearance {
            case .standard, .workoutActive: return bgColor
            case .muted: return .white
            }
        }()

        return ZStack {
            HStack {
                Text(labelText)
                    .font(.system(size: 16))
                    .foregroundColor(labelTextColor)
                    .frame(width: labelWidth, height: 28)
                    .background(labelBg)
                    .cornerRadius(5)
                    .padding(.trailing, setsSpacing + 2)
                    .opacity(isCompleted ? 0.5 : 1)

                if let weight, let reps {
                    Text("\(Int(weight)) lb")
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

            // Strikethrough overlay — only emitted for workoutActive.
            // Conditional values preserve the original animation: width 0→∞,
            // opacity 0→1, offset -20→-10 all interpolate together when the
            // parent's withAnimation block toggles `isCompleted`.
            if case .workoutActive = appearance {
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
        .preferredColorScheme(.dark)
    }
}
