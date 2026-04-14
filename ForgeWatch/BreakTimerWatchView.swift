import SwiftUI

/// Watch face for the break timer. Three states: idle, counting down, expired.
/// Uses TimelineView for countdown updates (same pattern as the iOS BreakTimerView).
struct BreakTimerWatchView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager

    private let fgColor = Color(red: 1.0, green: 67.0 / 255.0, blue: 107.0 / 255.0)  // #FF436B

    var body: some View {
        switch sessionManager.timerState {
        case .idle:
            idleView
        case let .counting(endDate, duration, exerciseName, setDescription):
            countingView(endDate: endDate, duration: duration,
                         exerciseName: exerciseName, setDescription: setDescription)
        case let .expired(exerciseName, setDescription):
            expiredView(exerciseName: exerciseName, setDescription: setDescription)
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 36))
                .foregroundColor(fgColor)
            Text("Forge")
                .font(.headline)
                .foregroundColor(.white)
        }
    }

    // MARK: - Counting

    private func countingView(endDate: Date, duration: Int,
                              exerciseName: String, setDescription: String) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(endDate.timeIntervalSince(context.date)))
            let progress = duration > 0 ? CGFloat(remaining) / CGFloat(duration) : 0

            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(Color(.darkGray))
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .foregroundColor(fgColor)
                        .rotationEffect(.degrees(-90))
                    Text("\(remaining)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .frame(width: 90, height: 90)

                if !exerciseName.isEmpty {
                    VStack(spacing: 2) {
                        Text("Up Next")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(exerciseName)
                            .font(.caption)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
            .onChange(of: remaining) { _, newValue in
                if newValue == 0 {
                    sessionManager.timerState = .expired(
                        exerciseName: exerciseName,
                        setDescription: setDescription
                    )
                    sessionManager.playHaptic()
                }
            }
        }
    }

    // MARK: - Expired

    private func expiredView(exerciseName: String, setDescription: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.functional")
                .font(.system(size: 28))
                .foregroundColor(fgColor)
            Text("Start Next Set")
                .font(.headline)
                .foregroundColor(fgColor)
            if !exerciseName.isEmpty {
                Text(exerciseName)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            if !setDescription.isEmpty {
                Text(setDescription)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
    }
}
