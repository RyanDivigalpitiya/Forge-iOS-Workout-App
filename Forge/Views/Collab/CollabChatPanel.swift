import SwiftUI
import UIKit

/// Reusable chat surface for a collab session. Originally inlined in
/// `PlanSuggestionView`; extracted here so `WorkoutInProgressView` can host
/// the same chat during the active workout. Reads `sessionClient` +
/// `settings` from the environment and owns its own draft state.
///
/// `showAvatarHeader: true` renders a peer-left / self-right avatar row
/// with a connector between them at the top of the panel — mirrors the
/// avatarRow in `PlanSuggestionView`, minus the READY UP buttons. Used by
/// the workout-mode chat panel so the friends still see each other while
/// chatting. Defaults to false so `PlanSuggestionView` (which renders the
/// avatar row separately, with the READY UP buttons) is unaffected.
struct CollabChatPanel: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    var showAvatarHeader: Bool = false

    @State private var chatDraft: String = ""
    /// Driven by `KeyboardPersistentTextView` via a binding. Starts at one
    /// line and grows as the user types more wrapped lines, capped at
    /// ~5 lines via `.frame(maxHeight:)` on the SwiftUI side.
    @State private var inputHeight: CGFloat = 22

    private var peerId: UUID? { sessionClient.peerIds.first }
    private var peerProfile: Profile? {
        guard let pid = peerId else { return nil }
        return sessionClient.peerProfiles[pid]
    }

    var body: some View {
        VStack(spacing: 4) {
            if showAvatarHeader {
                avatarHeader
                    .padding(.top, 4)
            }
            chatMessagesScroll
            chatInputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var avatarHeader: some View {
        avatar(
            data: peerProfile?.photoData,
            fallbackInitial: initial(from: peerProfile?.name ?? "?"),
            diameter: 56
        )
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
        HStack(alignment: .bottom, spacing: 8) {
            KeyboardPersistentTextView(
                text: $chatDraft,
                dynamicHeight: $inputHeight,
                placeholder: "Message",
                onSubmit: sendCurrentDraft
            )
            .frame(maxWidth: .infinity)
            .frame(height: min(max(inputHeight, 22), 100))
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
            .padding(.bottom, 4)
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

/// Multi-line UITextView wrapped in a UIViewRepresentable so:
/// (a) Long messages wrap to new lines instead of expanding the input
///     bar's width (UITextField is single-line and grows horizontally).
/// (b) Tapping Send / Return doesn't dismiss the keyboard. SwiftUI's
///     TextField + `.onSubmit` always resigns first responder, causing
///     a visible flicker even with immediate `@FocusState` reassertion.
///     We intercept "\n" in `shouldChangeTextIn` and call `onSubmit()`
///     while returning false so the field stays first-responder.
///
/// `isScrollEnabled = false` makes the text view grow with content; the
/// SwiftUI side caps it via `.frame(maxHeight:)`. autocorrect / spell-
/// check / QuickType are all disabled at the UIKit level — SwiftUI's
/// `.autocorrectionDisabled()` is inconsistent.
/// UITextView subclass that reports `noIntrinsicMetric` for its
/// intrinsic WIDTH. Default UITextView (with `isScrollEnabled = false`)
/// reports an intrinsic width equal to the longest single line, which
/// in an HStack causes the field to expand horizontally on long input
/// instead of wrapping. Returning noIntrinsicMetric for width tells
/// SwiftUI "I have no preferred width — let the parent constrain me",
/// at which point the text view honors its assigned width and wraps
/// text vertically.
private final class WrappingUITextView: UITextView {
    override var intrinsicContentSize: CGSize {
        return CGSize(
            width: UIView.noIntrinsicMetric,
            height: super.intrinsicContentSize.height
        )
    }
}

struct KeyboardPersistentTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    let placeholder: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = WrappingUITextView()
        tv.delegate = context.coordinator
        tv.returnKeyType = .send
        tv.autocorrectionType = .no
        tv.spellCheckingType = .no
        tv.smartInsertDeleteType = .no
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.textColor = .white
        tv.backgroundColor = .clear
        tv.font = .preferredFont(forTextStyle: .subheadline)
        tv.textContainer.lineFragmentPadding = 0
        // Asymmetric vertical inset so the typed text (and cursor) sit
        // vertically centered relative to the placeholder and chat-input
        // bar. The font's line fragment includes ascender+descender, but
        // the VISIBLE glyphs (cap height) sit in the upper portion of
        // the line — so symmetric insets still leave the text visually
        // high. A larger top inset compensates.
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 5, right: 0)
        tv.isScrollEnabled = false

        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = tv.font
        placeholderLabel.textColor = UIColor.gray.withAlphaComponent(0.6)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            // centerY (not top) so the placeholder sits where the cursor
            // sits — UITextView's text baseline sits a hair below its
            // top edge, so anchoring the placeholder to top makes it
            // visually shifted up relative to the cursor.
            placeholderLabel.centerYAnchor.constraint(equalTo: tv.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: tv.leadingAnchor),
        ])
        context.coordinator.placeholderLabel = placeholderLabel
        placeholderLabel.isHidden = !text.isEmpty

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Re-assert insets on every update — defends against SwiftUI
        // reusing a cached UITextView from a previous build that had
        // different padding values.
        let desiredInset = UIEdgeInsets(top: 8, left: 0, bottom: 5, right: 0)
        if uiView.textContainerInset != desiredInset {
            uiView.textContainerInset = desiredInset
        }
        if uiView.text != text {
            uiView.text = text
        }
        context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        context.coordinator.parent = self
        recalcHeight(view: uiView)
    }

    /// Reports the text view's measured content height back to SwiftUI
    /// via the `dynamicHeight` binding. Async so the read happens after
    /// UIKit finishes laying out the new text.
    private func recalcHeight(view: UITextView) {
        let width = view.bounds.width > 0 ? view.bounds.width : 200
        let measured = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        DispatchQueue.main.async {
            if abs(self.dynamicHeight - measured) > 0.5 {
                self.dynamicHeight = measured
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: KeyboardPersistentTextView
        weak var placeholderLabel: UILabel?

        init(parent: KeyboardPersistentTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
            parent.recalcHeight(view: textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // Intercept Return → fire submit handler, keep keyboard up.
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }
    }
}
