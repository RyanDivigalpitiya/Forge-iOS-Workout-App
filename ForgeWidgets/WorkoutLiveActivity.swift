import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {

    private let fgColor = Color(red: 255/255, green: 67/255, blue: 107/255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // LOCK SCREEN presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            // Dynamic Island — placeholder for Stage 4
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.center) {
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(fgColor)
            } compactTrailing: {
                Text("\(context.state.percentCompleted)%")
                    .foregroundColor(fgColor)
                    .fontWeight(.bold)
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
