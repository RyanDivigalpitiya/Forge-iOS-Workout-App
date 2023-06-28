import SwiftUI

struct ExerciseEditorView: View {
    
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState private var isNameFieldFocused: Bool // used to assign focus on exercise name textfield on appear
    
    // Textfield animation parameters when +/- buttons are pressed
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var weightScaleEffect: CGFloat = 1.0
    @State private var repsScaleEffect: CGFloat = 1.0
    @State private var setsScaleEffect: CGFloat = 1.0
    private var incrementedScaleSize: CGFloat = 1.2
    private var decrementedScaleSize: CGFloat = 0.9
    let textFieldAnimationSpeed: Double = 0.05
    let textFieldAnimationDelay: Double = 0.05
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let fontSize: CGFloat = 25
    

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
//                .focused($isNameFieldFocused)
                .autocapitalization(.words)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .font(.system(size: 23))
                .padding(.vertical, 10)
            
            
            VStack {
                // WEIGHT FIELD
                Stepper(value: $exerciseViewModel.activeExercise.weight, in: -999...999, step: 5) {
                    HStack {
                        Text("\(Int(exerciseViewModel.activeExercise.weight))").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("lbs").fontWeight(.bold).foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(weightScaleEffect)
                }
                .padding()
                .onChange(of: exerciseViewModel.activeExercise.weight) { newValue in
                    if newValue > exerciseViewModel.previousWeightValue {
                        incrementWeightAnimation()
                    } else if newValue < exerciseViewModel.previousWeightValue {
                        decrementWeightAnimation()
                    }
                    exerciseViewModel.previousWeightValue = newValue
                }
                
                // REPS FIELD
                Stepper(value: $exerciseViewModel.activeExercise.reps, in: 1...999) {
                    HStack {
                        Text("\(exerciseViewModel.activeExercise.reps)").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("reps").fontWeight(.bold) .foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(repsScaleEffect)
                }
                .padding()
                .onChange(of: exerciseViewModel.activeExercise.reps) { newValue in
                    if newValue > exerciseViewModel.previousRepsValue {
                        incrementRepsAnimation()
                    } else if newValue < exerciseViewModel.previousRepsValue {
                        decrementRepsAnimation()
                    }
                    exerciseViewModel.previousRepsValue = newValue
                }
                
                // SETS FIELD
                Stepper(value: $exerciseViewModel.activeExercise.sets, in: 1...999) {
                    HStack {
                        Text("\(exerciseViewModel.activeExercise.sets)").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("sets").fontWeight(.bold) .foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(setsScaleEffect)
                }
                .padding()
                .onChange(of: exerciseViewModel.activeExercise.sets) { newValue in
                    if newValue > exerciseViewModel.previousSetsValue {
                        incrementSetsAnimation()
                    } else if newValue < exerciseViewModel.previousSetsValue {
                        decrementSetsAnimation()
                    }
                    exerciseViewModel.previousSetsValue = newValue
                }
            }
            .frame(width: 260)
            

            
            HStack {
                
                Spacer()
            
                // SAVE BUTTON
                Button(action: {
                    isNameFieldFocused = false
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
        .onAppear {
            isNameFieldFocused = exerciseViewModel.activeExercise.name == ""
        }
    }
}

// ANIMATION FUNCTIONS
extension ExerciseEditorView {

    private func incrementWeightAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            weightScaleEffect = incrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            weightScaleEffect = 1.0
        }
    }
    
    private func decrementWeightAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            weightScaleEffect = decrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            weightScaleEffect = 1.0
        }
    }
    
    private func incrementRepsAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            repsScaleEffect = incrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            repsScaleEffect = 1.0
        }
    }
    
    private func decrementRepsAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            repsScaleEffect = decrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            repsScaleEffect = 1.0
        }
    }
    
    private func incrementSetsAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            setsScaleEffect = incrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            setsScaleEffect = 1.0
        }
    }
    
    private func decrementSetsAnimation() {
        feedbackGenerator.impactOccurred()
        withAnimation(.easeInOut(duration: textFieldAnimationSpeed)) {
            setsScaleEffect = decrementedScaleSize
        }
        
        withAnimation(Animation.easeInOut(duration: textFieldAnimationSpeed).delay(textFieldAnimationDelay)) {
            setsScaleEffect = 1.0
        }
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
