import SwiftUI
import UIKit

/// Reusable chat surface for a collab session. Originally inlined in
/// `PlanSuggestionView`; extracted here so `WorkoutInProgressView` can host
/// the same chat during the active workout. Reads `sessionClient` +
/// `settings` from the environment and owns its own draft state.
struct CollabChatPanel: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var chatDraft: String = ""

    var body: some View {
        VStack(spacing: 4) {
            chatMessagesScroll
            chatInputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chatMessagesScroll: some View {
        ScrollViewReader { proxy in
            // Empty-state placeholder lives OUTSIDE the ScrollView so it can
            // fill the chat container's full vertical space and center
            // itself. ScrollView sizes to content, so wrapping the
            // placeholder in a Spacer-padded VStack inside it wouldn't
            // actually take the available height.
            if sessionClient.chatEntries.isEmpty {
                VStack {
                    Spacer()
                    Text("Say hi 👋")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.4))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(sessionClient.chatEntries) { entry in
                            chatBubble(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 8)
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
            .cornerRadius(settings.cornerRadiusLarge)

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
        withAnimation(.easeOut(duration: settings.animationQuick)) {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

/// UITextField wrapped in a UIViewRepresentable so the keyboard does NOT
/// dismiss when the user taps the Send / Return key. SwiftUI's TextField +
/// `.submitLabel(.send)` + `.onSubmit` always resigns first responder,
/// causing a visible keyboard flicker even with immediate `@FocusState`
/// reassertion. Returning false from `textFieldShouldReturn` keeps the
/// field first-responder throughout.
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
