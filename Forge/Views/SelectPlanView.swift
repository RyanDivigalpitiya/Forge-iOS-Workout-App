import SwiftUI

struct SelectPlanView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    
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
                            VStack {
                                HStack {
                                    Text(planViewModel.workoutPlans[index].name)
                                        .fontWeight(.bold)
                                        .font(.system(size: 30))
                                        .foregroundColor(fgColor)
                                    Spacer()
                                }
                                .padding(.top,5)
                                
                                
                                Divider()
                                
                                HStack {
                                    // NUMBER OF EXERCISES
                                    Text(String(planViewModel.workoutPlans[index].exercises.count) + " Exercises")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
                                    Text("·")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 1)
                                    // DURATION OF WORKOUT
                                    Text(String(planViewModel.calculateWorkoutDuration(for: planViewModel.workoutPlans[index])) + " min")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
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
                                            .frame(width: 20, height: 20)
                                            .foregroundColor(.gray)
                                            .opacity(0.4)
                                    }
                                    
                                }
                                .padding(.top,15)
                                
                            }
                            .padding(5)
                        }
                        .padding()
                        .background(bgColor)
                        .cornerRadius(15)
                        .fullScreenCover(isPresented: $workoutInProgressViewPresented) {
                            WorkoutInProgressView()
                                .environment(\.colorScheme, .dark)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
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
