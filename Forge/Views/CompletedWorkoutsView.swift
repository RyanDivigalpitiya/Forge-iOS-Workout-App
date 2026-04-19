import SwiftUI

struct CompletedWorkoutsView: View {
    
    //-//////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-//////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var historyViewIsPresented = false
    @State private var settingsViewIsPresented = false

    @StateObject private var sessionClient = SessionClient()
    @State private var workoutWithFriendActive = false
    @State private var joinerConnectingActive = false

    @EnvironmentObject var settings: GlobalSettings

    @Environment(\.scenePhase) private var scenePhase

    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(completedWorkoutsViewModel.completedWorkouts.indices.reversed(), id: \.self) { completedWorkoutIndex in
                    
                    Button(action: {
                        completedWorkoutsViewModel.activePlan = completedWorkoutsViewModel.completedWorkouts[completedWorkoutIndex]
                        historyViewIsPresented = true
                    }) {
                        let completedWorkout = completedWorkoutsViewModel.completedWorkouts[completedWorkoutIndex]
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text(completedWorkoutsViewModel.numberOfDaysString(from: completedWorkout.dateCompleted))
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.bottom, 2)
                            
                            
                            Text(completedWorkout.workout.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(settings.fgColor)
                                .padding(.top, 3)
                                .padding(.bottom, 9)
                            
                            HStack {
                                Image(systemName: "clock.fill")
                                    .resizable()
                                    .frame(width: 13, height: 13)
                                Text("\(completedWorkoutsViewModel.format(timeInterval: completedWorkout.elapsedTime))")
                                    .padding(.leading, -3)
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .frame(width: 13, height: 13)
                                    .padding(.leading,7)
                                Text("Completion: \(completedWorkout.completion)")
                                    .padding(.leading, -3)
                            }
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.systemGray2))
                            .padding(.bottom, 2)
                        }
                        .padding(.vertical, 12)

                    }
                }
                .onDelete(perform: completedWorkoutsViewModel.deleteCompletedWorkouts)
                .listRowBackground(bgColor)
            }
            .sheet(isPresented: $historyViewIsPresented) {
                HistoryView()
                    .presentationDragIndicator(.hidden)
                    .environment(\.colorScheme, .dark)
            }
            .navigationBarTitle(Text("History"))
            .navigationBarTitleTextColor(settings.fgColor)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        workoutWithFriendActive = true
                    } label: {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(settings.fgColor)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        settingsViewIsPresented = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(settings.fgColor)
                    }
                }
                ToolbarItemGroup(placement: .bottomBar){
                    Button {
                        completedWorkoutsViewModel.isSelectPlanViewActive = true
                    } label: {
                        HStack {
                            Image(systemName: "figure.run")
                                .resizable()
                                .frame(width: 15, height: 20)
                                .padding(.trailing, 3)
                            Text("Start Workout")
                        }
                    }
                    .padding(5)
                    .padding(.horizontal, 10)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(settings.fgColor)
                }
            }
            .navigationDestination(isPresented: $completedWorkoutsViewModel.isSelectPlanViewActive) {
                SelectPlanView()
            }
            .navigationDestination(isPresented: $settingsViewIsPresented) {
                SettingsView()
            }
            .navigationDestination(isPresented: $workoutWithFriendActive) {
                WorkoutWithFriendView()
                    .environmentObject(sessionClient)
                    .environmentObject(settings)
            }
            .navigationDestination(isPresented: $joinerConnectingActive) {
                ConnectingView()
                    .environmentObject(sessionClient)
                    .environmentObject(settings)
            }
        }
        .background(.black)
        .accentColor(settings.fgColor)
        .onAppear{
            completedWorkoutsViewModel.isSelectPlanViewActive = false
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase != .active {
                sessionClient.reconnect()
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.pathExtension.lowercased() == "forgeplan" {
            importIncomingPlan(from: url)
            return
        }
        if url.scheme?.lowercased() == "forge",
           url.host?.lowercased() == "session" {
            let idString = url.pathComponents.last(where: { $0 != "/" }) ?? ""
            if let id = UUID(uuidString: idString) {
                sessionClient.joinSession(id: id)
                joinerConnectingActive = true
            }
        }
    }

    private func importIncomingPlan(from url: URL) {
        guard url.pathExtension.lowercased() == "forgeplan" else { return }
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard
            let data = try? Data(contentsOf: url),
            let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data)
        else {
            print("Failed to decode shared plan at \(url.lastPathComponent)")
            return
        }
        planViewModel.importPlan(plan)
    }
}

extension View {
    // Sets the text colour for a navigation bar title.
    // Updates the appearance proxy for future bars AND force-updates
    // any existing UINavigationBar instances so the change is visible
    // immediately (not only after an app restart).
    @available(iOS 14, *)
    func navigationBarTitleTextColor(_ color: Color) -> some View {
        let uiColor = UIColor(color)
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: uiColor]
        UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: uiColor]
        return self.onChange(of: color) { _, newColor in
            applyNavigationBarTitleColor(UIColor(newColor))
        }
    }
}

private func applyNavigationBarTitleColor(_ color: UIColor) {
    UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: color]
    UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: color]
    for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for window in windowScene.windows {
            updateNavigationBars(in: window, color: color)
        }
    }
}

private func updateNavigationBars(in view: UIView, color: UIColor) {
    if let navBar = view as? UINavigationBar {
        let standard = navBar.standardAppearance.copy()
        standard.titleTextAttributes[.foregroundColor] = color
        standard.largeTitleTextAttributes[.foregroundColor] = color
        navBar.standardAppearance = standard
        if let scroll = navBar.scrollEdgeAppearance?.copy() {
            scroll.titleTextAttributes[.foregroundColor] = color
            scroll.largeTitleTextAttributes[.foregroundColor] = color
            navBar.scrollEdgeAppearance = scroll
        }
    }
    for subview in view.subviews {
        updateNavigationBars(in: subview, color: color)
    }
}


struct CompletedWorkoutsView_Previews: PreviewProvider {
    static var previews: some View {
        CompletedWorkoutsView()
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
