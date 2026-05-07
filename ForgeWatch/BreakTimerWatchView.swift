import SwiftUI
import WatchKit

/// Watch face for the workout companion. States:
/// - idle (no workout) → dumbbell + "Forge"
/// - idle (mid-workout, no break) → exercise + set description + Complete button
/// - idle (workout fully complete) → "All Sets Complete — Finish on iPhone"
/// - counting → countdown ring + "Up Next"
/// - expired → "Start Next Set" + Complete button
/// Uses TimelineView for countdown updates (same pattern as the iOS BreakTimerView).
struct BreakTimerWatchView: View {

    @EnvironmentObject var sessionManager: WatchSessionManager

    private let fgColor = Color(red: 1.0, green: 67.0 / 255.0, blue: 107.0 / 255.0)  // #FF436B

    var body: some View {
        switch sessionManager.timerState {
        case .idle:
            idleBranch
        case let .counting(endDate, duration, exerciseName, setDescription):
            countingView(endDate: endDate, duration: duration,
                         exerciseName: exerciseName, setDescription: setDescription)
        case let .expired(exerciseName, setDescription):
            expiredView(exerciseName: exerciseName, setDescription: setDescription)
        }
    }

    // MARK: - Idle branch

    @ViewBuilder
    private var idleBranch: some View {
        if let info = sessionManager.currentSetInfo {
            if info.isAwaitingFinish {
                awaitingFinishView
            } else {
                nextSetView(info: info)
            }
        } else {
            idleView
        }
    }

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

    private func nextSetView(info: WatchSessionManager.SetInfo) -> some View {
        VStack(spacing: 8) {
            if !info.exerciseName.isEmpty {
                Text(info.exerciseName)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            if !info.setDescription.isEmpty {
                Text(info.setDescription)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            completeButton(info: info)
        }
        .padding(.horizontal, 8)
    }

    private var awaitingFinishView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(fgColor)
            Text("All Sets Complete")
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Finish on iPhone")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
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
        }
        .onAppear {
            // If the timer already expired while the app was not visible, sync the UI
            // immediately instead of leaving the countdown stuck at 0.
            sessionManager.syncExpiredStateIfNeeded(for: endDate)
        }
    }

    // MARK: - Expired

    private func expiredView(exerciseName: String, setDescription: String) -> some View {
        VStack(spacing: 6) {
            Text("Start Next Set")
                .font(.subheadline)
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
            if let info = sessionManager.currentSetInfo, !info.isAwaitingFinish {
                completeButton(info: info)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Shared

    private func completeButton(info: WatchSessionManager.SetInfo) -> some View {
        Button {
            sessionManager.sendSetCompleted(
                exerciseIndex: info.exerciseIndex,
                setIndex: info.setIndex
            )
            WKInterfaceDevice.current().play(.click)
        } label: {
            Text("Complete")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(fgColor)
    }
}
