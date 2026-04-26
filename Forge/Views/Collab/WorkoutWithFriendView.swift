import SwiftUI
import UIKit

struct WorkoutWithFriendView: View {
    /// Non-nil when presented over an in-progress solo workout. In that
    /// mode Copy/Share use `startSharedSessionForActiveWorkout(plan:)` so
    /// the joiner is auto-routed back into the active workout (Stage 7b'),
    /// and the view dismisses itself instead of pushing `ConnectingView` —
    /// the host stays inside `WorkoutInProgressView` and `CollabStatusBanner`
    /// handles the `.waitingForPeer` UI from there.
    var activeWorkoutPlan: WorkoutPlan? = nil

    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var connectingActive = false
    /// Drives both the iOS share sheet and the workout-mode profile prompt
    /// from a single `.sheet(item:)` modifier. Two separate `.sheet`
    /// modifiers on the same view silently conflict in SwiftUI (only the
    /// first attaches), so the prompt and the share sheet are switched on
    /// case below.
    @State private var activeSheet: ActiveSheet?
    /// Tracks which gradient rectangles have run their on-appear stagger
    /// animation. Indices 0…5 cascade top-to-bottom inside the collab
    /// preview graphic; each rectangle reads `appearedIndices.contains`
    /// to drive its own opacity + offset.
    @State private var appearedIndices: Swift.Set<Int> = []
    /// Parallel cascade for the three instruction rows above the graphic.
    /// Indices 0…2 fire alongside `appearedIndices` 0…2 so the two
    /// cascades visually share the same wave-front.
    @State private var instructionAppearedIndices: Swift.Set<Int> = []
    /// Avatar glide state. Each flip triggers a 2s easeInOut .offset(y:)
    /// shift of 80pt (one set + one rest row) — moving the avatar one
    /// "set row" down. Sequence (relative to view appear):
    ///   t = 2s → avatar 2 slides set 2 → set 3.
    ///   t = 6s → avatar 1 slides set 1 → set 2 (avatar 2 already gone).
    @State private var avatar1Glided = false
    @State private var avatar2Glided = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

//            Image(systemName: "person.2.fill")
//                .font(.system(size: 50))
//                .foregroundColor(settings.fgColor)

            Spacer().frame(height: 16)

