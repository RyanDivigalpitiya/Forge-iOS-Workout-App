import SwiftUI
import Charts

/// Phase B: a single exercise's progress card in the Full History tab.
/// Displays Weight PR + Reps PR badges, a Weight↔Reps metric selector,
/// and a line chart plotting the selected metric over time across every
/// `CompletedWorkout` containing this exercise's UUID.
struct ExerciseProgressCard: View {
    let exercise: Exercise

    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var metric: ProgressMetric = .weight

    var body: some View {
        VStack(spacing: 14) {
            exerciseNameHeader
            prRow
            metricSelector
            chart
        }
        .padding(17)
        .background(settings.bgColor)
        .cornerRadius(settings.cornerRadiusLarge)
    }

    private var exerciseNameHeader: some View {
        HStack {
            Text(exercise.name)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .font(.system(size: 22))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
        }
    }

    private var prRow: some View {
        HStack(spacing: 12) {
            prBadge(
                label: "Weight PR",
                pair: completedWorkoutsViewModel.weightPR(forExerciseId: exercise.id),
                accentOn: .weight
            )
            prBadge(
                label: "Reps PR",
                pair: completedWorkoutsViewModel.repsPR(forExerciseId: exercise.id),
                accentOn: .reps
            )
        }
    }

    @ViewBuilder
    private func prBadge(
        label: String,
        pair: (weight: Float, reps: Int)?,
        accentOn: ProgressMetric
    ) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(settings.darkGray)
            if let pair {
                HStack(spacing: 0) {
                    Text(formatWeight(pair.weight))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accentOn == .weight ? settings.fgColor : .white)
                    Text(" lb × ")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(pair.reps)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(accentOn == .reps ? settings.fgColor : .white)
                    Text(" reps")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                Text("—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: settings.cornerRadiusMedium)
                .fill(Color.black.opacity(0.3))
        )
    }

    private var metricSelector: some View {
        Picker("", selection: $metric) {
            Text("Weight").tag(ProgressMetric.weight)
            Text("Reps").tag(ProgressMetric.reps)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var chart: some View {
        let series = completedWorkoutsViewModel.progressSeries(
            forExerciseId: exercise.id,
            metric: metric
        )
        if series.isEmpty {
            Text("No completed sets logged yet")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            Chart {
                ForEach(series.indices, id: \.self) { i in
                    AreaMark(
                        x: .value("Date", series[i].date),
                        y: .value(yAxisLabel, series[i].value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [settings.fgColor.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
                }
                ForEach(series.indices, id: \.self) { i in
                    LineMark(
                        x: .value("Date", series[i].date),
                        y: .value(yAxisLabel, series[i].value)
                    )
                    .foregroundStyle(settings.fgColor)
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                }
            }
            .frame(height: 140)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private var yAxisLabel: String {
        metric == .weight ? "Weight (lb)" : "Reps"
    }

    private func formatWeight(_ w: Float) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(w))"
            : String(format: "%.1f", w)
    }
}
