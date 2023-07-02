import SwiftUI

struct ExerciseEditorView: View {
    
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-////////////////////////////////////////////////////////
    @EnvironmentObject var exerciseViewModel: ExerciseViewModel
    //-////////////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState private var isNameFieldFocused: Bool // used to assign focus on exercise name textfield on appear
    @Binding var selectedDetent: PresentationDetent
    
    //- ////////////////////////////////////////////////////////////////////////////
    // Data being inputted / edited:
    @State var exerciseName: String = ""
    // Homogenous Sets: ////////////////////////////////////////////////////////////
    @State private var homoSelectedSets = "3 sets"
    @State private var homoSelectedWeight = "5 lbs"
    @State private var homoSelectedReps = "12 reps"
    // Heterogenous Sets: ////////////////////////////////////////////////////////////
    @State private var heteroSets_Weights: [String] = ["5 lbs", "5 lbs", "5 lbs"]
    @State private var heteroSets_Reps: [String] = ["12 reps", "12 reps", "12 reps"]
    @State private var heteroSets_Failure: [Bool] = [false, false, false]
    let setsRange = Array(1...50).reversed().map { "\($0) sets" }
    let weightRange = stride(from: 500, through: -100, by: -5).map { "\($0) lbs" }
    let repsRange = Array(1...500).reversed().map { "\($0) reps" }
    //- ////////////////////////////////////////////////////////////////////////////
    
    // Toggle for changing individual sets
    @State private var areSetsUnique = false
    @State private var homoHeteroControlsAreConnected: Bool = false
    @State private var editedExerciseStartedWithUniqueSets: Bool = false
    
    // Animation + Feedback parameters
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @State private var homogenousSelectorHeight: CGFloat = 200
    @State private var heterogenousSelectorHeight: CGFloat = 0
    @State private var homogenousSelectorOpacity: Double = 1.0
    @State private var heterogenousSelectorOpacity: Double = 0
    @State private var heterogenousSetMaxViewHeight: CGFloat = CGFloat((150*3)+80)
    @State private var heterogenousSetRowHeight: CGFloat = 1000000
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let fontSize: CGFloat = 21
    let fontTitleSize: CGFloat = 35
    let buttonPlusMinusIconSize: CGFloat = 15
    let buttonPlusMinusWidth: CGFloat = 85
    let buttonPlusMinusHeight: CGFloat = 30
    let buttonPlusMinusSize: CGFloat = 5
    let wheelSelectorSize: CGFloat = 150
    let darkGray: Color = Color(red: 0.33, green: 0.33, blue: 0.33)
    let screenWidth = UIScreen.main.bounds.width
    