            Text("Workout with a Friend")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)

            Spacer().frame(height: 40)

            instructionList
                .padding(.horizontal, 32)

            Spacer().frame(height: 28)

            collabPreviewGraphic
                .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    Button {
                        generateAndCopy()
                    } label: {
                        Label("Copy Link", systemImage: "doc.on.doc.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(GlobalSettings.shared.bgColor)
                    .foregroundColor(settings.fgColor)
                    .cornerRadius(12)

                    Button {
                        generateAndShare()
                    } label: {
                        Label("Share Link", systemImage: "square.and.arrow.up.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .background(GlobalSettings.shared.bgColor)
                    .foregroundColor(settings.fgColor)
                    .cornerRadius(12)
                }

                // Divider + secondary instruction only render on Air-class
                // and larger (≥414pt). On SE / 17 / 17 Pro the screen feels
                // too cramped with these visible, so we hide them.
                if UIScreen.main.bounds.width >= 414 {
                    Rectangle()
                        .fill(GlobalSettings.shared.buttonCircleBgColor)
                        .frame(width: 30, height: 1)
                        .padding(.vertical, 6)

                    Text("or ask a friend to share their link with you")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .profilePrompt:
                JoinSessionView(onSoloProfileSaved: handleProfilePromptSave)
                    .environmentObject(sessionClient)
                    .environmentObject(settings)
                    .environment(\.colorScheme, .dark)
            case .share(let wrapper):
                ShareSheet(activityItems: [wrapper.url])
            }
        }
        .onChange(of: activeSheet) { oldValue, newValue in
            // Workout-mode dismissal: once the user finishes (or cancels)
            // the iOS share sheet, return to the in-progress workout.
            // Pattern-match so we ONLY dismiss on a `.share → nil`
            // transition; `.profilePrompt → nil` means the user backed out
            // of the prompt without saving (they're still on the explainer
            // and can tap Copy/Share again), and `.profilePrompt → .share`
            // is the intentional swap during the auto-resume flow.
            guard activeWorkoutPlan != nil else { return }
            if case .share = oldValue, newValue == nil {
                dismiss()
            }
        }
        .navigationDestination(isPresented: $connectingActive) {
            ConnectingView()
                .environmentObject(sessionClient)
                .environmentObject(settings)
        }
    }

    /// Three-step instruction list: each row is an icon stacked above its
    /// caption, all in a uniform grey so the FG-color title and buttons
    /// remain the visual anchors.
    private var instructionList: some View {
        VStack(spacing: 28) {
            instructionRow(
                icon: "square.and.arrow.up.fill",
                text: "Share invite link with a friend",
                staggerIndex: 0
            )
            instructionRow(
                icon: "bubble.left.and.text.bubble.right.fill",
                text: "Choose a workout plan together",
                staggerIndex: 1
            )
            instructionRow(
                icon: "person.2.fill",
                text: "Workout with each other",
                staggerIndex: 2
            )
        }
    }

    private func instructionRow(
        icon: String,
        text: String,
        staggerIndex: Int
    ) -> some View {
        let isAppeared = instructionAppearedIndices.contains(staggerIndex)
        return VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GlobalSettings.shared.editorDarkGray)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(GlobalSettings.shared.editorDarkGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .opacity(isAppeared ? 1 : 0)
        .offset(x: isAppeared ? 0 : 24)
    }

    // MARK: - Collab preview graphic
    //
    // Decorative visualization of an active joint workout: an avatar gutter
    // on the left with two placeholder avatars pointing at specific rows,
    // beside an exercise card that mimics the joint-mode card layout (two
    // columns of completion circles per row). All text content is replaced
    // with horizontal-gradient rounded rectangles so the graphic reads as
    // a "demo" rather than as live data.
    //
    // The gutter and card use matching fixed row heights (26pt) so the
    // avatar slot for set 1 lines up with the first set row in the card,
    // and similarly for set 3. The 34pt top spacer in the gutter accounts
    // for the card's 12pt top padding plus the exercise-name rectangle
    // and its bottom gap.

    private var collabPreviewGraphic: some View {
        HStack(alignment: .top, spacing: 6) {
            graphicGutter
            graphicCard
        }
        .frame(maxWidth: .infinity)
        .task {
            // Let the NavigationStack push transition + initial layout
            // settle before the first stagger fires. Without this, the
            // value-scoped .animation(_:value:) modifier could capture
            // layout-in-flux during the push and interpolate everything's
            // y-position, making the rectangles appear to "float down"
            // from the top of the card instead of slide in from the right.
            // Canvas previews have no push transition, so the bug only
            // surfaces on device.
            //
            // Driving each rectangle with its own withAnimation scope
            // (instead of a single .animation modifier covering the chain)
            // limits the animatable scope to the specific opacity + x-
            // offset change at trigger time — no implicit layout capture.
            try? await Task.sleep(for: .milliseconds(80))
            for index in 0..<6 {
                withAnimation(.easeOut(duration: 0.7)) {
                    _ = appearedIndices.insert(index)
                    // Instructions cascade has 3 rows; fire each at the
                    // matching tick of the rectangle cascade so the two
                    // wave-fronts run in lockstep parallel.
                    if index < 3 {
                        _ = instructionAppearedIndices.insert(index)
                    }
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
        .task {
            // Avatar glide timeline — independent of the cascade above.
            // Both .task blocks fire on view appear; this one sleeps long
            // enough to start the glides AFTER the cascade has settled.
            //   t = 2s  → avatar 2 slides set 2 → set 3 (2s easeInOut)
            //   t = 6s  → avatar 1 slides set 1 → set 2 (2s easeInOut)
            //             (4s after avatar 2's glide started)
            // Tighter cubic-Bezier S-curve than the stock .easeInOut
            // (0.42, 0, 0.58, 1). Control points pushed outward give a
            // slower ramp up + ramp down with a faster peak velocity in
            // the middle of the glide.
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 2)) {
                avatar2Glided = true
            }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 2)) {
                avatar1Glided = true
            }
        }
    }

    private var graphicGutter: some View {
        VStack(spacing: 0) {
            // Vertical offset matching card top padding (16) + exercise
            // name placeholder height (22) + bottom gap (12) = 50.
            Color.clear.frame(height: 50)
            // Avatar 1 lives in slot 1 (set 1) layout-wise; .offset(y:)
            // visually slides it down 80pt (one set + one rest row) into
            // slot 3 (set 2) when avatar1Glided flips.
            avatarSlot(imageName: "collabAvatar1")
                .offset(y: avatar1Glided ? 80 : 0)
            avatarSlot(imageName: nil)                 // rest 1
            // Avatar 2 lives in slot 3 (set 2) layout-wise; the same 80pt
            // offset slides it down into slot 5 (set 3).
            avatarSlot(imageName: "collabAvatar2")
                .offset(y: avatar2Glided ? 80 : 0)
            avatarSlot(imageName: nil)                 // rest 2
            avatarSlot(imageName: nil)                 // set 3 (vacant until avatar 2 glides into it)
            Spacer(minLength: 0)
        }
        .frame(width: 60)
    }

    private var graphicCard: some View {
        // Indexes 0…5 cascade top-to-bottom for the on-appear fade-in
        // animation in `flexiblePlaceholder`.
        VStack(alignment: .leading, spacing: 0) {
            flexiblePlaceholder(
                height: 22,
                leftColor: Color.gray,
                rightColor: .clear,
                staggerIndex: 0
            )
            .padding(.bottom, 12)

            graphicSetRow(staggerIndex: 1).frame(height: 40)
            graphicRestRow(staggerIndex: 2).frame(height: 40)
            graphicSetRow(staggerIndex: 3).frame(height: 40)
            graphicRestRow(staggerIndex: 4).frame(height: 40)
            graphicSetRow(staggerIndex: 5).frame(height: 40)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Card bg fades out left → right so the right edge of the panel
        // dissolves into the screen background, mirroring the grey-to-clear
        // gradient pattern used by the rectangles inside.
        .background(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: GlobalSettings.shared.bgColor, location: 0),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
    }

    /// Renders an avatar (bundled portrait + right-arrow) when `imageName`
    /// is non-nil; otherwise an empty 40pt slot that preserves the
    /// gutter's row-by-row alignment with the card.
    private func avatarSlot(imageName: String?) -> some View {
        Group {
            if let imageName {
                HStack(spacing: 5) {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                }
            } else {
                Color.clear
            }
        }
        .frame(height: 40)
    }

    private func placeholderRect(
        width: CGFloat,
        height: CGFloat,
        leftColor: Color,
        rightColor: Color
    ) -> some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: leftColor, location: 0),
                .init(color: rightColor, location: 1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 5))
    }

    /// Width-flexible variant — fills the available horizontal space inside
    /// its parent (used for placeholders that should stretch to the right
    /// edge of the exercise card).
    ///
    /// `staggerIndex` (0…5) maps the rectangle to its slot in the
    /// `appearedIndices` set. The collabPreviewGraphic's .task body flips
    /// each index in turn with its own withAnimation block. Top-to-bottom
    /// indexing — 0 = exercise name, 5 = bottom-most set bar — so the
    /// cascade flows downward.
    private func flexiblePlaceholder(
        height: CGFloat,
        leftColor: Color,
        rightColor: Color,
        staggerIndex: Int
    ) -> some View {
        let isAppeared = appearedIndices.contains(staggerIndex)
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: leftColor, location: 0),
                .init(color: rightColor, location: 1),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 5))
        .opacity(isAppeared ? 1 : 0)
        .offset(x: isAppeared ? 0 : 24)
    }

    private func graphicSetRow(staggerIndex: Int) -> some View {
        HStack(spacing: 0) {
            Circle()
                .stroke(Color.gray.opacity(0.6), lineWidth: 1.8)
                .frame(width: 22, height: 22)
                .padding(.trailing, 9)
            Circle()
                .stroke(settings.fgColor.opacity(0.6), lineWidth: 1.8)
                .frame(width: 22, height: 22)
                .padding(.trailing, 14)
            // Set + weight x reps placeholder — fg-tinted so it reads as
            // the "active" content row vs. the grey name/rest placeholders.
            // Height matches the completion circles' diameter so the row
            // reads as a single horizontal block. Stretches to the card's
            // right edge.
            flexiblePlaceholder(
                height: 22,
                leftColor: settings.fgColor.opacity(0.3),
                rightColor: .clear,
                staggerIndex: staggerIndex
            )
        }
    }

    private func graphicRestRow(staggerIndex: Int) -> some View {
        HStack(spacing: 0) {
            graphicConnector
                .padding(.trailing, 9)
            graphicConnector
                .padding(.trailing, 14)
            flexiblePlaceholder(
                height: 14,
                leftColor: Color.gray,
                rightColor: .clear,
                staggerIndex: staggerIndex
            )
        }
    }

    private var graphicConnector: some View {
        VStack(spacing: 4) {
            Rectangle().frame(width: 1.5, height: 11)
            Circle().frame(width: 6, height: 6)
            Rectangle().frame(width: 1.5, height: 11)
        }
        .foregroundColor(GlobalSettings.shared.darkGray)
        .frame(width: 22)
    }

    private func generateAndCopy() {
        if requiresProfilePrompt(for: .copy) { return }
        provisionSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        UIPasteboard.general.string = url.absoluteString
        if activeWorkoutPlan != nil {
            dismiss()
        } else {
            connectingActive = true
        }
    }

    private func generateAndShare() {
        if requiresProfilePrompt(for: .share) { return }
        provisionSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        activeSheet = .share(ShareableURL(url: url))
        // Workout mode defers dismissal until the share sheet itself
        // closes — see `.onChange(of: activeSheet)` in body.
        if activeWorkoutPlan == nil {
            connectingActive = true
        }
    }

    /// Workout-mode gate: if the host hasn't set a profile yet, surface
    /// `JoinSessionView` (in solo-profile-entry mode) over the explainer
    /// to collect name + photo before doing the actual copy/share.
    /// Returns true when the prompt was presented (caller bails; the
    /// view's `onSoloProfileSaved` closure re-fires the action). History
    /// mode returns false — its profile collection happens later in the
    /// pairing flow's own JoinSessionView.
    private func requiresProfilePrompt(for action: PendingAction) -> Bool {
        guard activeWorkoutPlan != nil, sessionClient.myProfile == nil else {
            return false
        }
        activeSheet = .profilePrompt(action: action)
        return true
    }

    /// Picks the right session-creation API for the current entry point.
    /// Workout mode also registers `workoutInProgress` server-side so any
    /// joiner is routed straight into `WorkoutInProgressView` via the
    /// Stage 7b' welcome path.
    private func provisionSession() {
        if let plan = activeWorkoutPlan {
            sessionClient.startSharedSessionForActiveWorkout(plan: plan)
        } else {
            sessionClient.createSession()
        }
    }

    // MARK: - Workout-mode profile prompt

    /// Closure passed into `JoinSessionView`'s solo-profile-entry mode.
    /// Fires AFTER the view has called `sessionClient.submitProfile`, so
    /// `myProfile` is set by the time we re-enter `generateAndCopy/Share`
    /// and the profile gate skips. We hop one runloop tick before the
    /// re-fire so UIKit can finish tearing down the prompt sheet's
    /// PresentationController; without it, the resumed action's
    /// sheet-present (Share path) or `dismiss()` (Copy path) collides
    /// with the in-flight teardown and one of them gets dropped.
    private func handleProfilePromptSave() {
        let pending: PendingAction? = {
            if case .profilePrompt(let action) = activeSheet { return action }
            return nil
        }()
        activeSheet = nil
        DispatchQueue.main.async {
            switch pending {
            case .copy: generateAndCopy()
            case .share: generateAndShare()
            case .none: break
            }
        }
    }

    // MARK: - Sheet enum

    private enum PendingAction: String, Equatable {
        case copy
        case share
    }

    private enum ActiveSheet: Identifiable, Equatable {
        case profilePrompt(action: PendingAction)
        case share(ShareableURL)

        var id: String {
            switch self {
            case .profilePrompt(let action): return "profilePrompt-\(action.rawValue)"
            case .share(let wrapper): return "share-\(wrapper.id.uuidString)"
            }
        }

        // ShareableURL isn't Equatable, so auto-synthesis won't compile.
        // Compare via the case-identifying string id — sufficient for
        // SwiftUI's diffing and for our `.onChange` pattern-match.
        static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
            lhs.id == rhs.id
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutWithFriendView()
            .environmentObject(SessionClient())
            .environmentObject(GlobalSettings.shared)
    }
    .preferredColorScheme(.dark)
}
