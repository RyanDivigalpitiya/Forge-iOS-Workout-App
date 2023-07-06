import SwiftUI

struct SelectPlanView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////
    
    
    @State private var planEditorIsPresented = false
    @State private var reorderDeleteViewPresented = false
    @State private var workoutInProgressViewPresented = false
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack {
                    ForEach(planViewModel.workoutPlans.indices, id: \.self) { index in
                        
                        Button(action: {
                            // set active Plan to workoutPlans[index] + bring up WorkoutInProgressView
                            planViewModel.activePlan = planViewModel.workoutPlans[index]
                            planViewModel.activePlanIndex = index
                            workoutInProgressViewPresented = true
                        }) {
                            HStack(spacing:0){
                                
                                VStack {
                                    VStack {
                                        HStack {
                                            Text(planViewModel.workoutPlans[index].name)
                                                .fontWeight(.bold)
                                                .font(.system(size: 30))
                                                .foregroundColor(fgColor)
                                            Spacer()
                                            HStack {
                                                Text("START")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.black)
                                                    .fontWeight(.bold)
                                            }
                                            .padding(8)
                                            .padding(.horizontal,1)
                                            .background(fgColor)
                                            .cornerRadius(5)

                                        }
                                        .padding(.top,5)
                                        
                                        if let lastComleted = planViewModel.workoutPlans[index].lastCompleted {
                                            HStack {
                                                Text("Last Completed: ")
                                                    .foregroundColor(Color.gray.opacity(0.5))
                                                    .fontWeight(.bold)
                                                Text(completedWorkoutsViewModel.numberOfDaysString(from: lastComleted))
                                                    .foregroundColor(.white)
                                                    .fontWeight(.bold)
                                                Spacer()
                                            }
                                            .padding(.top, 1)
                                            .padding(.bottom, 13)
                                        }
                                    }
                                    
                                    
                                    Divider()
                                    
                                    HStack {
                                        // NUMBER OF EXERCISES
                                        Image(systemName: "dumbbell.fill")
                                            .resizable()
                                            .frame(width: 18, height: 13)
                                            .foregroundColor(.gray)
                                            .opacity(0.4)
                                            .padding(.vertical, 15)
                                        Text(String(planViewModel.workoutPlans[index].exercises.count) + " Exercises")
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .fontWeight(.bold)
                                        // DURATION OF WORKOUT
                                        Image(systemName: "clock.fill")
                                            .resizable()
                                            .frame(width: 13, height: 13)
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .padding(.leading, 10)
                                        Text(String(planViewModel.calculateWorkoutDuration(for: planViewModel.workoutPlans[index])) + " min")
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .fontWeight(.bold)
                                            .padding(.leading, -3)
                                        Spacer()
                                        // EDIT BUTTON //////////////////
                                        Button( action: {
                                            planViewModel.activePlan = planViewModel.workoutPlans[index]
                                            planViewModel.activePlanMode = "EditMode"
                                            planViewModel.activePlanIndex = index
                                            self.planEditorIsPresented = true
                                        }) {
                                            Image(systemName: "pencil.circle.fill")
                                                .resizable()
                                                .frame(width: 15, height: 15)
                                                .foregroundColor(Color.gray.opacity(0.5))
                                                .padding(.trailing, 2)
                                                .padding(.vertical, 15)
                                        }

                                    }
                                }
                                .padding(.leading, 5)
                                .padding(.trailing, 20)
                                .padding(.top, 5)
                                .padding(.bottom, -9)
                            }
                        }
                        .padding(.vertical)
                        .padding(.leading)
                        .background(bgColor)
                        .cornerRadius(15)
                        .contextMenu {
                            VStack {
                                ForEach(planViewModel.workoutPlans[index].exercises) { exercise in
                                    Text(exercise.name)
                                }
                                Divider()
                                Button( action: {
                                    planViewModel.activePlan = planViewModel.workoutPlans[index]
                                    planViewModel.activePlanIndex = index
                                    workoutInProgressViewPresented = true
                                }) {
                                    Text("Start")
                                    Image(systemName: "play.circle")
                                }
                            }
                        }

                        .fullScreenCover(isPresented: $workoutInProgressViewPresented) {
                            WorkoutInProgressView()
                                .environment(\.colorScheme, .dark)
                        }
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                }
                .padding(.bottom, 120)
            }
            
            VStack {
                Spacer()
                
                // Bottom toolbar
                HStack {
                    Spacer()
                    
                    // NEW BUTTON
                    Button(action: {
                        // set activePlan to a new plan
                        planViewModel.activePlan = WorkoutPlan()
                        planViewModel.activePlanMode = "AddMode"
                        self.planEditorIsPresented = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .padding(.trailing, 3)
                            Text("New")
                                .font(.system(size: 20))
                        }
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    }
                    .fullScreenCover(isPresented: $planEditorIsPresented) {
                        PlanEditorView()
                            .environment(\.colorScheme, .dark)
                    }
                    
                    Spacer()
                    
                    // REORDER BUTTON
                    Button(action: {
                        // pulls up reOrderDeleteView
                        self.reorderDeleteViewPresented = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .padding(.trailing, 3)
                            Text("Order")
                                .font(.system(size: 20))
                        }
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    }
                    .sheet(isPresented: $reorderDeleteViewPresented) {
                        ReorderDeleteView(mode: "PlanMode")
                            .presentationDetents([.medium, .large])
                            .environment(\.colorScheme, .dark)
                    }
                    
                    
                    Spacer()
                }
                .frame(height: bottomToolbarHeight)
                .padding(.bottom, 10)
                .background(BlurView(style: .systemChromeMaterial))
            }
        }
        .navigationBarTitle(Text("Select Plan"))
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct SelectPlanView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPlanView()
            .environmentObject(ExerciseViewModel())
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .preferredColorScheme(.dark)
    }
}
