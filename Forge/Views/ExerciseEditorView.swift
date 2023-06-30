import SwiftUI

struct ExerciseEditorView: View {
    
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState private var isNameFieldFocused: Bool // used to assign focus on exercise name textfield on appear
    
    // Data being inputted / edited:
    @State var exerciseName: String = ""
    @State var exerciseWeight: Float = 5.0
    @State var exerciseReps: Int = 12
    @State var exerciseSets: Int = 3
    //
    @State var previousWeight: Float = 0
    @State var previousReps: Int = 0
    @State var previousSets: Int = 0
    
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
            
            TextField("Enter Name Here", text: $exerciseName)
                .frame(width: 300)
                .focused($isNameFieldFocused)
                .autocapitalization(.words)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .font(.system(size: 23))
                .padding(.vertical, 10)
            
            
            VStack {
                // WEIGHT FIELD
                Stepper(value: $exerciseWeight, in: -999...999, step: 5) {
                    HStack {
                        Text("\(Int(exerciseWeight))").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("lbs").fontWeight(.bold).foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(weightScaleEffect)
                }
                .padding()
                .onChange(of: exerciseWeight) { newValue in
                    if newValue > previousWeight {
                        incrementWeightAnimation()
                    } else if newValue < previousWeight {
                        decrementWeightAnimation()
                    }
                    previousWeight = newValue
                }
                
                // REPS FIELD
                Stepper(value: $exerciseReps, in: 1...999) {
                    HStack {
                        Text("\(exerciseReps)").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("reps").fontWeight(.bold) .foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(repsScaleEffect)
                }
                .padding()
                .onChange(of: exerciseReps) { newValue in
                    if newValue > previousReps {
                        incrementRepsAnimation()
                    } else if newValue < previousReps {
                        decrementRepsAnimation()
                    }
                }
                
                // SETS FIELD
                Stepper(value: $exerciseSets, in: 1...999) {
                    HStack {
                        Text("\(exerciseSets)").fontWeight(.bold).foregroundColor(.white).font(.system(size: fontSize))
                        Text("sets").fontWeight(.bold) .foregroundColor(fgColor).font(.system(size: fontSize))
                    }
                    .scaleEffect(setsScaleEffect)
                }
                .padding()
                .onChange(of: exerciseSets) { newValue in
                    if newValue > previousSets {
                        incrementSetsAnimation()
                    } else if newValue < previousSets {
                        decrementSetsAnimation()
                    }
                }
            }
            .frame(width: 260)
            

            
            HStack {
                
                Spacer()
            
                // SAVE BUTTON
                Button(action: {
                    isNameFieldFocused = false
                    // assign @State input values to activeExericse's properties
//                    exerciseViewModel.activeExercise.name   = exerciseName
//                    exerciseViewModel.activeExercise.weight = exerciseWeight
//                    exerciseViewModel.activeExercise.reps   = exerciseReps
//                    exerciseViewModel.activeExercise.sets   = exerciseSets
//                    //add exercise to active plan's exercises
//                    if exerciseViewModel.activeExerciseMode == "AddMode" {
//
//                        // Add new exericse to active plan being operated on:
//                        planViewModel.activePlan.exercises.append(exerciseViewModel.activeExercise)
//                        //-///////////////////////////////////////////////////
//
//                    } else if exerciseViewModel.activeExerciseMode == "EditMode"  {
//
//                        // Edit exercise and update active plan
//                        planViewModel.activePlan.exercises[exerciseViewModel.activeExerciseIndex] = exerciseViewModel.activeExercise
//
//                    } else { // LogMode
//
//                    }
                    
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
            // assign exercise data from view model to UI input controls
//            exerciseName = exerciseViewModel.activeExercise.name
//            exerciseWeight = exerciseViewModel.activeExercise.weight
//            exerciseReps = exerciseViewModel.activeExercise.reps
//            exerciseSets = exerciseViewModel.activeExercise.sets
//            // assign "previous" values used by stepper to compare adjusted values to previous values
//            previousWeight = exerciseViewModel.activeExercise.weight
//            previousReps = exerciseViewModel.activeExercise.reps
//            previousSets = exerciseViewModel.activeExercise.sets
//            // assign focus to exercise name field if no name exists
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
            .environmentObject(CompletedWorkoutsViewModel())
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
