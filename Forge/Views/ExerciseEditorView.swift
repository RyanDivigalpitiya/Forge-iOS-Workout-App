import SwiftUI

struct ExerciseEditorView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-/////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    

    var body: some View {
        VStack {
            Spacer()
            
            if exerciseViewModel.activeExerciseMode == "AddMode" {
                Text("Add Exercise")
                    .font(.title)
                    .foregroundColor(fgColor)
                    .fontWeight(.bold)
                    .padding(.top,15)
            } else if exerciseViewModel.activeExerciseMode == "EditMode" {
                Text("Edit Exercise")
                    .font(.title)
                    .foregroundColor(fgColor)
                    .fontWeight(.bold)
                    .padding(.top,15)
            } else {
                Text("Log Change")
                    .font(.title)
                    .foregroundColor(fgColor)
                    .fontWeight(.bold)
                    .padding(.top,15)
            }
            
            TextField("Enter Name Here", text: $exerciseViewModel.activeExercise.name)
                .frame(width: 300)
                .autocapitalization(.words)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .font(.system(size: 23))
            
            
            VStack {
                // WEIGHT FIELD
                Stepper(value: $exerciseViewModel.activeExercise.weight, in: -999...999, step: 5) {
                    HStack {
                        Text("\(Int(exerciseViewModel.activeExercise.weight))").fontWeight(.bold).foregroundColor(.white)
                        Text("lbs").fontWeight(.bold) .foregroundColor(fgColor)
                    }
                }
                .padding()
                
                // REPS FIELD
                Stepper(value: $exerciseViewModel.activeExercise.reps, in: 1...999) {
                    HStack {
                        Text("\(exerciseViewModel.activeExercise.reps)").fontWeight(.bold).foregroundColor(.white)
                        Text("reps").fontWeight(.bold) .foregroundColor(fgColor)
                    }
                }
                .padding()
                
                // SETS FIELD
                Stepper(value: $exerciseViewModel.activeExercise.sets, in: 1...999) {
                    HStack {
                        Text("\(exerciseViewModel.activeExercise.sets)").fontWeight(.bold).foregroundColor(.white)
                        Text("sets").fontWeight(.bold) .foregroundColor(fgColor)
                    }
                }
                .padding()
            }
            .frame(width: 240)
            

            
            HStack {
                
                Spacer()
            
                
                
                // SAVE BUTTON
                Button(action: {
                    if exerciseViewModel.activeExerciseMode == "AddMode" {

                        // Add new exericse to active plan being operated on:
                        planViewModel.activePlan.exercises.append(exerciseViewModel.activeExercise)
                        //-///////////////////////////////////////////////////
                        
                    } else if exerciseViewModel.activeExerciseMode == "EditMode"  {
                        
                        // Edit exercise and update active plan
                        planViewModel.activePlan.exercises[exerciseViewModel.activeExerciseIndex] = exerciseViewModel.activeExercise
                        
                    } else { // LogMode
                        
                    }
                    
                    self.presentationMode.wrappedValue.dismiss()
                    
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                        Text("Save")
                            .fontWeight(.bold)
                    }
                    .padding(EdgeInsets(top: 6, leading: 13, bottom: 6, trailing: 14))
                    .foregroundColor(fgColor)
                    .background(Color(.systemGray5))
                    .cornerRadius(100)
                }
                
                Spacer()
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color(.systemGray6))
    }
}

struct ExerciseEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseEditorView()
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
