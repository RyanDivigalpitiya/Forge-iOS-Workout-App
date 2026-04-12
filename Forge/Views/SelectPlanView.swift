import SwiftUI

struct SelectPlanView: View {

    //-/////////////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel
    //-/////////////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-////////////////////////////////////////////////


    @State private var planEditorIsPresented = false
    @State private var workoutInProgressViewPresented = false
    @State private var editMode: EditMode = .inactive
    @State private var planToDeleteIndex: Int? = nil
    @State private var showDeleteConfirmation = false

    let fgColor = GlobalSettings.shared.fgColor // foreground colour
    let bgColor = GlobalSettings.shared.bgColor // background colour
    let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight // Bottom Toolbar Height

    var body: some View {
        ZStack {
            List {
                ForEach(planViewModel.workoutPlans) { plan in
                    let index = planViewModel.workoutPlans.firstIndex(where: { $0.id == plan.id })!
                    HStack(spacing:0){
                        VStack {
                            VStack {
                                HStack {
                                    Text(plan.name)
                                        .fontWeight(.bold)
                                        .font(.system(size: 30))
                                        .foregroundColor(fgColor)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    HStack {
                                        Text("START")
                                            .font(.system(size: 12))
                                            .foregroundColor(.black)
                                            .fontWeight(.bold)
                                    }
                                    .padding(8)
                                    .padding(.horizontal,1)
                                    .background(fgColor)
                                    .cornerRadius(5)
                                    .shadow(
                                        color: fgColor.opacity(0.4), // color + transparency
                                        radius: 15,                  // blur
                                        x: 0,                        // horizontal offset
                                        y: 0                         // vertical offset
                                    )
                                }
                                .padding(.top,5)

                                if let lastComleted = plan.lastCompleted {
                                    HStack {
                                        Text("Last Completed: ")
                                            .foregroundColor(Color.gray.opacity(0.5))
                                            .fontWeight(.bold)
                                        Text(completedWorkoutsViewModel.numberOfDaysString(from: lastComleted))
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                        Spacer()
                                    }
                                    .padding(.top, 1)
                                    .padding(.bottom, 13)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startWorkout(at: index)
                            }


                            Divider()

                            HStack {
                                // NUMBER OF EXERCISES
                                Image(systemName: "dumbbell.fill")
                                    .resizable()
                                    .frame(width: 18, height: 13)
                                    .foregroundColor(.gray)
                                    .opacity(0.4)
                                    .padding(.vertical, 15)
                                Text(String(plan.exercises.count) + " Exercises")
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .fontWeight(.bold)
                                // DURATION OF WORKOUT
                                Image(systemName: "clock.fill")
                                    .resizable()
                                    .frame(width: 13, height: 13)
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .padding(.leading, 10)
                                Text(String(planViewModel.calculateWorkoutDuration(for: plan)) + " min")
                                    .foregroundColor(Color.gray.opacity(0.5))
                                    .fontWeight(.bold)
                                    .padding(.leading, -3)
                                Spacer()
                                // EDIT BUTTON //////////////////
                                Button( action: {
                                    startEditingPlan(at: index)
                                }) {
                                    Image(systemName: "pencil.circle.fill")
                                        .resizable()
                                        .frame(width: 15, height: 15)
                                        .foregroundColor(Color.gray.opacity(0.5))
                                        .padding(.trailing, 2)
                                        .padding(.vertical, 15)
                                }
                            }
                        }
                        .padding(.leading, 5)
                        .padding(.trailing, 20)
                        .padding(.top, 5)
                        .padding(.bottom, -9)
                    }
                    .padding(.vertical)
                    .padding(.leading)
                    .background(bgColor)
                    .cornerRadius(15)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            planToDeleteIndex = index
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 13, leading: 20, bottom: 13, trailing: 20))
                }
                .onMove(perform: planViewModel.movePlan)

                // Bottom spacing to clear the toolbar
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, $editMode)
            .alert("Delete Plan?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { planToDeleteIndex = nil }
                Button("Delete", role: .destructive) {
                    if let index = planToDeleteIndex {
                        planViewModel.deletePlan(at: IndexSet(integer: index))
                    }
                    planToDeleteIndex = nil
                }
            }
            .fullScreenCover(isPresented: $workoutInProgressViewPresented) {
                WorkoutInProgressView()
                    .environment(\.colorScheme, .dark)
            }

            VStack {
                Spacer()

                // Bottom toolbar
                HStack {
                    Spacer()

                    // NEW BUTTON
                    Button(action: {
                        // set activePlan to a new plan
                        planViewModel.activePlan = WorkoutPlan()
                        planViewModel.activePlanMode = .add
                        self.planEditorIsPresented = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .padding(.trailing, 3)
                            Text("New")
                                .font(.system(size: 20))
                        }
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    }
                    .fullScreenCover(isPresented: $planEditorIsPresented) {
                        PlanEditorView()
                            .environment(\.colorScheme, .dark)
                    }

                    Spacer()

                    // REORDER BUTTON
                    Button(action: {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }) {
                        HStack {
                            Image(systemName: editMode == .active
                                ? "checkmark.circle.fill"
                                : "arrow.up.arrow.down.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .padding(.trailing, 3)
                            Text(editMode == .active ? "Done" : "Order")
                                .font(.system(size: 20))
                        }
                        .fontWeight(.bold)
                        .foregroundColor(fgColor)
                    }

                    Spacer()
                }
                .frame(height: bottomToolbarHeight)
                .padding(.bottom, 10)
                .background(BlurView(style: .systemChromeMaterial))
            }
        }
        .navigationBarTitle(Text("Select Plan"))
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

private extension SelectPlanView {
    func startWorkout(at index: Int) {
        guard planViewModel.workoutPlans.indices.contains(index) else { return }
        planViewModel.activePlan = planViewModel.workoutPlans[index]
        planViewModel.activePlanIndex = index
        workoutInProgressViewPresented = true
    }

    func startEditingPlan(at index: Int) {
        guard planViewModel.workoutPlans.indices.contains(index) else { return }
        planViewModel.activePlan = planViewModel.workoutPlans[index]
        planViewModel.activePlanMode = .edit
        planViewModel.activePlanIndex = index
        planEditorIsPresented = true
    }
}

struct SelectPlanView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPlanView()
            .environmentObject(ExerciseViewModel())
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .preferredColorScheme(.dark)
    }
}
