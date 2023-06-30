import SwiftUI

struct CompletedWorkoutsView: View {
    
    //-//////////////////////////////////////////
    @EnvironmentObject var viewModel: CompletedWorkoutsViewModel
    //-//////////////////////////////////////////
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.completedWorkouts) { completedWorkout in
                    VStack(alignment: .leading) {
                        Text(viewModel.numberOfDaysString(from: completedWorkout.dateCompleted))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemGray3))
                        
                        Text(completedWorkout.workout.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(fgColor)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete(perform: viewModel.deleteCompletedWorkouts)
            }
            .navigationBarTitle(Text("History"))
            .navigationBarTitleTextColor(Color(.systemGray3))
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar){
                    NavigationLink(destination: SelectPlanView()){
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
