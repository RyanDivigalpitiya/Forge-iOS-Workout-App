import SwiftUI

struct PlanSuggestionView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings
    @EnvironmentObject var planViewModel: PlanViewModel

    @State private var planEditorIsPresented = false
    @State private var showEndSessionConfirm = false
    @State private var currentPlanId: UUID?
    @State private var suggestedPaneScale: CGFloat = 1.0
    @State private var chatDraft: String = ""

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

            dotIndicators
                .frame(maxWidth: .infinity)
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
            endSessionButton
        }
    }

    @ViewBuilder
    private var suggestedHeaderCluster: some View {
        if let suggested = sessionClient.suggestedPlan {
            HStack(spacing: 10) {
                Text("Suggested: \(suggested.name)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

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
        } else {
            Text("Suggest Workout")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    private var endSessionButton: some View {
        Button {
            showEndSessionConfirm = true
        } label: {
            ZStack {
                Circle()
                    .frame(width: 24, height: 24)
                    .foregroundColor(Color(.systemGray4))
                Image(systemName: "xmark")
                    .resizable()
                    .frame(width: 10, height: 10)
                    .fontWeight(.bold)
                    .foregroundColor(settings.fgColor)
            }
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
