import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var planEditorIsPresented = false
    @State private var showEndSessionConfirm = false
    @State private var currentPlanId: UUID?
    @State private var suggestedPaneScale: CGFloat = 1.0

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    var body: some View {
        VStack(spacing: 16) {
            gradientPanel

            carouselHeaderRow
                .padding(.horizontal, 20)

            planCarousel
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $planEditorIsPresented) {
            PlanEditorView()
                .environment(\.colorScheme, .dark)
        }
        .onChange(of: planEditorIsPresented) { _, isPresented in
            guard !isPresented else { return }
            // Editor just dismissed — reset read-only flag and re-broadcast
            // the current suggestion if it matches a plan that may have been
            // edited. Idempotent: if nothing changed, the peer just re-receives
            // the same PlanSnapshot.
            planViewModel.activePlanIsReadOnly = false
            if let suggested = sessionClient.suggestedPlan,
               let latest = planViewModel.workoutPlans.first(where: { $0.id == suggested.id }) {
                sessionClient.suggestPlan(from: latest)
            }
        }
        .alert("End Session?", isPresented: $showEndSessionConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { sessionClient.disconnect() }
        }
        .onChange(of: sessionClient.suggestedPlan?.id) { _, newId in
            guard newId != nil else { return }   // no bounce when pane goes empty
            bounceSuggestedPane()
        }
    }

    private func openPreview(ownPlan: WorkoutPlan) {
        guard let idx = planViewModel.workoutPlans.firstIndex(where: { $0.id == ownPlan.id }) else { return }
        planViewModel.activePlan = ownPlan
        planViewModel.activePlanIndex = idx
        planViewModel.activePlanMode = .preview
        planViewModel.activePlanIsReadOnly = false
        planEditorIsPresented = true
    }

    private func openPreview(snapshot: PlanSnapshot) {
        // Always open read-only from the Suggested pane. The pane renders a
        // frozen moment-in-time PlanSnapshot from the wire; matching it to
        // a local plan by id (or even id+name) isn't reliable — two phones
        // can share a plan-id via an earlier AirDrop of a .forgeplan, or
        // the local copy may have diverged from what's actually suggested.
        // If the user wants to edit their own plan, they tap PREVIEW on
        // the carousel card instead, which goes through openPreview(ownPlan:)
        // and opens editable mode unconditionally.
        planViewModel.activePlan = snapshot.toWorkoutPlan()
        planViewModel.activePlanIndex = -1      // sentinel: not in workoutPlans
        planViewModel.activePlanMode = .preview
        planViewModel.activePlanIsReadOnly = true
        planEditorIsPresented = true
    }

    private var gradientPanel: some View {
        VStack(spacing: 16) {
            topRow
                .padding(.horizontal, 12)
                .padding(.top, 12)

            avatarRow
                .padding(.horizontal, 12)

            chatInterface
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    .black,
                    Color(red: 0x15 / 255.0, green: 0x15 / 255.0, blue: 0x15 / 255.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var topRow: some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                showEndSessionConfirm = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(settings.fgColor)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            suggestedWorkoutPane
                .scaleEffect(suggestedPaneScale)
        }
    }

    private func bounceSuggestedPane() {
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            suggestedPaneScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                suggestedPaneScale = 1.0
            }
        }
    }

    @ViewBuilder
    private var suggestedWorkoutPane: some View {
        if let suggested = sessionClient.suggestedPlan {
            HStack(alignment: .top, spacing: 12) {
                suggestedPaneInfo(plan: suggested)
                Spacer(minLength: 0)
                suggestedPaneButtonStack(plan: suggested)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(Color(white: 0.1))
            .cornerRadius(8)
        } else {
            Text("No plan suggested yet")
                .font(.subheadline)
                .foregroundColor(Color(white: 0.2))
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 88)
                .background(Color(white: 0.05))
                .cornerRadius(8)
        }
    }

    private func suggestedPaneInfo(plan: PlanSnapshot) -> some View {
        PlanInfoBlock(
            name: plan.name,
            exerciseCount: plan.exercises.count,
            durationMinutes: plan.durationMinutes
        )
    }

    private func suggestedPaneButtonStack(plan: PlanSnapshot) -> some View {
        VStack(spacing: 6) {
            Text("SUGGESTED")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .frame(width: 80)
                .padding(.vertical, 8)

            Spacer()
                .frame(width: 0, height: 0)

            Button {
                openPreview(snapshot: plan)
            } label: {
                Text("PREVIEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .frame(width: 80)
                    .padding(.vertical, 8)
            }
            .background(Color(white: 0.2))
            .foregroundColor(.white)
            .cornerRadius(5)
            .buttonStyle(.borderless)
        }
    }

    private var avatarRow: some View {
        HStack(spacing: 0) {
            Spacer()

            readyUpButton
                .padding(.trailing, 7)

            avatar(
                data: sessionClient.myProfile?.photoData,
                fallbackInitial: initial(from: sessionClient.myProfile?.name ?? "?"),
                diameter: 44
            )

            connector
                .padding(.horizontal, 8)

            avatar(
                data: peerProfile?.photoData,
                fallbackInitial: initial(from: peerProfile?.name ?? "?"),
                diameter: 44
            )

            readyUpButton
                .padding(.leading, 7)

            Spacer()
        }
    }

    private var readyUpButton: some View {
        Button {
            // Stage 3: dummy — wired to the ready-flag protocol in Stage 5
        } label: {
            Text("READY UP")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
//                .background(settings.fgColor)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .shadow(
            color: settings.fgColor.opacity(0.4), // color + transparency
            radius: 15,                  // blur
            x: 0,                        // horizontal offset
            y: 0                         // vertical offset
        )
    }

    private var connector: some View {
        HStack(spacing: 0) {
            Circle().frame(width: 6, height: 6)
            Rectangle().frame(width: 28, height: 1)
            Circle().frame(width: 6, height: 6)
        }
        .foregroundColor(GlobalSettings.shared.darkGray)
    }

    private var chatInterface: some View {
        VStack {
            Text("Chat coming in Stage 4")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var carouselHeaderRow: some View {
        HStack {
            Text("Suggest Workout")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
            dotIndicators
        }
    }

    @ViewBuilder
    private var planCarousel: some View {
        if planViewModel.workoutPlans.isEmpty {
            Text("No plans. Create one in the Select Plan screen first.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(planViewModel.workoutPlans) { plan in
                        PlanCarouselCard(
                            plan: plan,
                            onSuggest: { sessionClient.suggestPlan(from: plan) },
                            onPreview: { openPreview(ownPlan: plan) }
                        )
                        .id(plan.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentPlanId, anchor: .leading)
            .frame(height: 88)
        }
    }

    @ViewBuilder
    private var dotIndicators: some View {
        if planViewModel.workoutPlans.count > 1 {
            HStack(spacing: 5) {
                ForEach(planViewModel.workoutPlans) { plan in
                    Capsule()
                        .fill(isActivePlan(plan) ? settings.fgColor : Color(white: 0.25))
                        .frame(width: 14, height: 3)
                }
            }
        }
    }

    private func isActivePlan(_ plan: WorkoutPlan) -> Bool {
        if let current = currentPlanId {
            return current == plan.id
        }
        return plan.id == planViewModel.workoutPlans.first?.id
    }
}

struct PlanCarouselCard: View {
    let plan: WorkoutPlan
    let onSuggest: () -> Void
    let onPreview: () -> Void

    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var planViewModel: PlanViewModel

    private var isCurrentlySuggested: Bool {
        sessionClient.suggestedPlan?.id == plan.id
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            planInfo
            Spacer(minLength: 0)
            buttonStack
        }
        .padding(12)
        .frame(width: 280, height: 88)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }

    private var planInfo: some View {
        PlanInfoBlock(
            name: plan.name,
            exerciseCount: plan.exercises.count,
            durationMinutes: planViewModel.calculateWorkoutDuration(for: plan)
        )
    }

    private var buttonStack: some View {
        VStack(spacing: 6) {
            Button(action: onSuggest) {
                Group {
                    if isCurrentlySuggested {
                        Image(systemName: "checkmark")
                    } else {
                        Text("SUGGEST")
                    }
                }
                .font(.caption2)
                .fontWeight(.bold)
                .frame(width: 80, height: 30)
            }
            .background(settings.fgColor)
            .foregroundColor(.black)
            .cornerRadius(5)
            .buttonStyle(.borderless)
            .shadow(
                color: settings.fgColor.opacity(0.5), // color + transparency
                radius: 10,                  // blur
                x: 0,                        // horizontal offset
                y: 0                         // vertical offset
            )
            
            Spacer()
                .frame(width: 0, height: 0)
            
            Button(action: onPreview) {
                Text("PREVIEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .frame(width: 80)
                    .padding(.vertical, 8)
            }
            .background(Color(white: 0.2))
            .foregroundColor(.white)
            .cornerRadius(5)
            .buttonStyle(.borderless)
        }
    }
}

struct PlanInfoBlock: View {
    let name: String
    let exerciseCount: Int
    let durationMinutes: Int

    @EnvironmentObject var settings: GlobalSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .resizable()
                    .frame(width: 18, height: 13)
                Text("\(exerciseCount) \(exerciseCount == 1 ? "Exercise" : "Exercises")")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .resizable()
                    .frame(width: 13, height: 13)
                Text("\(durationMinutes) min")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))
        }
    }
}

// MARK: - Previews

@MainActor
private func previewSessionClient(withSuggestion: Bool) -> SessionClient {
    let client = SessionClient()
    let peerId = UUID()
    client.myId = UUID()
    client.peerIds = [peerId]
    client.myProfile = Profile(name: "Ryan", photoData: nil)
    client.peerProfiles = [peerId: Profile(name: "Alex", photoData: nil)]
    client.hasSubmittedProfile = true
    client.state = .connected
    if withSuggestion, let firstPlan = mockWorkoutPlans.first {
        client.suggestedPlan = PlanSnapshot(from: firstPlan)
    }
    return client
}

#Preview("No Suggestion") {
    NavigationStack {
        PlanSuggestionView()
            .environmentObject(previewSessionClient(withSuggestion: false))
            .environmentObject(GlobalSettings.shared)
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
    }
    .preferredColorScheme(.dark)
}

#Preview("Plan Suggested") {
    NavigationStack {
        PlanSuggestionView()
            .environmentObject(previewSessionClient(withSuggestion: true))
            .environmentObject(GlobalSettings.shared)
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
    }
    .preferredColorScheme(.dark)
}
