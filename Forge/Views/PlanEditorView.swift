import SwiftUI

struct PlanEditorView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var viewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @FocusState private var isPlanNameFocused: Bool // used to assign focus on plan name textfield on appear
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        VStack {
            Text("Create New Plan")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(fgColor)
            
            TextField("Plan Name (Ex: Leg Day)", text: $viewModel.activePlan.name)
                .padding()
                .focused($isPlanNameFocused)
                .autocapitalization(.words)
                .modifier(CustomFontModifier(size: 25, weight: .bold, color: Color.white, opacity: 1.0))
                .textFieldStyle(RoundedTextFieldStyle(borderColor: Color.gray, borderOpacity: 0.0, backgroundColor: Color(.systemGray6)))
                .multilineTextAlignment(.center)
            
            Text("Exercises:")
                .font(.headline)
                .fontWeight(.bold)
                .padding(EdgeInsets(top:1, leading: 0, bottom: 15, trailing: 0))
                .foregroundColor(.gray)
            
            ScrollView {
                LazyVStack {
                    ForEach(viewModel.activePlan.exercises.indices, id: \.self) { index in
                        Button(action: {
                            // bring up Exercise Editor View
                        }) {
                            VStack() {
                                HStack {
                                    // Exercise Name
                                    Text(viewModel.activePlan.exercises[index].name)
                                        .foregroundColor(fgColor)
                                        .fontWeight(.bold)
                                        .font(.system(size: 25))
                                        .padding(.bottom,1)
                                    Spacer()
                                }
                                let setRepsString = "( \(viewModel.activePlan.exercises[index].sets) Sets x \(viewModel.activePlan.exercises[index].reps) Reps )"
                                
                                HStack {
                                    // Exercise Data
                                    Text(viewModel.isThereNonZeroDecimal(in: viewModel.activePlan.exercises[index].weight) + " lbs")
                                        .fontWeight(.bold)
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                    Text(setRepsString)
                                        .font(.system(size: 20))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                            }
                        }
                        .padding(15)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray5)))
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 8)
                }
            }
            
            Spacer()
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Dismiss").foregroundColor(fgColor)
            }
        }
        .background(Color(.systemGray6))
    }
}

struct PlanEditorView_Previews: PreviewProvider {
    static var previews: some View {
        PlanEditorView()
            .environmentObject(PlanViewModel(mockPlans: mockWorkouts))
            .preferredColorScheme(.dark)
    }
}
