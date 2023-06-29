import SwiftUI

struct SelectPlanView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var viewModel: PlanViewModel
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
                    ForEach(viewModel.workoutPlans.indices, id: \.self) { index in
                        
                        Button(action: {
                            // set active Plan to workoutPlans[index] + bring up WorkoutInProgressView
                            viewModel.activePlan = viewModel.workoutPlans[index]
                            viewModel.activePlanIndex = index
                            workoutInProgressViewPresented = true
                        }) {
                            VStack {
                                HStack {
                                    Text(viewModel.workoutPlans[index].name)
                                        .fontWeight(.bold)
                                        .font(.system(size: 40))
                                        .foregroundColor(fgColor)
                                    Spacer()
                                    Image("Arrow-Right")
                                        .resizable()
                                        .frame(width: 33, height: 33)
                                        .opacity(0.2)
                                        .padding(.trailing, 9)
                                }
                                .padding(.top,5)
                                
                                
                                Divider()
                                
                                HStack {
                                    // NUMBER OF EXERCISES
                                    Text(String(viewModel.workoutPlans[index].exercises.count) + " Exercises")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
                                    Text("·")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 1)
                                    // DURATION OF WORKOUT
                                    Text(String(viewModel.calculateWorkoutDuration(for: viewModel.workoutPlans[index])) + " min")
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .fontWeight(.bold)
                                    Spacer()
                                    
                                    // EDIT BUTTON //////////////////
                                    Button( action: {
                                        viewModel.activePlan = viewModel.workoutPlans[index]
                                        viewModel.activePlanMode = "EditMode"
                                        viewModel.activePlanIndex = index
                                        self.planEditorIsPresented = true
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .resizable()
                                            .frame(width: 20, height: 20)
                                            .padding(.trailing, 15)
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
                .padding(.bottom, 100)
            }
            
            VStack {
                Spacer()
                
                // Bottom toolbar
                HStack {
                    Spacer()
                    
                    // NEW BUTTON
                    Button(action: {
                        // set activePlan to a new plan
                        viewModel.activePlan = WorkoutPlan()
                        viewModel.activePlanMode = "AddMode"
                        self.planEditorIsPresented = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 15, height: 15)
                                .padding(.trailing, 3)
                            Text("New")
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
                                .frame(width: 15, height: 15)
                                .padding(.trailing, 3)
                            Text("Edit")
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
            .environmentObject(PlanViewModel(mockPlans: mockWorkouts))
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .preferredColorScheme(.dark)
    }
}