    var body: some View {
        VStack {
            ScrollView {
            
                // TOP TOOLBAR TITLE
                HStack {
                    
                    // dismiss button
                    HStack {
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            ZStack {
                                Circle()
                                    .frame(width: 28, height: 28)
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                Image(systemName: "xmark")
                                    .resizable()
                                    .frame(width: 11, height: 11)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(width: 0.2*screenWidth)
                
                    // Title text
                    HStack {
                        if exerciseViewModel.activeExerciseMode == "AddMode" {
                            Text("Add Exercise")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(fgColor)
                                .fontWeight(.bold)
                        } else if exerciseViewModel.activeExerciseMode == "EditMode" {
                            Text("Edit Exercise")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(fgColor)
                                .fontWeight(.bold)
                        } else {
                            Text("Log Change")
                                .font(.system(size:fontTitleSize))
                                .foregroundColor(fgColor)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(width: 0.6*screenWidth)
                
                    // save button
                    HStack {
                        Button(action: {
                            saveExercise()
                        }) {
                            ZStack {
                                if exerciseViewModel.activeExerciseMode == "AddMode" {
                                    Circle()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    Image(systemName: "plus")
                                        .resizable()
                                        .frame(width: 13, height: 13)
                                        .fontWeight(.bold)
                                        .foregroundColor(fgColor)
                                } else if exerciseViewModel.activeExerciseMode == "EditMode" {
                                    Circle()
                                        .frame(width: 28, height: 28)
                                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                    Image("Checkmark")
                                        .resizable()
                                        .frame(width: 15, height: 13)
                                        .padding(.top,1)
                                }
                            }
                        }
                    }
                    .frame(width: 0.2*screenWidth)
            }
                .padding(.top,15)
                        
                // EXERCISE NAME
                VStack{
                    TextField("Enter Exercise Name Here", text: $exerciseName)
                        .frame(width: 300)
                        .focused($isNameFieldFocused)
                        .autocapitalization(.words)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 23))
                        .padding(.bottom, 10)
                }
            
                // HOMOGENOUS SET SELECTORS
                HStack {
                    
                    // SETS SELECTOR
                    VStack {
                        VStack {
                            Picker(selection: $homoSelectedSets, label: Text("Weight")) {
                               ForEach(setsRange, id: \.self) {
                                   Text("\($0)")
                                       .foregroundColor(fgColor)
                               }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 100)
                            .frame(maxHeight: wheelSelectorSize)
                        }
                           
                        HStack() {
                            // DECREMENT BUTTON
                            Button(action: {
                                if var num = Int(homoSelectedSets.dropLast(5)) {
                                    if num > 1 {
                                        num -= 1
                                        homoSelectedSets = "\(num) sets"
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
                                if var num = Int(homoSelectedSets.dropLast(5)) {
                                    if num < 999{
                                        num += 1
                                        homoSelectedSets = "\(num) sets"
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
                        Picker(selection: $homoSelectedWeight, label: Text("Weight")) {
                           ForEach(weightRange, id: \.self) {
                               Text("\($0)")
                                   .foregroundColor(fgColor)

                           }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxHeight: wheelSelectorSize)
                        .frame(width: 100)
                           
                        HStack() {
                            // DECREMENT BUTTON
                            Button(action: {
                                if var num = Int(homoSelectedWeight.dropLast(4)) {
                                    if num > -956 {
                                        num -= 5
                                        homoSelectedWeight = "\(num) lbs"
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
                                if var num = Int(homoSelectedWeight.dropLast(4)) {
                                    if num < 956{
                                        num += 5
                                        homoSelectedWeight = "\(num) lbs"
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
                        Picker(selection: $homoSelectedReps, label: Text("Reps")) {
                           ForEach(repsRange, id: \.self) {
                               Text("\($0)")
                                   .foregroundColor(fgColor)
                           }
                        }
                       .pickerStyle(WheelPickerStyle())
                       .frame(maxHeight: wheelSelectorSize)
                       .frame(width: 100)
                           
                        HStack() {
                            // DECREMENT BUTTON
                            Button(action: {
                                if var num = Int(homoSelectedReps.dropLast(5)) {
                                    if num > 1{
                                        num -= 1
                                        homoSelectedReps = "\(num) reps"
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
                                if var num = Int(homoSelectedReps.dropLast(5)) {
                                    if num < 999 {
                                        num += 1
                                        homoSelectedReps = "\(num) reps"
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
                    Toggle(isOn: $areSetsUnique) {
                        Text("Change Specific Sets")
                            .foregroundColor(areSetsUnique ? fgColor : darkGray)
                            .fontWeight(.bold)
                    }
                    .onChange(of: areSetsUnique) { newValue in
    
                        if editedExerciseStartedWithUniqueSets {
                            // do nothing.
                            /*
                             when this editor view appears with unique sets to be edited,
                             this toggle will automatically be switched from false to true.
                             When this happens, we do not want to update the hetero data based on homo data because
                             the user did not trigger this switch, the UI does when loading itself.
                             So the first time this toggle is switched WHEN an exercise to be edited has unique sets
                             should not trigger updateHeteroDataBasedOnHomoData()
                             However, after the data loads, and the user switches toggle to false, then back to true again,
                             we want to always trigger updateHeteroDataBasedOnHomoData() from there on out.
                             Thus, we set editedExerciseStartedWithUniqueSets = false after this if-else statement
                             */
                        } else {
                            if newValue == false { // we're switching to viewing the homogenous sets
                                updateHomoDataBasedOnHeteroData()
                            } else { // we're switching to viewing the heterogenous sets
                                updateHeteroDataBasedOnHomoData()
                            }
                        }
                        
                        editedExerciseStartedWithUniqueSets = false
    
                        selectedDetent = newValue ? .large : .medium
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            homogenousSelectorHeight = newValue ? 0 : 200
                            homogenousSelectorOpacity = newValue ? 0 : 1
                            heterogenousSelectorHeight = newValue ? heterogenousSetMaxViewHeight : 0
                            heterogenousSelectorOpacity = newValue ? 1 : 0
                        }
                    }
                }
                .frame(width: 235)
                .padding(.top, areSetsUnique ? 0 : 20)
            
                // HETEROGENOUS SET ROWS + CONTROLS
                VStack {
                    if !exerciseViewModel.activeExercise.sets.isEmpty {
                        
                        ForEach(heteroSets_Weights.indices, id: \.self) { setIndex in
                            
                            // SET ROW
                            HStack() {
                                // padding hstack
                                HStack { // internal padding hstack
                                    
                                    // SET LABEL + DELETE BUTTON
                                    VStack{
                                        // SET LABEL
                                        Text("Set \(setIndex+1)")
                                            .foregroundColor(darkGray)
                                            .fontWeight(.bold)
                                            .font(.system(size: fontSize))
                                            .frame(width: 70)
                                        
                                        // DELETE BUTTON
                                        Button(action: {
                                            heteroSets_Weights.remove(at: setIndex)
                                            heteroSets_Reps.remove(at: setIndex)
                                            heteroSets_Failure.remove(at: setIndex)
                                            
                                        }) {
                                            Image(systemName: "trash.fill")
                                                .foregroundColor(.black)
                                                .font(.system(size: buttonPlusMinusIconSize))
                                                .bold()
                                                .padding(buttonPlusMinusSize)
                                        }
                                        .frame(width: 60, height: buttonPlusMinusHeight)
                                        .background(fgColor)
                                        .cornerRadius(5)
                                        .onChange(of: heteroSets_Weights) { newValue in
                                            let count = newValue.count
                                            // compute new height
                                            heterogenousSetMaxViewHeight = CGFloat((count*Int(heterogenousSetRowHeight))+80)
                                            homoSelectedSets = "\(newValue.count) sets"
                                        }
                                    }
                                    .padding(.trailing,10)
                                    
                                    
                                    // WEIGHT LABEL + PLUS/MINUS BUTTONS
                                    VStack{
                                        // WEIGHT LABEL
                                        Text("\(heteroSets_Weights[setIndex])")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                            .font(.system(size: fontSize))
                                            .frame(width: 100)
                                        
                                        // PLUS/MINUS BUTTON
                                        HStack() {
                                            // DECREMENT BUTTON
                                            Button(action: {
                                                if var num = Int(heteroSets_Weights[setIndex].dropLast(4)) {
                                                    if num > -956 {
                                                        num -= 5
                                                        heteroSets_Weights[setIndex] = "\(num) lbs"
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
                                                if var num = Int(heteroSets_Weights[setIndex].dropLast(4)) {
                                                    if num < 956{
                                                        num += 5
                                                        heteroSets_Weights[setIndex] = "\(num) lbs"
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
                                        Rectangle().frame(width: 1, height: buttonPlusMinusHeight)
                                            .hidden()
                                            .padding(.bottom,9)
                                    }
                                    .padding(.horizontal, -5)
                                    
                                    // REPS LABEL + PLUS/MINUS BUTTONS
                                    VStack{
                                        // REPS LABEL
                                        if heteroSets_Failure[setIndex] {
                                            Text("till Failure")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .font(.system(size: fontSize))
                                                .frame(width: 120)
                                        } else {
                                            Text("\(heteroSets_Reps[setIndex])")
                                                .foregroundColor(.white)
                                                .fontWeight(.bold)
                                                .font(.system(size: fontSize))
                                                .frame(width: 120)
                                        }
                                        
                                        // PLUS/MINUS BUTTON
                                        HStack() {
                                            // DECREMENT BUTTON
                                            Button(action: {
                                                if var num = Int(heteroSets_Reps[setIndex].dropLast(5)) {
                                                    if num > 1{
                                                        num -= 1
                                                        heteroSets_Reps[setIndex] = "\(num) reps"
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
                                                if var num = Int(heteroSets_Reps[setIndex].dropLast(5)) {
                                                    if num < 999 {
                                                        num += 1
                                                        heteroSets_Reps[setIndex] = "\(num) reps"
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
                                            
                                            Rectangle().frame(width: 1, height: 18).foregroundColor(.black).opacity(0.3)
                                            
                                            // TILL FAILURE (♾️) BUTTON
                                            Button(action: {
                                                heteroSets_Failure[setIndex].toggle()
                                            }) {
                                                Image(systemName: "infinity")
                                                    .foregroundColor( heteroSets_Failure[setIndex] ? .white : .black)
                                                    .font(.system(size: buttonPlusMinusIconSize))
                                                    .bold()
                                                    .padding(buttonPlusMinusSize)
                                            }
                                        }
                                        .frame(width: buttonPlusMinusWidth+50, height: buttonPlusMinusHeight)
                                        .background(fgColor)
                                        .cornerRadius(5)

                                    }

                                    
                                }
                            }
                            .frame(height: 100)
                            .padding(.top, 10)
                            .cornerRadius(20)
                        }
                    }
                    // ADD SET BUTTON
                    Button(action: {
                        if let unwrappedLastWeight = heteroSets_Weights.last {
                            heteroSets_Weights.append(unwrappedLastWeight)
                        }
                        if let unwrappedLastRep = heteroSets_Reps.last {
                            heteroSets_Reps.append(unwrappedLastRep)
                        }
                        if let unwrappedLastFailure = heteroSets_Failure.last {
                            heteroSets_Failure.append(unwrappedLastFailure)
                        }
                        
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Set").fontWeight(.bold)
                        }
                        .frame(height: 20)
                        .foregroundColor(fgColor)
                    }
                    .onChange(of: heteroSets_Weights) { newValue in
                        let count = newValue.count
                        // compute new height
                        heterogenousSetMaxViewHeight = CGFloat((count*Int(heterogenousSetRowHeight))+80)
                        homoSelectedSets = "\(newValue.count) sets"
                    }
                    .padding(.top, 20)
                    
                    // SAVE BUTTON
                    HStack {
                        Button(action: {
                            saveExercise()
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
                    }
                    .padding(20)
                }
                .frame(maxHeight: heterogenousSelectorHeight)
                .clipped()
                .opacity(heterogenousSelectorOpacity)
            
            
            Spacer()
            }
            
        }
        .background(Color(.systemGray6))
        .onAppear {
            homoHeteroControlsAreConnected = false
            // initialize UI dimensions, labels + toggle based on activeExercise and activeMode
            // name field
            exerciseName = exerciseViewModel.activeExercise.name
            // heterogenousSetMaxViewHeight
            let count = exerciseViewModel.activeExercise.sets.count
            heterogenousSetMaxViewHeight = CGFloat((Int(heterogenousSetRowHeight)*count)+80)
            //areSetsUnique  = true // for testing UI purposes
            // whether areSetsUnique toggle is switched to false/true (ie. should view show homogenous exercise or heterogenous set rows)
            areSetsUnique  = exerciseViewModel.activeExercise.areSetsUnique
            if areSetsUnique {
                editedExerciseStartedWithUniqueSets = true
            }
            
            selectedDetent = areSetsUnique ? .large : .medium
            
            // LOAD UI WITH ACTIVE EXERCISE'S DATA: ////////////////////////////////////
            // clear heteroSets_ values and append values from activeExercise's set data
            heteroSets_Weights.removeAll()
            heteroSets_Reps.removeAll()
            heteroSets_Failure.removeAll()
            for index in 0...exerciseViewModel.activeExercise.sets.count-1 {
                heteroSets_Weights.append("\(Int(exerciseViewModel.activeExercise.sets[index].weight)) lbs")
                heteroSets_Reps.append("\(exerciseViewModel.activeExercise.sets[index].reps) reps")
                heteroSets_Failure.append(exerciseViewModel.activeExercise.sets[index].tillFailure)
            }
            
            // assign homoSelected_ data values from activeExercise's data
            homoSelectedSets    = "\(exerciseViewModel.activeExercise.sets.count) sets"
            homoSelectedWeight  = "\(Int(exerciseViewModel.activeExercise.sets[0].weight)) lbs"
            homoSelectedReps    = "\(exerciseViewModel.activeExercise.sets[0].reps) reps"
            // -  //////////////////////////////////// //////////////////////////////////
            
            homoHeteroControlsAreConnected = true
            
            // isNameFieldFocused = exerciseViewModel.activeExercise.name == ""
        }
    }
}

// view functions
extension ExerciseEditorView {
    
    func saveExercise() {
        isNameFieldFocused = false
        
        // create list of sets that were edited
        var newSets: [Set] = []
        
        if areSetsUnique {
            for index in 0...heteroSets_Weights.count-1 {
                let inputtedWeight = Float(heteroSets_Weights[index].dropLast(4))
                let inputtedReps = Int(heteroSets_Reps[index].dropLast(5))
                if let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps  {
                    let newSet = Set(weight: unwrappedWeight, reps: unwrappedReps, tillFailure: heteroSets_Failure[index])
                    newSets.append(newSet)
                }
            }
        } else {
            let inputtedSets = Int(homoSelectedSets.dropLast(5))
            let inputtedWeight = Float(homoSelectedWeight.dropLast(4))
            let inputtedReps = Int(homoSelectedReps.dropLast(5))
            
            if let unwrappedSets = inputtedSets, let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps {
                for _ in 0...unwrappedSets-1 {
                    let newSet = Set(weight: unwrappedWeight, reps: unwrappedReps, tillFailure: false)
                    newSets.append(newSet)
                }
            }
        }
        
        
        if exerciseViewModel.activeExerciseMode == "AddMode" {
            // create new exercise + append it to planViewModel's active plan
            let newExercise = Exercise(name: exerciseName, sets: newSets)
            planViewModel.activePlan.exercises.append(newExercise)

        } else if exerciseViewModel.activeExerciseMode == "EditMode" || exerciseViewModel.activeExerciseMode == "LogMode" {
            // update active plan's exercises with the updated exercise
            let updatedExercise = Exercise(name: exerciseName, sets: newSets)
            planViewModel.activePlan.exercises[exerciseViewModel.activeExerciseIndex] = updatedExercise
        }
        
        feedbackGenerator.impactOccurred()
        self.presentationMode.wrappedValue.dismiss()
    }
    
    func updateHeteroDataBasedOnHomoData() {
        if homoHeteroControlsAreConnected {
            // clear heteroSets_ values and append values from homoSelected_ data
            heteroSets_Weights.removeAll()
            heteroSets_Reps.removeAll()
            heteroSets_Failure.removeAll()
            
            let inputtedSets = Int(homoSelectedSets.dropLast(5))
            let inputtedWeight = Float(homoSelectedWeight.dropLast(4))
            let inputtedReps = Int(homoSelectedReps.dropLast(5))
            
            // update individual sets
            if let unwrappedSets = inputtedSets, let unwrappedWeight = inputtedWeight, let unwrappedReps = inputtedReps {
                for _ in 0...unwrappedSets-1 {
                    heteroSets_Weights.append("\(Int(unwrappedWeight)) lbs")
                    heteroSets_Reps.append("\(unwrappedReps) reps")
                    heteroSets_Failure.append(false)
                    
                }
            }
        }
    }
    
    func updateHomoDataBasedOnHeteroData() {
        if homoHeteroControlsAreConnected {
            homoSelectedSets = "\(heteroSets_Weights.count) sets"
            homoSelectedWeight = heteroSets_Weights[0]
            homoSelectedReps = heteroSets_Reps[0]
        }
    }
}

struct ExerciseEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseEditorView(selectedDetent: .constant(.medium))
            .environmentObject(CompletedWorkoutsViewModel())
            .environmentObject(ExerciseViewModel())
            .preferredColorScheme(.dark)
    }
}
