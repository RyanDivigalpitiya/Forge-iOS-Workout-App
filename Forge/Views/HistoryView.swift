import SwiftUI

struct HistoryView: View {
    
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let darkGray: Color = Color(red: 0.25, green: 0.25, blue: 0.25)
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setButtonSize: CGFloat = 28
    let setsFontSize: CGFloat = 20 // Font size used for text in set rows
    let setsSpacing: CGFloat = 3
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height
    
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
                                                Image("Checkmark")
                                                    .resizable()
                                                    .frame(width: 13, height: 11)
                                                    .padding(.top,1)
                                                    .padding(.trailing, 16)
                                                Circle()
                                                    .stroke(lineWidth: 2)
                                                    .frame(width: setButtonSize, height: setButtonSize)
                                                    .foregroundColor(fgColor)
                                                    .padding(.trailing, 16)
                                            }
                                            .opacity(0.5)
                                        } else {
                                            Circle()
                                                .stroke(lineWidth: 2)
                                                .frame(width: setButtonSize, height: setButtonSize)
                                                .foregroundColor(fgColor)
                                                .padding(.trailing, 16)
                                        }
                                
                                    }
                                    .padding(.trailing, 3)
                                    .disabled(true)

                                    
                                    ZStack {
                                       let set = completedWorkout.workout.exercises[exerciseIndex].sets[setIndex]
                                        
                                        HStack {
                                            if setIndex+1 > 9 {
                                                Text("Set \(setIndex+1)")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .frame(width: 67, height: 28)
                                                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                                                    .cornerRadius(5)
                                                    .padding(.trailing, setsSpacing+2)
                                            } else {
                                                Text("Set \(setIndex+1)")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .frame(width: 58, height: 28)
                                                    .background(Color(red: 0.2, green: 0.2, blue: 0.2))
                                                    .cornerRadius(5)
                                                    .padding(.trailing, setsSpacing+2)

                                            }
                                            Text("\(Int(set.weight)) lb")
                                                .foregroundColor(.white)
                                                .padding(.trailing, setsSpacing)
                                            Image(systemName: "xmark")
                                                .resizable()
                                                .frame(width: 10, height: 10)
                                                .padding(.top,3)
                                                .foregroundColor(.gray)
                                                .opacity(0.6)
                                                .padding(.trailing, setsSpacing)
                                                
                                            if set.tillFailure {
                                                Text("Until Failure").foregroundColor(.gray).opacity(0.6)
                                            } else {
                                                Text("\(set.reps) reps").foregroundColor(.gray).opacity(0.6)
                                            }
                                            Spacer()
                                        }
                                        .fontWeight(.bold)
                                        .font(.system(size: setsFontSize))
                                    }
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
