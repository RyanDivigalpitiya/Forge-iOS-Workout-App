import SwiftUI

struct CompletedWorkoutsView: View {
    
    //-//////////////////////////////////////////
    @EnvironmentObject var completedWorkoutsViewModel: CompletedWorkoutsViewModel
    //-//////////////////////////////////////////
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var historyViewIsPresented = false
    @State private var settingsViewIsPresented = false
    @State private var weightTrackingActive = false
    @State private var progressPhotosActive = false

    @StateObject private var sessionClient = SessionClient()
    @State private var workoutWithFriendActive = false
    @State private var joinerConnectingActive = false

    /// Tracks which row indices have run their on-appear stagger
    /// (mirrors `WorkoutWithFriendView`'s cascade). Rows render at
    /// opacity 0 + .offset(x: 24) until their index lands here.
    /// Re-driven from `.onAppear` so the cascade replays every time
    /// the user navigates back (back from SelectPlanView, dismiss
    /// from WorkoutInProgressView's flow, etc.).
    @State private var appearedRowIndices: Swift.Set<Int> = []
    /// Holds the in-flight cascade so a re-entry (rapid nav-back during
    /// the previous cascade) can cancel before starting fresh.
    @State private var rowCascadeTask: Task<Void, Never>?
    /// Set true when the cascade loop completes. Any row whose index
    /// arrives AFTER the cascade has finished (e.g. a workout completion
    /// whose @Published append lands after the navigation pop has
    /// already triggered .onAppear) renders at final state instead of
    /// getting stuck invisible. Reset to false at the start of every
    /// new cascade so the next nav-back re-animates everything.
    @State private var rowCascadeFinished = false

    @EnvironmentObject var settings: GlobalSettings

    @Environment(\.scenePhase) private var scenePhase

