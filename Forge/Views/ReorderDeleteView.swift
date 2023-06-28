import SwiftUI

struct ReorderDeleteView: View {
    
    // Workout Plan data /////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    // - /////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @State private var isEditing: EditMode = .inactive
    
    var mode: String = "PlanMode"
    let fgColor = GlobalSettings.shared.fgColor
    
    var body: some View {
        VStack {
            Text(mode == "PlanMode" ? "Edit Order of Plans" : "Edit Order of Exercises")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(fgColor)
                .padding(.top,25)
                .padding(.bottom,2)
            
            Text("Drag handlebar up or down to reorder")
                .fontWeight(.bold)
                .foregroundColor(Color(.systemGray2))
                .padding(.top,0)
            
            HStack {
                Text("Press")
                    .fontWeight(.bold)
                    .padding(.top,0)
                    
                Image(systemName: "minus.circle.fill")
                    .resizable()
                    .frame(width: 18, height: 18)
                
                Text("te delete")
                    .fontWeight(.bold)
                    .padding(.top,0)
            }
            .foregroundColor(Color(.systemGray2))
            
            if mode == "PlanMode"{
                List {
                    ForEach(planViewModel.workoutPlans.indices, id: \.self) { index in
                        Text(planViewModel.workoutPlans[index].name)
                            .foregroundColor(fgColor)
                            .fontWeight(.bold)
                    }
                    .onMove(perform: planViewModel.movePlan)
                    .onDelete(perform: planViewModel.deletePlan)
                }
                .environment(\.editMode, $isEditing)
            } else { // mode == "ExerciseMode
                List {
                    ForEach(planViewModel.activePlan.exercises.indices, id: \.self) { index in
                        Text(planViewModel.activePlan.exercises[index].name)
                            .foregroundColor(fgColor)
                            .fontWeight(.bold)
                    }
                    .onMove(perform: planViewModel.moveExercise)
                    .onDelete(perform: planViewModel.deleteExercise)
                }
                .environment(\.editMode, $isEditing)
            }
            
            Spacer()
            
            HStack {
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    HStack{
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Dismiss")
                            .font(.headline)
                    }
                    .foregroundColor(fgColor)
                }
                .padding(.top, 15)
            }
        }
        .background(Color(.systemGray6))
        .onAppear{self.isEditing = .active}
    }
}

struct ReorderDeleteView_Previews: PreviewProvider {
    static var previews: some View {
        ReorderDeleteView()
    }
}
