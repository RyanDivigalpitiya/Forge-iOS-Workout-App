import SwiftUI

struct CompletedWorkoutsView: View {
    
    //-//////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-//////////////////////////////////////////
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        NavigationView {
            List {
                ForEach(completedWorkoutsViewModel.completedWorkouts.indices.reversed(), id: \.self) { completedWorkoutIndex in
                    let completedWorkout = completedWorkoutsViewModel.completedWorkouts[completedWorkoutIndex]
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(completedWorkoutsViewModel.numberOfDaysString(from: completedWorkout.dateCompleted))
//                            Text("·")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 2)
                        
                        
                        Text(completedWorkout.workout.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(fgColor)
                            .padding(.top, 3)
                            .padding(.bottom, 7)
                        
                        HStack {
                            Text("Duration: \(completedWorkoutsViewModel.format(timeInterval: completedWorkout.elapsedTime))")
                            Text("·")
                            Text("Completion: \(completedWorkout.completion)")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.systemGray2))
                        .padding(.bottom, 2)
                    }
                    .padding(.vertical, 15)
                }
                .onDelete(perform: completedWorkoutsViewModel.deleteCompletedWorkouts)
            }
            .navigationBarTitle(Text("History"))
            .navigationBarTitleTextColor(Color(.systemGray2))
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar){
                    NavigationLink(destination: SelectPlanView(), isActive: $completedWorkoutsViewModel.isSelectPlanViewActive) {
                        HStack {
                            Image(systemName: "figure.run")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.trailing, 3)
                            Text("Start Workout")
                        }
                    }
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(fgColor)
                }
            }
        }
        .accentColor(fgColor)
        .onAppear{
            completedWorkoutsViewModel.isSelectPlanViewActive = false
        }
    }
}

extension View {
    // Sets the text colour for a navigation bar title
    // Parameter color: Color the title should be set to
    // Supports both regular and large titles
    @available(iOS 14, *) // only possible on iOS14+
    func navigationBarTitleTextColor(_ color: Color) -> some View {
        let uiColor = UIColor(color)
        // Set appearance for both normal and large sizes.
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: uiColor ]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: uiColor ]
        return self
    }
}


struct CompletedWorkoutsView_Previews: PreviewProvider {
    static var previews: some View {
        CompletedWorkoutsView()
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .preferredColorScheme(.dark)
    }
}
