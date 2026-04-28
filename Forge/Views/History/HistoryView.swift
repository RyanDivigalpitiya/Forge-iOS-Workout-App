import SwiftUI

struct HistoryView: View {


    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////

    @EnvironmentObject var settings: GlobalSettings
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray = GlobalSettings.shared.darkGray
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize = GlobalSettings.shared.setButtonSize
    let setsFontSize = GlobalSettings.shared.setsFontSize
    let setsSpacing = GlobalSettings.shared.setsSpacing

    @Environment(\.dismiss) private var dismiss

    private enum HistoryTab: String, CaseIterable, Identifiable {
        case mostRecent = "Most Recent"
        case fullHistory = "Full History"
        var id: Self { self }
    }

    @State private var selectedTab: HistoryTab = .mostRecent

    var body: some View {

        let completedWorkout = completedWorkoutsViewModel.activePlan

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    header(for: completedWorkout)
                    statsRow(for: completedWorkout)
                    tabPicker
                        .padding(.horizontal, 30)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    Group {
                        switch selectedTab {
                        case .mostRecent:
                            mostRecentTab(for: completedWorkout)
                        case .fullHistory:
                            FullHistoryTab(workout: completedWorkout)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.down")
                                .resizable()
                                .frame(width: 15, height: 9)
                                .padding(.trailing, 3)
                            Text("Dismiss")
                        }
                    }
                    .padding(5)
                    .padding(.horizontal, 10)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(settings.fgColor)
                }
            }
        }
        .background(.black)

    }

    @ViewBuilder
    private func header(for completedWorkout: CompletedWorkout) -> some View {
        VStack(spacing: 0) {
            Text(completedWorkout.workout.name)
                .foregroundColor(settings.fgColor)
                .fontWeight(.medium)
                .font(.system(size: 35))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer().frame(height:3)
            Text(completedWorkoutsViewModel.formatDate(completedWorkout.dateCompleted))
                .foregroundColor(darkGray)
                .fontWeight(.bold)
                .font(.system(size: 20))
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private func statsRow(for completedWorkout: CompletedWorkout) -> some View {
        HStack {
            // Calories
            VStack(spacing: 2) {
                if let calories = completedWorkout.caloriesBurned {
                    Text("\(Int(calories))")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("cal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(darkGray)
                } else {
                    Text("—")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("cal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(darkGray)
                }
            }
            .frame(maxWidth: .infinity)

            // Completion ring
            let percent = Int(completedWorkout.completion.replacingOccurrences(of: "%", with: "")) ?? 0
            ZStack {
                Circle()
                    .stroke(darkGray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(percent) / 100)
                    .stroke(settings.fgColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(percent)%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("Finished")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(darkGray)
                }
            }
            .frame(width: 72, height: 72)

            // Duration
            VStack(spacing: 2) {
                Text("\(Int(completedWorkout.elapsedTime / 60))")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Text("min")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(darkGray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 30)
        .padding(.top, 15)
        .padding(.bottom, 10)
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(HistoryTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func mostRecentTab(for completedWorkout: CompletedWorkout) -> some View {
        VStack(spacing: 0) {
            // EXERCISE LIST
            ForEach(completedWorkout.workout.exercises.indices, id: \.self) { exerciseIndex in

                VStack {

                    // EXERCISE NAME
                    HStack {
                        Text(completedWorkout.workout.exercises[exerciseIndex].name)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .font(.system(size: 30))
                        Spacer()
                    }

                    // EXERCISE SETS
                    VStack(spacing: 0){
                        ForEach(completedWorkout.workout.exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in
                            HStack(spacing: 0) {
                                // SET BUTTON — disabled, shows checkmark when set was completed
                                Button(action: { }) {
                                    if completedWorkout.workout.exercises[exerciseIndex].sets[setIndex].completed {
                                        ZStack {
                                            Image(systemName: "checkmark")
                                                .resizable()
                                                .frame(width: 11, height: 9)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .padding(.trailing, 16)
                                            Circle()
                                                .stroke(lineWidth: 2)
                                                .frame(width: setButtonSize, height: setButtonSize)
                                                .foregroundColor(.white)
                                                .padding(.trailing, 16)
                                        }
                                        .opacity(0.4)
                                    } else {
                                        Circle()
                                            .stroke(lineWidth: 2)
                                            .frame(width: setButtonSize, height: setButtonSize)
                                            .foregroundColor(.white)
                                            .padding(.trailing, 16)
                                    }

                                }
                                .padding(.trailing, 3)
                                .disabled(true)


                                SetView(
                                    content: .individual(
                                        set: completedWorkout.workout.exercises[exerciseIndex].sets[setIndex],
                                        index: setIndex
                                    ),
                                    appearance: .muted
                                )
                            }
                            if setIndex < completedWorkout.workout.exercises[exerciseIndex].sets.count - 1 {
                                Spacer().frame(height: 25)
                            }

                        }
                    }

                }
                .padding(17)
                .background(bgColor)
                .cornerRadius(settings.cornerRadiusLarge)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let completedWorkoutsVM = CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts)
        completedWorkoutsVM.activePlan = completedWorkout2
        return HistoryView()
            .environmentObject(completedWorkoutsVM)
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
