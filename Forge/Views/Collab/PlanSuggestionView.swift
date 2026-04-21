import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var activeCover: ActiveCover?
    @State private var showEndSessionConfirm = false
    @State private var currentPlanId: UUID?
    @State private var suggestedPaneScale: CGFloat = 1.0
    @State private var chatDraft: String = ""
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

    var body: some View {
        VStack(spacing: 16) {
            gradientPanel

            carouselHeaderRow
                .padding(.horizontal, 20)

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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
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
            planViewModel.activePlan = inProgress.toWorkoutPlan()
            activeCover = .workoutInProgress
        } else if sessionClient.startWorkoutSignal != nil,
                  let suggested = sessionClient.suggestedPlan {
            planViewModel.activePlan = suggested.toWorkoutPlan()
            activeCover = .workoutInProgress
        }
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
        activeCover = .planEditor
    }

    private var gradientPanel: some View {
        VStack(spacing: 16) {
            avatarRow
                .padding(.horizontal, 12)
                .padding(.top, 12)

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
        HStack(spacing: 0) {
            Spacer()

            readyUpButton(isSelf: true)
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

            readyUpButton(isSelf: false)
                .padding(.leading, 7)

            Spacer()
        }
    }

    private func readyUpButton(isSelf: Bool) -> some View {
        let peerIsReady = peerId.flatMap { sessionClient.peerReady[$0] } ?? false
        let isReady = isSelf ? sessionClient.myIsReady : peerIsReady
        let canInteract = isSelf && sessionClient.suggestedPlan != nil

        return Button {
            if isSelf { sessionClient.toggleReady() }
        } label: {
            Text(isReady ? "READY" : "READY UP")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(isReady ? .black : settings.fgColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isReady ? settings.fgColor : Color.clear)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
        .disabled(!canInteract)
        .opacity(isReady || canInteract ? 1.0 : 0.35)
        .shadow(
            color: settings.fgColor.opacity(isReady ? 0.5 : 0.4),
            radius: 15,
            x: 0,
            y: 0
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
        VStack(spacing: 4) {
            chatMessagesScroll
            chatInputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatMessagesScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if sessionClient.chatEntries.isEmpty {
                    Text("Say hi 👋")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.4))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(sessionClient.chatEntries) { entry in
                            chatBubble(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: sessionClient.chatEntries.count) { _, _ in
                scrollToLatest(using: proxy)
            }
            .onAppear {
                scrollToLatest(using: proxy)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)
            ) { _ in
                scrollToLatest(using: proxy)
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)
            ) { _ in
                scrollToLatest(using: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func chatBubble(entry: ChatEntry) -> some View {
        HStack(spacing: 0) {
            if entry.isMine { Spacer(minLength: 48) }
            Text(entry.text)
                .font(.subheadline)
                .foregroundColor(entry.isMine ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(entry.isMine ? settings.fgColor : Color(white: 0.22))
                .cornerRadius(14)
            if !entry.isMine { Spacer(minLength: 48) }
        }
    }

    private var chatInputBar: some View {
        HStack(spacing: 8) {
            KeyboardPersistentTextField(
                text: $chatDraft,
                placeholder: "Message",
                onSubmit: sendCurrentDraft
            )
            .frame(height: 22)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .cornerRadius(16)

            Button(action: sendCurrentDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(canSendDraft ? settings.fgColor : .gray.opacity(0.35))
            }
            .disabled(!canSendDraft)
        }
    }

    private var canSendDraft: Bool {
        !chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendCurrentDraft() {
        sessionClient.sendChat(text: chatDraft)
        chatDraft = ""
    }

    private func scrollToLatest(using proxy: ScrollViewProxy) {
        guard let lastId = sessionClient.chatEntries.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private var carouselHeaderRow: some View {
        HStack(spacing: 10) {
            suggestedHeaderCluster
                .scaleEffect(suggestedPaneScale)
            Spacer()
        }
    }

    @ViewBuilder
    private var suggestedHeaderCluster: some View {
        if let suggested = sessionClient.suggestedPlan {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggested")
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
                .cornerRadius(5)
                .buttonStyle(.borderless)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.1))
            .cornerRadius(8)
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
            let cycle: Double = 2.5
            let progress = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle) / cycle
            // Map [0,1] → [-1.5, 1.5] so the bright midpoint sweeps from
            // off-left, across the text, to off-right per cycle.
            let phase = CGFloat(progress * 3.0 - 1.5)
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

    /// END SESSION text label — replaces the old X-circle button. Same plain
    /// fg-color text styling as the DISMISS label on the trailing edge.
    private var endSessionLabel: some View {
        Button { showEndSessionConfirm = true } label: {
            Text("LEAVE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
        }
        .buttonStyle(.plain)
    }

    /// DISMISS label — only enabled while the keyboard is up. Sends
    /// resignFirstResponder system-wide so KeyboardPersistentTextField (a
    /// UITextField) drops focus and the keyboard slides away.
    private var dismissKeyboardLabel: some View {
        Button {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        } label: {
            Text("DISMISS")
                .font(.caption)
                .fontWeight(.bold)
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
                .padding(.horizontal, 20)
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
                .animation(.easeInOut(duration: 0.2), value: isLastCardCurrent)
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

/// UITextField wrapped for SwiftUI so Return-to-send doesn't dismiss the
/// keyboard. SwiftUI's TextField + .submitLabel(.send) + .onSubmit always
/// resigns first responder on submit — re-asserting @FocusState right
/// after causes a visible flicker. Intercepting Return at the UIKit
/// delegate level and returning false from textFieldShouldReturn keeps
/// the field first-responder throughout.
///
/// Also sets autocorrectionType = .no + spellCheckingType = .no, which is
/// the more reliable path than SwiftUI's .autocorrectionDisabled() for
/// suppressing the iOS QuickType predictive text bar.
struct KeyboardPersistentTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.returnKeyType = .send
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.smartInsertDeleteType = .no
        tf.textColor = .white
        tf.backgroundColor = .clear
        tf.font = .preferredFont(forTextStyle: .subheadline)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.gray.withAlphaComponent(0.6)]
        )
        tf.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.onSubmit = onSubmit
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        @objc func editingChanged(_ textField: UITextField) {
            text.wrappedValue = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            return false
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
