import SwiftUI

struct SelectPlanView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var viewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        List {
            ForEach(viewModel.workoutPlans) { workoutPlan in
                Text(workoutPlan.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(fgColor)
                    .padding(.vertical, 5)
            }
        }
        .navigationBarTitle(Text("Select Plan"))
    }
}

struct SelectPlanView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPlanView()
            .environmentObject(PlanViewModel(mockPlans: mockWorkouts))
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .preferredColorScheme(.dark)
    }
}
