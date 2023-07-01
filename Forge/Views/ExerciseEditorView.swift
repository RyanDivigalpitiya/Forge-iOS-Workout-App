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
    // Homogenous Sets: ////////////////////////////////////////////////////////////
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
    // Heterogenous Sets: ////////////////////////////////////////////////////////////
    @State private var heteroSets_Weights: [String] = ["5 lbs", "5 lbs", "5 lbs"]
    @State private var heteroSets_Reps: [String] = ["12 reps", "12 reps", "12 reps"]
    @State private var heteroSets_Failure: [Bool] = [false, false, false]
    
    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var homogenousSelectorHeight: CGFloat = 200
    @State private var heterogenousSelectorHeight: CGFloat = 0
    @State private var homogenousSelectorOpacity: Double = 1.0
    @State private var heterogenousSelectorOpacity: Double = 0
    
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
            ScrollView {
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
            
            // HOMOGENOUS SET SELECTORS
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
                    .frame(minHeight: 150)
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
                   .frame(minHeight: 150)
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
            .frame(maxHeight: homogenousSelectorHeight)
            .clipped()
            .opacity(homogenousSelectorOpacity)
            
            // TOGGLE
            HStack {
                Toggle(isOn: $viewUniqueSets) {
                    Text("Change Specific Sets")
                        .foregroundColor(viewUniqueSets ? fgColor : darkGray)
                        .fontWeight(.bold)
                }
                .onChange(of: viewUniqueSets) { newValue in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        homogenousSelectorHeight = newValue ? 0 : 200
                        homogenousSelectorOpacity = newValue ? 0 : 1
                        heterogenousSelectorHeight = newValue ? 175 : 0
                        heterogenousSelectorOpacity = newValue ? 1 : 0
                    }
                }
            }
            
            .frame(width: 235)
            .padding(.top, 20)
            
            // HETEROGENOUS SET ROWS + SELECTORS
            VStack {
                if !exerciseViewModel.activeExercise.sets.isEmpty {
                    ForEach(heteroSets_Weights.indices, id: \.self) { setIndex in
                        
                        // SET ROW
                        HStack() {
                            
                            HStack {
                                // SET LABEL
                                Text("Set \(setIndex+1)")
                                    .foregroundColor(fgColor)
                                    .fontWeight(.bold)
                                    .font(.system(size: 15))
                                    .frame(width: 45)
                                
                                // WEIGHT SELECTOR
                                VStack {
                                    Picker(selection: $heteroSets_Weights[setIndex], label: Text("Weight")) {
                                        ForEach(weightRange, id: \.self) {
                                            Text("\($0)")
                                                .foregroundColor(fgColor)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(minHeight: 150)
                                    .frame(width: 100)
                                }
                                
                                // "X"
                                VStack {
                                    Image(systemName: "xmark")
                                        .foregroundColor(darkGray)
                                        .bold()
                                }
                                
                                // REPS SELECTOR
                                VStack {
                                    Picker(selection: $heteroSets_Reps[setIndex], label: Text("Reps")) {
                                        ForEach(repsRange, id: \.self) {
                                            Text("\($0)")
                                                .foregroundColor(fgColor)
                                        }
                                    }
                                    .pickerStyle(WheelPickerStyle())
                                    .frame(minHeight: 150)
                                    .frame(width: 100)
                                }
                                
                                // till Failure + Delete Button
                                VStack(spacing: 15) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(darkGray)
                                    Spacer().frame(height: 8)
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(darkGray)
                                }
                                .frame(width: 45)
                            }
                            .padding(15)
                        }
                        .frame(maxHeight: heterogenousSelectorHeight)
                        .clipped()
                        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .opacity(heterogenousSelectorOpacity)
                        .cornerRadius(20)
                        .padding(.top, 10)
                        
                        
                    }
                }
                
            }
            
            
            // BOTTOM TOOLBAR
            HStack {
//                Spacer()
//
//                // CANCEL BUTTON
//                Button(action: {
//                    self.presentationMode.wrappedValue.dismiss()
//                }) {
//                    Text("Cancel")
//                        .foregroundColor(fgColor)
//                        .bold()
//                }
                
                Spacer()
            
                // SAVE BUTTON
                Button(action: {
                    isNameFieldFocused = false

                    if exerciseViewModel.activeExerciseMode == "AddMode" {
                        if viewUniqueSets { // heterogenous sets

                            // create list of sets
                            var newSets: [Set] = []
                            for index in 0...heteroSets_Weights.count-1 {
                                let inputtedWeight = Float(heteroSets_Weights[index].dropLast(4))
                                let inputtedReps = Int(heteroSets_Reps[index].dropLast(5))
                                if let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps  {
                                    let newSet = Set(weight: unwrappedWeight, reps: unwrappedReps, tillFailure: heteroSets_Failure[index])
                                    newSets.append(newSet)
                                }
                            }
                            
                            // create new exercise + append it to planViewModel's active plan
                            let newExercise = Exercise(name: exerciseName, sets: newSets)
                            planViewModel.activePlan.exercises.append(newExercise)
                            
                            
                        } else { // homogenous sets
                            if exerciseViewModel.activeExerciseMode == "AddMode" {
                                let inputtedSets = Int(selectedSets.dropLast(5))
                                let inputtedWeight = Float(selectedWeight.dropLast(4))
                                let inputtedReps = Int(selectedReps.dropLast(5))
                                
                                // create sets
                                var newSets: [Set] = []
                                if let unwrappedSets = inputtedSets, let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps {
                                    for _ in 0...unwrappedSets-1 {
                                        let newSet = Set(weight: unwrappedWeight, reps: unwrappedReps, tillFailure: false)
                                        newSets.append(newSet)
                                    }
                                }
                                
                                // create new exercise + append it to planViewModel's active plan
                                let newExercise = Exercise(name: exerciseName, sets: newSets)
                                planViewModel.activePlan.exercises.append(newExercise)
                                
                            } else { // Edit Mode or Log Mode
                                
                            }
                        }
                    } else if exerciseViewModel.activeExerciseMode == "EditMode" || exerciseViewModel.activeExerciseMode == "LogMode" {
                        
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
                        
                        // update active plan's exercises with the updated exercise
                        let updatedExercise = Exercise(name: exerciseName, sets: setList)
                        planViewModel.activePlan.exercises[exerciseViewModel.activeExerciseIndex] = updatedExercise
                        
                    }
                    
                    feedbackGenerator.impactOccurred()
                    self.presentationMode.wrappedValue.dismiss()
                    
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
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
                
//                // DELETE BUTTON
//                Button(action: {
//                    // perform delete function
//                }) {
//                    Text("Delete")
//                        .bold()
//                }
//                .disabled(true)
//                .foregroundColor(darkGray)
//
//                Spacer()
            }
            .padding(.top, 20)
            
            Spacer()
        }
            
        }
        .background(Color(.systemGray6))
        .onAppear {
            // assign exercise data from view model to UI input controls
            exerciseName = exerciseViewModel.activeExercise.name
            viewUniqueSets  = exerciseViewModel.activeExercise.setsAreUnique
            
            if exerciseViewModel.activeExerciseMode == "AddMode" {
                if viewUniqueSets {
                    // add unique sets to new exercise + append to active plan
                } else {
                    selectedSets    = "3 sets"
                    selectedWeight  = "5 lbs"
                    selectedReps    = "12 reps"
                }
            } else if exerciseViewModel.activeExerciseMode == "EditMode" {
                if viewUniqueSets {
                    // udpate exercise with unique sets + update active plan with edited exercise
                } else { // homogenous sets
                    selectedSets    = "\(exerciseViewModel.activeExercise.sets.count) sets"
                    selectedWeight  = "\(Int(exerciseViewModel.activeExercise.sets[0].weight)) lbs"
                    selectedReps    = "\(exerciseViewModel.activeExercise.sets[0].reps) reps"
                }
            } else if exerciseViewModel.activeExerciseMode == "LogMode" {
                if viewUniqueSets {
                    // udpate exercise with unique sets + update active plan with edited exercise
                } else { // homogenous sets
                    selectedSets    = "\(exerciseViewModel.activeExercise.sets.count) sets"
                    selectedWeight  = "\(Int(exerciseViewModel.activeExercise.sets[0].weight)) lbs"
                    selectedReps    = "\(exerciseViewModel.activeExercise.sets[0].reps) reps"
                }
            }

            // isNameFieldFocused = exerciseViewModel.activeExercise.name == ""
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
