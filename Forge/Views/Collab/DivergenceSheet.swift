import SwiftUI

/// Driven by `PlanSuggestionView`'s `.sheet(item:)` when the match-and-route
/// logic returns `.lineageMatch` — i.e. B and A both have plans descended
/// from the same source (`lineageId` matches) but B's structure has drifted
/// (`fingerprint` differs). Carries both ends of the divergence so the sheet
/// body can render a side-by-side count.
struct DivergenceContext: Identifiable {
    let id = UUID()
    let snapshot: PlanSnapshot
    let localPlan: WorkoutPlan
}

/// Presents the user with two recovery options for a diverged plan.
///
/// Notably, **there is no "use my version" option**. Joint-mode set sync
/// is positional — both peers' plans must share structure for set
/// completions to address the right rows on both phones. Offering "use
/// my version" would silently disable peer set-completion sync (worst-of-
/// both-worlds: feels broken without explanation). Instead, the prompt
/// honestly surfaces the constraint and offers two ways to recover to a
/// shared structure: ephemeral (this session only) or persistent (save
/// the friend's version as a new plan).
struct DivergenceSheet: View {
    let context: DivergenceContext
    let onUseFriendsThisSession: () -> Void
    let onSaveAndUseFriends: () -> Void

    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(settings.fgColor)
                Text("Plan has diverged")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }

            Text(bodyText)
                .font(.callout)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button(action: onUseFriendsThisSession) {
                    Text("Use friend's version (this session)")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: settings.cornerRadiusMedium)
                                .fill(settings.fgColor)
                        )
                        .foregroundColor(.white)
                }

                Button(action: onSaveAndUseFriends) {
                    Text("Use friend's version (save updated copy)")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: settings.cornerRadiusMedium)
                                .stroke(settings.fgColor, lineWidth: 1.5)
                        )
                        .foregroundColor(settings.fgColor)
                }

                Button("Cancel") { dismiss() }
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .presentationDetents([.medium])
        .presentationBackground(Color.black)
    }

    private var bodyText: String {
        let mine = context.localPlan.exercises.count
        let theirs = context.snapshot.exercises.count
        return """
        Your version of "\(context.snapshot.name)" has \(mine) \(mine == 1 ? "exercise" : "exercises"). Your friend's has \(theirs).

        Working out together requires a shared plan structure so set completions sync correctly across both phones.
        """
    }
}
