import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var previewPlan: PlanSnapshot?

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    var body: some View {
        VStack(spacing: 0) {
            suggestedWorkoutPane
                .padding(.horizontal, 20)
                .padding(.top, 16)

            avatarRow
                .padding(.horizontal, 20)
                .padding(.top, 24)

            Spacer(minLength: 16)

            Text("Chat coming in Stage 4")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))

            Spacer(minLength: 16)

            planCarousel

            Button {
                sessionClient.disconnect()
            } label: {
                Text("End Session")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
            }
            .foregroundColor(.white)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(12)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarBackButtonHidden(true)
        .sheet(item: $previewPlan) { plan in
            PlanPreviewSheet(plan: plan)
        }
    }

    private var suggestedWorkoutPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUGGESTED WORKOUT")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)

            if let suggested = sessionClient.suggestedPlan {
                Button {
                    previewPlan = suggested
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggested.name)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(settings.fgColor)
                            Text("\(suggested.exercises.count) exercise\(suggested.exercises.count == 1 ? "" : "s") · tap to preview")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(16)
                    .background(Color(white: 0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            } else {
                Text("No plan suggested yet")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(white: 0.08))
                    .cornerRadius(12)
            }
        }
    }

    private var avatarRow: some View {
        HStack {
            HStack(spacing: 10) {
                avatar(
                    data: sessionClient.myProfile?.photoData,
                    fallbackInitial: initial(from: sessionClient.myProfile?.name ?? "?"),
                    diameter: 44
                )
                Text(sessionClient.myProfile?.name ?? "You")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 10) {
                Text(peerProfile?.name ?? "Friend")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                avatar(
                    data: peerProfile?.photoData,
                    fallbackInitial: initial(from: peerProfile?.name ?? "?"),
                    diameter: 44
                )
            }
        }
    }

    private var planCarousel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR PLANS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .padding(.horizontal, 20)

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
}

struct PlanCarouselCard: View {
    let plan: WorkoutPlan
    let onSuggest: () -> Void
    let onPreview: () -> Void

    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var sessionClient: SessionClient

    private var isCurrentlySuggested: Bool {
        sessionClient.suggestedPlan?.id == plan.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(plan.name)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(height: 44, alignment: .topLeading)

            Text("\(plan.exercises.count) exercise\(plan.exercises.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()

            VStack(spacing: 8) {
                Button(action: onSuggest) {
                    Text(isCurrentlySuggested ? "SUGGESTED" : "SUGGEST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .background(isCurrentlySuggested ? Color(white: 0.25) : settings.fgColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(.borderless)

                Button(action: onPreview) {
                    Text("PREVIEW")
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .background(Color(white: 0.2))
                .foregroundColor(.white)
                .cornerRadius(8)
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 180, height: 200)
        .background(Color(white: 0.1))
        .cornerRadius(16)
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
