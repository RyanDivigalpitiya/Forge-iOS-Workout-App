import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {

    private let fgColor = Color(red: 255/255, green: 67/255, blue: 107/255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.planName)
                        .font(.headline)
                        .foregroundColor(fgColor)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.percentCompleted)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.isResting, let endDate = context.state.restEndDate {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .foregroundColor(fgColor)
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .monospacedDigit()
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let exerciseName = context.state.nextExerciseName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Up next: \(exerciseName)")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .lineLimit(1)
                            if let setDesc = context.state.nextSetDescription {
                                Text(setDesc)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                if context.state.isResting {
                    Image(systemName: "timer")
                        .foregroundColor(fgColor)
                } else {
                    Image(systemName: "dumbbell.fill")
                        .foregroundColor(fgColor)
                }
            } compactTrailing: {
                if context.state.isResting, let endDate = context.state.restEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                        .frame(width: 36)
                        .minimumScaleFactor(0.6)
                } else {
                    Text("\(context.state.percentCompleted)%")
                        .foregroundColor(fgColor)
                        .fontWeight(.bold)
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(fgColor)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.planName)
                    .font(.headline)
                    .foregroundColor(fgColor)

                Text("\(context.state.percentCompleted)% Complete")
                    .font(.subheadline)
                    .foregroundColor(.white)

                if context.state.isResting, let endDate = context.state.restEndDate {
                    HStack(spacing: 6) {
                        Text("Rest")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(fgColor)
                            .monospacedDigit()
                    }
                }

                if let exerciseName = context.state.nextExerciseName {
                    Text("Up next: \(exerciseName)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    if let setDesc = context.state.nextSetDescription {
                        Text(setDesc)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundColor(fgColor)
        }
        .padding()
        .activityBackgroundTint(Color(red: 22/255, green: 22/255, blue: 22/255))
    }
}