    let bgColor = GlobalSettings.shared.bgColor // background colour
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(completedWorkoutsViewModel.completedWorkouts.indices.reversed(), id: \.self) { completedWorkoutIndex in

                    let isAppeared = rowCascadeFinished || appearedRowIndices.contains(completedWorkoutIndex)

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
                        .opacity(isAppeared ? 1 : 0)
                        .offset(x: isAppeared ? 0 : 24)
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
                    Menu {
                        Button {
                            weightTrackingActive = true
                        } label: {
                            Label("Weight Tracking", systemImage: "scalemass")
                        }
                        Button {
                            progressPhotosActive = true
                        } label: {
                            Label("Progress Photos", systemImage: "photo.on.rectangle.angled")
                        }
                        Divider()
                        Button {
                            settingsViewIsPresented = true
                        } label: {
                            Label("Settings", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
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
            .navigationDestination(isPresented: $weightTrackingActive) {
                WeightHistoryView()
                    .navigationTitle("Weight Tracking")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(isPresented: $progressPhotosActive) {
                ProgressPhotosView()
                    .navigationTitle("Progress Photos")
                    .navigationBarTitleDisplayMode(.inline)
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
        // Inject sessionClient at the NavigationStack root so every nav
        // destination AND every modal presented from within those
        // destinations (e.g. SelectPlanView's .fullScreenCover into
        // WorkoutInProgressView) inherits it. Without this, solo workouts
        // crash because WorkoutInProgressView reads @EnvironmentObject
        // sessionClient and SwiftUI doesn't auto-propagate @StateObject
        // across .fullScreenCover boundaries.
        .environmentObject(sessionClient)
        .background(.black)
        .accentColor(settings.fgColor)
        // Phase C: surface auto-imported plan name set by
        // PlanSuggestionView's no-match / save-and-use-friends paths.
        // Capsule overlay matches CollabStatusBanner's idiom — sits at
        // the top, ~4s auto-dismiss, no user interaction.
        .overlay(alignment: .top) {
            if let name = planViewModel.lastAutoImportedPlanName {
                Text("Saved \"\(name)\" to your plans")
                    .font(.callout.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(settings.darkGray)
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: planViewModel.lastAutoImportedPlanName) { _, newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: settings.animationStandard)) {
                    planViewModel.lastAutoImportedPlanName = nil
                }
            }
        }
        .onAppear{
            completedWorkoutsViewModel.isSelectPlanViewActive = false
            triggerRowCascade()
        }
        // `.onAppear` on a NavigationStack root only reliably fires on
        // initial mount — it does NOT fire on subsequent nav-pops back
        // into this view. Watch the navigation/sheet flags instead so
        // the cascade replays whenever a destination/modal dismisses
        // and the user lands back on the History list.
        .onChange(of: anyDestinationOrModalActive) { wasActive, isActive in
            if wasActive && !isActive {
                triggerRowCascade()
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                if oldPhase != .active {
                    sessionClient.reconnect()
                    // After reconnect, the rebind path on the server
                    // implicitly broadcasts peerReturned. This call is
                    // a defensive fallback for the rare case where the
                    // WS survived backgrounding (no reconnect rebind) —
                    // server's markReturned is a no-op if we're already
                    // .connected, so it's safe to fire either way.
                    sessionClient.sendReturningToForeground()
                }
            case .background:
                // Tell the server we're backgrounding BEFORE iOS kills
                // the WS (~5s of background runtime available). The
                // awaited send guarantees the frame leaves the device
                // before the OS suspends us. Without this, every brief
                // app-switch surfaces a "Friend disconnected" banner
                // on the other phone.
                Task { await sessionClient.sendGoingBackgroundAndAwait() }
            case .inactive:
                // Transient (control center, multitasking switcher) —
                // WS usually survives, don't trigger the away path.
                break
            @unknown default:
                break
            }
        }
        .onChange(of: sessionClient.state) { _, newState in
            if newState == .idle {
                workoutWithFriendActive = false
                joinerConnectingActive = false
            }
        }
    }

    /// Single rolled-up boolean covering every navigation/sheet target
    /// reachable from this view. `.onChange` watches it and re-runs the
    /// row cascade on every true→false transition (i.e. whenever the
    /// user pops/dismisses back to the History list). Reading the
    /// `@EnvironmentObject` flag inside makes the computed value
    /// reactive to model changes.
    private var anyDestinationOrModalActive: Bool {
        historyViewIsPresented
            || settingsViewIsPresented
            || workoutWithFriendActive
            || joinerConnectingActive
            || completedWorkoutsViewModel.isSelectPlanViewActive
    }

    /// Replays the staggered fade + slide-from-right cascade across every
    /// visible row. Called from `.onAppear` (initial mount) and from
    /// `.onChange` of `anyDestinationOrModalActive` (every nav-back).
    /// Cancels any in-flight cascade first so rapid re-entries don't
    /// double-animate. Resetting `appearedRowIndices` snaps rows to
    /// their initial state — the snap is masked by the navigation
    /// transition that brought us here.
    ///
    /// The loop re-reads `completedWorkouts.indices` on every iteration
    /// rather than snapshotting once, so a row that gets appended mid-
    /// cascade (e.g. a workout-finish whose @Published mutation lands
    /// just after `.onAppear` fires) still gets picked up and animated
    /// in. The `rowCascadeFinished` flag covers the post-cascade case:
    /// rows added after the loop ends snap to final state via the
    /// `isAppeared` short-circuit instead of getting stuck invisible.
    private func triggerRowCascade() {
        rowCascadeTask?.cancel()
        appearedRowIndices = []
        rowCascadeFinished = false
        rowCascadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            while !Task.isCancelled {
                let allIndicesNewestFirst = Array(
                    completedWorkoutsViewModel.completedWorkouts.indices.reversed()
                )
                guard let nextIndex = allIndicesNewestFirst.first(where: {
                    !appearedRowIndices.contains($0)
                }) else { break }
                withAnimation(.easeOut(duration: 0.7)) {
                    _ = appearedRowIndices.insert(nextIndex)
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            rowCascadeFinished = true
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
            Log.debug("Failed to decode shared plan at \(url.lastPathComponent)")
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
    @MainActor static var previews: some View {
        CompletedWorkoutsView()
            .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: mockCompletedWorkouts))
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
            .environmentObject(BodyWeightViewModel(mockEntries: mockBodyWeightEntries))
            .environmentObject(makeMockProgressPhotosVM())
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
