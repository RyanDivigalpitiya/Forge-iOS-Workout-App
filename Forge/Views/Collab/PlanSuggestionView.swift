import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var activeCover: ActiveCover?
    @State private var showEndSessionConfirm = false
    @State private var currentPlanId: UUID?
    @State private var suggestedPaneScale: CGFloat = 1.0
    /// Drives the divergence prompt sheet (Phase C). Non-nil whenever the
    /// match-and-route logic detects a `lineageMatch` (lineageId hits but
    /// fingerprints differ) — i.e. B and A both have plans descended from
    /// the same source but B's structure has drifted. Cleared on user
    /// action or sheet dismiss.
    @State private var divergenceContext: DivergenceContext?
    /// Tracks the iOS keyboard visibility (NotificationCenter-driven) so the
    /// "DISMISS" label in the indicator row can grey out when there's nothing
    /// to dismiss.
    @State private var keyboardVisible: Bool = false

    // Drives the single .fullScreenCover. SwiftUI silently ignores the
    // second of two .fullScreenCover(isPresented:) modifiers attached to
    // the same view, so we funnel both the plan-editor preview and the
    // workout-in-progress hand-off through one item-based cover.
    private enum ActiveCover: Identifiable {
        case planEditor
        case workoutInProgress
        var id: Self { self }
    }

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    /// Compact layout for screens ≤ 380pt wide (iPhone SE 3rd gen, 12/13
    /// mini). At standard sizing the avatar row's intrinsic width
    /// approaches the SE's available content area, so READY UP / NOT
    /// READY wraps to two lines. Compact mode shaves ~40pt across
    /// avatars, button paddings, and the connector.
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactWidth: Bool { screenWidth <= 380 }
    private var avatarDiameter: CGFloat { isCompactWidth ? 36 : 44 }
    private var connectorRectWidth: CGFloat { isCompactWidth ? 18 : 28 }
    private var connectorCircleSize: CGFloat { isCompactWidth ? 5 : 6 }
    private var connectorHPadding: CGFloat { isCompactWidth ? 6 : 8 }
    private var readyButtonHPadding: CGFloat { isCompactWidth ? 7 : 10 }
    private var readyButtonVPadding: CGFloat { isCompactWidth ? 4 : 6 }
    private var readyButtonOuterPadding: CGFloat { isCompactWidth ? 4 : 7 }

    var body: some View {
        VStack(spacing: 16) {
            gradientPanel

            carouselHeaderRow
                // Horizontal inset matches gradientPanel's `.padding(.horizontal, 16)`
                // above so the suggested-plan card and the chat container line
                // up edge-to-edge.
                .padding(.horizontal, 16)

            planCarousel

            indicatorRow
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .overlay(alignment: .top) {
            CollabStatusBanner()
                .padding(.top, 8)
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: $activeCover) { cover in
            switch cover {
            case .planEditor:
                PlanEditorView()
                    .environment(\.colorScheme, .dark)
            case .workoutInProgress:
                WorkoutInProgressView()
                    .environment(\.colorScheme, .dark)
            }
        }
        .sheet(item: $divergenceContext) { ctx in
            DivergenceSheet(
                context: ctx,
                onUseFriendsThisSession: {
                    // Ephemeral: read-only snapshot path with sentinel
                    // index. B's library untouched. Set sync works because
                    // B is using A's structure for this session.
                    planViewModel.activePlan = ctx.snapshot.toWorkoutPlan()
                    planViewModel.activePlanIndex = -1
                    divergenceContext = nil
                    activeCover = .workoutInProgress
                },
                onSaveAndUseFriends: {
                    // Persistent: import as new plan (auto-suffixed name,
                    // friend's lineageId preserved); becomes active. Future
                    // collab sessions fingerprint-match the new copy. B may
                    // end up with two plans sharing lineageId — the original
                    // diverged one and the new copy — and can manually
                    // delete the old via SelectPlanView.
                    autoImportAndRoute(snapshot: ctx.snapshot)
                    divergenceContext = nil
                }
            )
            .environment(\.colorScheme, .dark)
        }
        .onChange(of: activeCover) { old, new in
            // Detect editor dismissal — reset read-only flag and re-broadcast
            // the current suggestion if it matches a plan that may have been
            // edited. Idempotent: if nothing changed, the peer just re-receives
            // the same PlanSnapshot.
            if old == .planEditor && new == nil {
                planViewModel.activePlanIsReadOnly = false
                if let suggested = sessionClient.suggestedPlan,
                   let latest = planViewModel.workoutPlans.first(where: { $0.id == suggested.id }) {
                    sessionClient.suggestPlan(from: latest)
                }
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
        .onChange(of: sessionClient.startWorkoutSignal) { _, newSignal in
            guard newSignal != nil else { return }
            resolveCoverState()
        }
        .onAppear {
            resolveCoverState()
        }
        .onChange(of: sessionClient.workoutInProgress?.id) { _, _ in
            // Welcome may arrive after this view is on screen.
            resolveCoverState()
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: UIResponder.keyboardWillShowNotification).map { _ in true }
                .merge(with: NotificationCenter.default
                    .publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false })
        ) { keyboardVisible = $0 }
    }

    /// Single source of truth for presenting the workout cover. Called from
    /// three triggers (view appear, workoutInProgress change, startWorkout
    /// signal). `workoutInProgress` takes precedence so a mid-workout rejoin
    /// routes into the partner's active plan rather than whatever the user
    /// last suggested — fixes the race where both setters could fire in the
    /// same frame with different PlanSnapshot sources.
    private func resolveCoverState() {
        guard activeCover != .workoutInProgress else { return }
        if let inProgress = sessionClient.workoutInProgress {
            routeIntoActiveWorkout(snapshot: inProgress)
        } else if sessionClient.startWorkoutSignal != nil,
                  let suggested = sessionClient.suggestedPlan {
            routeIntoActiveWorkout(snapshot: suggested)
        }
    }

    /// Phase C match-and-route. For every transition into the active
    /// workout cover (re-joiner welcome OR Ready), we run the snapshot
    /// through `findMatch` and pick one of three branches:
    /// - `fingerprintMatch`: silent reuse of B's local plan.
    /// - `lineageMatch`: surface the divergence sheet; defer cover
    ///   transition until the user picks an option.
    /// - `none`: auto-import the snapshot, set the freshly-imported
    ///   plan as active, and surface the post-workout toast on
    ///   `CompletedWorkoutsView` via `lastAutoImportedPlanName`.
    private func routeIntoActiveWorkout(snapshot: PlanSnapshot) {
        let match = planViewModel.findMatch(
            forFingerprint: snapshot.fingerprint,
            lineageId: snapshot.lineageId
        )
        switch match {
        case .fingerprintMatch(let local, let idx):
            planViewModel.activePlan = local
            planViewModel.activePlanIndex = idx
            activeCover = .workoutInProgress

        case .lineageMatch(let local, _):
            divergenceContext = DivergenceContext(
                snapshot: snapshot,
                localPlan: local
            )

        case .none:
            autoImportAndRoute(snapshot: snapshot)
        }
    }

    /// Imports the snapshot via existing `importPlan` machinery (which
    /// regenerates plan/exercise/set UUIDs, strips completion state, and
    /// auto-suffixes the name on collision; preserves `lineageId`). The
    /// imported plan lands at the end of `workoutPlans` and becomes the
    /// active plan with a valid index. This branch is the natural
    /// successor to the "stale activePlanIndex" overwrite bug — by
    /// always producing a real index, the destructive write at
    /// `WorkoutInProgressView.finishWorkout` becomes safe.
    private func autoImportAndRoute(snapshot: PlanSnapshot) {
        planViewModel.importPlan(snapshot.toWorkoutPlan())
        let importedIndex = planViewModel.workoutPlans.count - 1
        planViewModel.activePlan = planViewModel.workoutPlans[importedIndex]
        planViewModel.activePlanIndex = importedIndex
        planViewModel.lastAutoImportedPlanName = planViewModel.activePlan.name
        activeCover = .workoutInProgress
    }

    private func openPreview(ownPlan: WorkoutPlan) {
        guard let idx = planViewModel.workoutPlans.firstIndex(where: { $0.id == ownPlan.id }) else { return }
        planViewModel.activePlan = ownPlan
        planViewModel.activePlanIndex = idx
        planViewModel.activePlanMode = .preview
        planViewModel.activePlanIsReadOnly = false
        activeCover = .planEditor
    }

    private func openPreview(snapshot: PlanSnapshot) {
        // The suggested-header PREVIEW is strictly read-only on both
        // devices — editing the suggested plan is not a supported
        // operation through this surface (the suggester edits their plan
        // via the carousel's own PREVIEW, which is the only path that
        // re-broadcasts). Phase C still applies for *display*: if B has a
        // structurally-identical local plan, render that copy so B sees
        // their own weights/reps instead of the broadcast's. Index is the
        // -1 sentinel so the save path stays gated even if a future
        // refactor accidentally clears the read-only flag.
        if case .fingerprintMatch(let local, _) = planViewModel.findMatch(
            forFingerprint: snapshot.fingerprint,
            lineageId: snapshot.lineageId
        ) {
            planViewModel.activePlan = local
        } else {
            planViewModel.activePlan = snapshot.toWorkoutPlan()
        }
        planViewModel.activePlanIndex = -1      // sentinel: not in workoutPlans
        planViewModel.activePlanMode = .preview
        planViewModel.activePlanIsReadOnly = true
        activeCover = .planEditor
    }

    private var gradientPanel: some View {
        VStack(spacing: 16) {
            avatarRow
                .padding(.horizontal, 12)
                .padding(.top, 12)

            CollabChatPanel()
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
        .cornerRadius(settings.cornerRadiusLarge)
        .padding(.horizontal, 16)
        .padding(.top, 16)
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

    private var avatarRow: some View {
        // Friend on the left, user on the right — visually mirrors the chat
        // bubble alignment below (peer bubbles left-aligned, user bubbles
        // right-aligned).
        HStack(spacing: 0) {
            Spacer()

            readyUpButton(isSelf: false)
                .padding(.trailing, readyButtonOuterPadding)

            avatar(
                data: peerProfile?.photoData,
                fallbackInitial: initial(from: peerProfile?.name ?? "?"),
                diameter: avatarDiameter
            )

            connector
                .padding(.horizontal, connectorHPadding)

            avatar(
                data: sessionClient.myProfile?.photoData,
                fallbackInitial: initial(from: sessionClient.myProfile?.name ?? "?"),
                diameter: avatarDiameter
            )

            readyUpButton(isSelf: true)
                .padding(.leading, readyButtonOuterPadding)

            Spacer()
        }
    }

    private func readyUpButton(isSelf: Bool) -> some View {
        let peerIsReady = peerId.flatMap { sessionClient.peerReady[$0] } ?? false
        let isReady = isSelf ? sessionClient.myIsReady : peerIsReady
        let canInteract = isSelf && sessionClient.suggestedPlan != nil

        // "READY UP" is an action prompt — only meaningful for self.
        // For the friend, show "Not Ready" as a status descriptor (greyed
        // out) so it doesn't read like a tappable affordance.
        let label: String
        if isReady {
            label = "READY"
        } else if isSelf {
            label = "READY UP"
        } else {
            label = "NOT READY"
        }
        let labelColor: Color
        if isReady {
            labelColor = .black
        } else if isSelf {
            labelColor = settings.fgColor
        } else {
            // Friend's NOT READY status descriptor — lighter than system
            // .gray so it stays legible against the dark backdrop without
            // looking like a disabled control.
            labelColor = Color(white: 0.72)
        }

        return Button {
            if isSelf { sessionClient.toggleReady() }
        } label: {
            HStack(spacing: 4) {
                // Checkmark sits on the inward-facing side of each button so
                // it points toward the avatar it belongs to: right button
                // (self) has the icon on the left of READY, left button
                // (peer) has it on the right.
                if isReady && isSelf {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                if isReady && !isSelf {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(labelColor)
            .padding(.horizontal, readyButtonHPadding)
            .padding(.vertical, readyButtonVPadding)
            .background(isReady ? settings.fgColor : Color.clear)
            .cornerRadius(settings.cornerRadiusSmall)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
        // `.allowsHitTesting` instead of `.disabled` so the friend's chip
        // doesn't pick up SwiftUI's environmental disabled-dim — the
        // friend's READY state should render at the same intensity as
        // self's. Tap-suppression for friend taps is handled by the
        // `if isSelf` guard inside the button action.
        .allowsHitTesting(canInteract)
        // Only dim self's pre-suggestion not-ready state. Friend states
        // (ready or not) and self-ready stay full opacity; the friend's
        // not-ready labelColor does its own muting via a lighter grey.
        .opacity((isSelf && !isReady && !canInteract) ? 0.65 : 1.0)
        .shadow(
            color: settings.fgColor.opacity(isReady ? 0.5 : 0.4),
            radius: 15,
            x: 0,
            y: 0
        )
    }

    private var connector: some View {
        HStack(spacing: 0) {
            Circle().frame(width: connectorCircleSize, height: connectorCircleSize)
            Rectangle().frame(width: connectorRectWidth, height: 1)
            Circle().frame(width: connectorCircleSize, height: connectorCircleSize)
        }
        .foregroundColor(GlobalSettings.shared.darkGray)
    }

    private var carouselHeaderRow: some View {
        // Single .frame(maxWidth:) wrapper rather than an HStack+Spacer so
        // the populated card (which has its own .frame(maxWidth: .infinity))
        // actually fills the row — an HStack-with-Spacer ends up clipping
        // it to its intrinsic content width on some layout passes. Leading
        // alignment keeps the "Suggest Workout" placeholder text on the
        // left edge in the unpopulated case.
        suggestedHeaderCluster
            .scaleEffect(suggestedPaneScale)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var suggestedHeaderCluster: some View {
        if let suggested = sessionClient.suggestedPlan {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)

                    shimmeringSuggestedName(suggested.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 0)

                Button {
                    openPreview(snapshot: suggested)
                } label: {
                    Text("PREVIEW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .background(Color(white: 0.2))
                .foregroundColor(.white)
                .cornerRadius(settings.cornerRadiusSmall)
                .buttonStyle(.borderless)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(shimmeringSuggestedBackground)
            .cornerRadius(settings.cornerRadiusMedium)
        } else {
            Text("Suggest Workout")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    /// Plan name with a continuously-sweeping shimmer (fgColor → white →
    /// fgColor). LinearGradient's startPoint/endPoint are NOT animatable
    /// via withAnimation, so we drive the phase from a TimelineView that
    /// re-renders every display frame and recomputes the gradient endpoints
    /// from wall-clock time. 2.5s per sweep cycle.
    private func shimmeringSuggestedName(_ name: String) -> some View {
        TimelineView(.animation) { context in
            let phase = shimmerPhase(at: context.date)
            Text(name)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: settings.fgColor, location: 0),
                            .init(color: .white, location: 0.5),
                            .init(color: settings.fgColor, location: 1),
                        ],
                        startPoint: UnitPoint(x: phase, y: 0.5),
                        endPoint: UnitPoint(x: phase + 1, y: 0.5)
                    )
                )
        }
    }

    /// Card-background shimmer for the suggested-plan panel. Same phase
    /// math + same 2.5s cycle as `shimmeringSuggestedName`, so the
    /// background highlight band stays in sync with the bright text-peak
    /// sweeping across the plan name.
    ///
    /// Color stops are darker than the text shimmer — `Color(white: 0.1)`
    /// matches the original static panel background, with an
    /// `fgColor.opacity(0.25)` mid-band so the sweep reads as a subtle
    /// branded glow rather than a high-contrast stripe.
    private var shimmeringSuggestedBackground: some View {
        TimelineView(.animation) { context in
            let phase = shimmerPhase(at: context.date)
            LinearGradient(
                stops: [
                    .init(color: Color(white: 0.1), location: 0),
                    .init(color: settings.fgColor.opacity(0.25), location: 0.5),
                    .init(color: Color(white: 0.1), location: 1),
                ],
                startPoint: UnitPoint(x: phase, y: 0.5),
                endPoint: UnitPoint(x: phase + 1, y: 0.5)
            )
        }
    }

    /// Maps wall-clock time into the [-1.5, +1.5] sweep phase used by both
    /// shimmer surfaces (text + background). Cycle constant is shared so
    /// the two shimmers can't drift out of sync.
    private func shimmerPhase(at date: Date) -> CGFloat {
        let cycle: Double = 2.5
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycle) / cycle
        return CGFloat(progress * 3.0 - 1.5)
    }

    /// END SESSION label with a back-chevron prefix to read as a "Leave"
    /// affordance. Same plain fg-color text styling as the DISMISS label
    /// on the trailing edge.
    private var endSessionLabel: some View {
        Button { showEndSessionConfirm = true } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text("LEAVE")
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .foregroundColor(settings.fgColor)
        }
        .buttonStyle(.plain)
    }

    /// DISMISS label — only enabled while the keyboard is up. Sends
    /// resignFirstResponder system-wide so KeyboardPersistentTextField (a
    /// UITextField) drops focus and the keyboard slides away. Trailing
    /// down-chevron icon mirrors the HistoryView toolbar's Dismiss button.
    private var dismissKeyboardLabel: some View {
        Button {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        } label: {
            HStack(spacing: 4) {
                Text("DISMISS")
                    .font(.caption)
                    .fontWeight(.bold)
                Image(systemName: "chevron.down")
                    .resizable()
                    .frame(width: 9, height: 6)
            }
            .foregroundColor(keyboardVisible ? settings.fgColor : Color(white: 0.3))
        }
        .buttonStyle(.plain)
        .disabled(!keyboardVisible)
    }

    /// Indicator row: END SESSION (leading) + dot indicators (true center
    /// via ZStack overlay so label widths don't shift them) + DISMISS
    /// (trailing).
    @ViewBuilder
    private var indicatorRow: some View {
        ZStack {
            HStack {
                endSessionLabel
                Spacer()
                dismissKeyboardLabel
            }
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
        .padding(.horizontal, 20)
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
                // Leading 16 matches the suggested-plan pane / gradientPanel
                // outer padding above so the first carousel card lines up
                // edge-to-edge with the populated suggestion card. Trailing
                // stays at 20 — the right edge falls under the fade-to-black
                // overlay, so no alignment constraint there.
                .padding(.leading, 16)
                .padding(.trailing, 20)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentPlanId, anchor: .leading)
            .frame(height: 88)
            .overlay(alignment: .trailing) {
                // Trailing fade-to-black so any card overflowing past the
                // right edge of the phone visually dissolves into the
                // background instead of getting hard-clipped. Hidden when
                // the last card is current — at that point nothing's
                // overflowing and the gradient would just visually mute
                // the trailing card's Suggest/Preview buttons.
                LinearGradient(
                    colors: [.black.opacity(0), .black],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 75)
                .opacity(isLastCardCurrent ? 0 : 1)
                .animation(.easeInOut(duration: settings.animationQuick), value: isLastCardCurrent)
                .allowsHitTesting(false)
            }
        }
    }

    private var isLastCardCurrent: Bool {
        guard let last = planViewModel.workoutPlans.last else { return true }
        return currentPlanId == last.id
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
        .cornerRadius(settings.cornerRadiusMedium)
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
            .cornerRadius(settings.cornerRadiusSmall)
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
            .cornerRadius(settings.cornerRadiusSmall)
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
    client.myProfile = Profile(name: "Ryan", photoData: nil)
    client.peerProfiles = [peerId: Profile(name: "Alex", photoData: nil)]
    client.hasSubmittedProfile = true
    client.state = .paired(peerIds: [peerId])
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
