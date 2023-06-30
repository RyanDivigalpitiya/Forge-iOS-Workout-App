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
    // Sets data
    @State private var selectedSets = "3 sets"
    let setsRange = Array(1...999).reversed().map { "\($0) sets" }
    // Weight data
    @State private var selectedWeight = "5 lbs"
    let weightRange = stride(from: 995, through: -995, by: -5).map { "\($0) lbs" }
    // Reps data
    @State private var selectedReps = "12 reps"
    let repsRange = Array(1...999).reversed().map { "\($0) reps" }
    // Toggle for changing individual sets
    @State private var viewUniqueSets = false
    
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
    let buttonPlusMinusIconSize: CGFloat = 15
    let buttonPlusMinusWidth: CGFloat = 85
    let buttonPlusMinusHeight: CGFloat = 30
    let buttonPlusMinusSize: CGFloat = 5
    let darkGray: Color = Color(red: 0.33, green: 0.33, blue: 0.33)
    


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
            
            TextField("Enter Exercise Name Here", text: $exerciseName)
                .frame(width: 300)
                .focused($isNameFieldFocused)
                .autocapitalization(.words)
                .foregroundColor(.white)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .font(.system(size: 23))
                .padding(.vertical, 10)
            
            
            HStack {
                
                // SETS SELECTOR
                VStack {
                    VStack {
                        Picker(selection: $selectedSets, label: Text("Weight")) {
                           ForEach(setsRange, id: \.self) {
                               Text("\($0)")
                                   .foregroundColor(fgColor)
                           }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 100)
                        .frame(minHeight: 150)
                    }
                       
                    HStack() {
                        // DECREMENT BUTTON
                        Button(action: {
                            if var num = Int(selectedSets.dropLast(5)) {
                                if num > 1 {
                                    num -= 1
                                    selectedSets = "\(num) sets"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "minus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                        
                        Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)
                        
                        // INCREMENT BUTTON
                        Button(action: {
                            if var num = Int(selectedSets.dropLast(5)) {
                                if num < 999{
                                    num += 1
                                    selectedSets = "\(num) sets"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                    }
                    .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                    .background(fgColor)
                    .cornerRadius(5)
                }
                
                // "X"
                VStack {
                    Image(systemName: "xmark")
                        .foregroundColor(darkGray)
                        .bold()
                    Rectangle().frame(width: 1, height:buttonPlusMinusHeight).hidden()
                }
                
                // WEIGHT SELECTOR
                VStack {
                    Picker(selection: $selectedWeight, label: Text("Weight")) {
                       ForEach(weightRange, id: \.self) {
                           Text("\($0)")
                               .foregroundColor(fgColor)

                       }
                    }
                    .pickerStyle(WheelPickerStyle())
                    .frame(width: 100)
                       
                    HStack() {
                        // DECREMENT BUTTON
                        Button(action: {
                            if var num = Int(selectedWeight.dropLast(4)) {
                                if num > -956 {
                                    num -= 5
                                    selectedWeight = "\(num) lbs"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "minus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                        
                        Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)
                        
                        // INCREMENT BUTTON
                        Button(action: {
                            if var num = Int(selectedWeight.dropLast(4)) {
                                if num < 956{
                                    num += 5
                                    selectedWeight = "\(num) lbs"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                    }
                    .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                    .background(fgColor)
                    .cornerRadius(5)
                }
                
                // "X"
                
                VStack {
                    Image(systemName: "xmark")
                        .foregroundColor(darkGray)
                        .bold()
                    Rectangle().frame(width: 1, height:buttonPlusMinusHeight).hidden()
                }
                
                // REPS SELECTOR
                VStack {
                    Picker(selection: $selectedReps, label: Text("Reps")) {
                       ForEach(repsRange, id: \.self) {
                           Text("\($0)")
                               .foregroundColor(fgColor)
                       }
                    }
                   .pickerStyle(WheelPickerStyle())
                   .frame(width: 100)
                       
                    HStack() {
                        // DECREMENT BUTTON
                        Button(action: {
                            if var num = Int(selectedReps.dropLast(5)) {
                                if num > 1{
                                    num -= 1
                                    selectedReps = "\(num) reps"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "minus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                        
                        Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)
                        
                        Button(action: {
                            // INCREMENT BUTTON
                            if var num = Int(selectedReps.dropLast(5)) {
                                if num < 999 {
                                    num += 1
                                    selectedReps = "\(num) reps"
                                    feedbackGenerator.impactOccurred()
                                }
                            }
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.black)
                                .font(.system(size: buttonPlusMinusIconSize))
                                .bold()
                                .padding(buttonPlusMinusSize)
                        }
                    }
                    .frame(width: buttonPlusMinusWidth, height: buttonPlusMinusHeight)
                    .background(fgColor)
                    .cornerRadius(5)
                }
            }
            
            HStack {
                Toggle(isOn: $viewUniqueSets) {
                    Text("Change Specific Sets")
                        .foregroundColor(viewUniqueSets ? fgColor : darkGray)
                        .fontWeight(.bold)
                }
            }
            .frame(width: 235)
            .padding(.top, 20)
            
            // BOTTOM TOOLBAR
            HStack {
                Spacer()
                
                // CANCEL BUTTON
                Button(action: {
                    self.presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(fgColor)
                        .bold()
                }
                
                Spacer()
            
                // SAVE BUTTON
                Button(action: {
                    isNameFieldFocused = false

                    if exerciseViewModel.activeExercise.setsAreUnique {
                        
                    } else { // homogenous sets
                        if exerciseViewModel.activeExerciseMode == "AddMode" {
                            let inputtedSets = Int(selectedSets.dropLast(5))
                            let inputtedWeight = Float(selectedWeight.dropLast(4))
                            let inputtedReps = Int(selectedReps.dropLast(5))
                            
                            // create sets
                            var setList: [Set] = []
                            if let unwrappedSets = inputtedSets, let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps {
                                for _ in 0...unwrappedSets-1 {
                                    let newSet = Set(weight: unwrappedWeight, reps: unwrappedReps, tillFailure: false)
                                    setList.append(newSet)
                                }
                            }
                            
                            // create new exercise + append it to planViewModel's active plan
                            let newExercise = Exercise(name: exerciseName, sets: setList)
                            planViewModel.activePlan.exercises.append(newExercise)
                            
                        } else { // Edit Mode or Log Mode
                            
                        }
                    }
                    
                    
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
                
                // DELETE BUTTON
                Button(action: {
                    // perform delete function
                }) {
                    Text("Delete")
                        .foregroundColor(fgColor)
                        .bold()
                }
                
                Spacer()
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .background(Color(.systemGray6))
        .onAppear {
            // assign exercise data from view model to UI input controls
            exerciseName = exerciseViewModel.activeExercise.name
            
            if exerciseViewModel.activeExerciseMode == "AddMode" {
                selectedSets = "3 sets"
                selectedWeight = "5 lbs"
                selectedReps = "12 reps"
            } else { // edit mode or log mode
                if exerciseViewModel.activeExercise.setsAreUnique {

                } else { // homogenous sets
                    selectedSets    = "\(exerciseViewModel.activeExercise.sets.count) sets"
                    selectedWeight  = "\(exerciseViewModel.activeExercise.sets[0].weight) lbs"
                    selectedReps    = "\(exerciseViewModel.activeExercise.sets[0].reps) reps"
                }
            }
        
//            isNameFieldFocused = exerciseViewModel.activeExercise.name == ""
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
