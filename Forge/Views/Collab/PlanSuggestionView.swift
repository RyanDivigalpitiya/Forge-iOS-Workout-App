import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var previewPlan: PlanSnapshot?
    @State private var showEndSessionConfirm = false

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
        .sheet(item: $previewPlan) { plan in
            PlanPreviewSheet(plan: plan)
        }
        .alert("End Session?", isPresented: $showEndSessionConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End", role: .destructive) { sessionClient.disconnect() }
        }
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
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 88)
                .background(Color(white: 0.08))
                .cornerRadius(8)
        }
    }

    private func suggestedPaneInfo(plan: PlanSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .resizable()
                    .frame(width: 18, height: 13)
                    .opacity(0.4)
                Text("\(plan.exercises.count) \(plan.exercises.count == 1 ? "Exercise" : "Exercises")")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .resizable()
                    .frame(width: 13, height: 13)
                Text("\(plan.durationMinutes) min")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))
        }
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
                previewPlan = plan
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
                .padding(.trailing, 6)

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
                .padding(.leading, 6)

            Spacer()
        }
    }

    private var readyUpButton: some View {
        Button {
            // Stage 3: dummy — wired to the ready-flag protocol in Stage 5
        } label: {
            Text("READY UP")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(settings.fgColor)
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
            Text("YOUR PLANS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
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
                HStack(spacing: 14) {
                    ForEach(planViewModel.workoutPlans) { plan in
                        PlanCarouselCard(
                            plan: plan,
                            onSuggest: { sessionClient.suggestPlan(from: plan) },
                            onPreview: { previewPlan = PlanSnapshot(from: plan) }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text(plan.name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .resizable()
                    .frame(width: 18, height: 13)
//                    .opacity(0.4)
                Text("\(plan.exercises.count) \(plan.exercises.count == 1 ? "Exercise" : "Exercises")")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .resizable()
                    .frame(width: 13, height: 13)
//                    .padding(.leading, 2)
//                    .opacity(0.4)
                Text("\(planViewModel.calculateWorkoutDuration(for: plan)) min")
//                    .padding(.leading, 3)
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.gray.opacity(0.5))
        }
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
                .frame(width: 80)
                .padding(.vertical, 8)
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

struct PlanPreviewSheet: View {
    let plan: PlanSnapshot
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(plan.exercises) { exercise in
                    Section(exercise.name) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { idx, set in
                            HStack {
                                Text("Set \(idx + 1)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(setDescription(set))
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func setDescription(_ set: SetSnapshot) -> String {
        let weight: String = set.weight == floor(set.weight)
            ? String(Int(set.weight))
            : String(format: "%.1f", set.weight)
        if set.tillFailure {
            return "\(weight) lb × fail"
        } else {
            return "\(weight) lb × \(set.reps) reps"
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

#Preview("Plan Suggested") {
    NavigationStack {
        PlanSuggestionView()
            .environmentObject(previewSessionClient(withSuggestion: true))
            .environmentObject(GlobalSettings.shared)
            .environmentObject(PlanViewModel(mockPlans: mockWorkoutPlans))
    }
    .preferredColorScheme(.dark)
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
