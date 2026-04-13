import SwiftUI

struct HistoryView: View {
    
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////

    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray = GlobalSettings.shared.darkGray
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize = GlobalSettings.shared.setButtonSize
    let setsFontSize = GlobalSettings.shared.setsFontSize
    let setsSpacing = GlobalSettings.shared.setsSpacing
    
    var body: some View {
        
        let completedWorkout = completedWorkoutsViewModel.activePlan
        
        ScrollView {
            LazyVStack {
                
                VStack(spacing: 0) {
                    Text(completedWorkout.workout.name)
                        .foregroundColor(fgColor)
                        .fontWeight(.medium)
                        .font(.system(size: 35))
                    Spacer().frame(height:3)
                    Text(completedWorkoutsViewModel.formatDate(completedWorkout.dateCompleted))
                        .foregroundColor(darkGray)
                        .fontWeight(.bold)
                        .font(.system(size: 20))
                }
                .padding(.top, 20)
                
                // EXERCISE LIST
                ForEach(completedWorkout.workout.exercises.indices, id: \.self) { exerciseIndex in
                    
                    VStack {
                        
                        // EXERCISE NAME + LOG CHANGE BUTTON
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
                                    // SET BUTTON
                                    // marks set.completed to TRUE OR FALSE
                                    Button(action: { }) { // this button is just to show the checkmark or not and is, thus, disabled
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
                    .padding(17) //.padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
                    .background(bgColor)
                    .cornerRadius(16)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 8)

            }
        }
            .background(.black)
        
        

    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)

    }
}
