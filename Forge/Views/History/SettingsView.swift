import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    ForEach(ColorTheme.allCases, id: \.self) { theme in
                        Button {
                            settings.colorTheme = theme
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(theme.color)
                                        .frame(width: 36, height: 36)
                                    if settings.colorTheme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                }
                                Text(theme.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(GlobalSettings.shared.bgColor)
            } header: {
                Text("Accent Color")
            }


            Section {
                let plansWithDate = planViewModel.workoutPlans.filter { $0.lastCompleted != nil }
                if plansWithDate.isEmpty {
                    Text("No plans with completion dates")
                        .foregroundColor(GlobalSettings.shared.editorDarkGray)
                        .listRowBackground(GlobalSettings.shared.bgColor)
                } else {
                    ForEach(plansWithDate) { plan in
                        if let index = planViewModel.workoutPlans.firstIndex(where: { $0.id == plan.id }),
                           let date = plan.lastCompleted {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plan.name)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    Text(completedWorkoutsViewModel.numberOfDaysString(from: date))
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Button {
                                    planViewModel.workoutPlans[index].lastCompleted = nil
                                    planViewModel.savePlans()
                                } label: {
                                    Text("Reset")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(settings.fgColor)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                            }
                            .listRowBackground(GlobalSettings.shared.bgColor)
                        }
                    }
                }
            } header: {
                Text("Reset Last Completed")
            }
        }
        .scrollContentBackground(.hidden)
        .background(.black)
        .navigationTitle("Settings")
        .navigationBarTitleTextColor(settings.fgColor)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(GlobalSettings.shared)
                .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
                .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
                .preferredColorScheme(.dark)
        }
    }
}
