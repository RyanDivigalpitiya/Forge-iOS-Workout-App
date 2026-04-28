import SwiftUI

/// Phase B: per-exercise progress visualization for the currently-viewed
/// `CompletedWorkout`. Sibling tab to the existing "Most Recent" view in
/// `HistoryView`. Each exercise from this workout's plan gets its own
/// progress card with PR badges, metric selector, and line chart.
struct FullHistoryTab: View {
    let workout: CompletedWorkout

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(workout.workout.exercises) { exercise in
                ExerciseProgressCard(exercise: exercise)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
    }
}
