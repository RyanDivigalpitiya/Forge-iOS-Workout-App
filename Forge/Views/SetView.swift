import SwiftUI

struct SetView: View {
    
    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////

    var setIndex: Int
    var exerciseIndex: Int
    var uniqueSets: Bool
    var displayLabelBKG: Bool
    
    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height
    let setsFontSize: CGFloat = 20 // Font size used for text in set rows
    let setsSpacing: CGFloat = 3

    
    var body: some View {
        
        let set = planViewModel.activePlan.exercises[exerciseIndex].sets[setIndex]
        if uniqueSets {
            HStack {
                if setIndex+1 > 9 {
                    Text("Set \(setIndex+1)")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 67, height: 28)
                        .background(displayLabelBKG ? fgColor : Color.clear)
                        .cornerRadius(5)
                        .padding(.trailing, setsSpacing+2)
                } else {
                    Text("Set \(setIndex+1)")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 28)
                        .background(displayLabelBKG ? fgColor : Color.clear)
                        .cornerRadius(5)
                        .padding(.trailing, setsSpacing+2)

                }
                Text("\(Int(set.weight)) lb")
                    .foregroundColor(.white)
                    .padding(.trailing, setsSpacing)
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .padding(.top,3)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.trailing, setsSpacing)
                    
                if set.tillFailure {
                    Text("Until Failure").foregroundColor(.gray).opacity(0.6)
                } else {
                    Text("\(set.reps) reps").foregroundColor(.gray).opacity(0.6)
                }
                Spacer()
            }
            .fontWeight(.bold)
            .font(.system(size: setsFontSize))
        } else {
            HStack {
                if planViewModel.activePlan.exercises[exerciseIndex].sets.count > 9 {
                    Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets.count) sets")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 67, height: 28)
                        .background(fgColor)
                        .cornerRadius(5)
                        .padding(.trailing, setsSpacing+2)
                } else {
                    Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets.count) sets")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 58, height: 28)
                        .background(fgColor)
                        .cornerRadius(5)
                        .padding(.trailing, setsSpacing+2)

                }
                Text("\(Int(planViewModel.activePlan.exercises[exerciseIndex].sets[0].weight)) lb")
                    .foregroundColor(.white)
                    .padding(.trailing, setsSpacing)
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .padding(.top,3)
                    .foregroundColor(.gray)
                    .opacity(0.6)
                    .padding(.trailing, setsSpacing)
                Text("\(planViewModel.activePlan.exercises[exerciseIndex].sets[0].reps) reps")
                    .foregroundColor(.gray)
                    .opacity(0.6)
                Spacer()
            }
            .padding(.top, -8)
            .fontWeight(.bold)
            .font(.system(size: setsFontSize))

        }

    }
}

struct SetView_Previews: PreviewProvider {
    static var previews: some View {
        SetView(setIndex: 0, exerciseIndex: 0, uniqueSets: true, displayLabelBKG: true)
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .preferredColorScheme(.dark)

    }
}
