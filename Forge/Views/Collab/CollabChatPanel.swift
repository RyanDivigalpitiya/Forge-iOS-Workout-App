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
    /// Mid-workout chat sits over the live workout view (lots of black) and
    /// inside its own chrome-material blur container. The default opaque
    /// `Color(white: 0.15)` input background reads as a flat block on top of
    /// that blur. Setting this `true` swaps in a translucent darker grey
    /// that lets the underlying blur show through, matching the surrounding
    /// chrome aesthetic. PlanSuggestionView (no underlying view to blend
    /// with) keeps the default opaque field.
    var translucentInputBackground: Bool = false

    @State private var chatDraft: String = ""
    /// Driven by `KeyboardPersistentTextView` via a binding. Starts at one
    /// line and grows as the user types more wrapped lines, capped at
    /// ~5 lines via `.frame(maxHeight:)` on the SwiftUI side.
    @State private var inputHeight: CGFloat = 22
    /// Custom (non-native) reaction picker state. Holds the entry id of
    /// the bubble whose picker is currently shown; nil = no picker.
    /// We drive the long-press + picker ourselves rather than using
    /// `.contextMenu` because every platform-specific glitch we hit
    /// (badge clipping, iOS 18 wobble, behind-bubble flash on stamp,
    /// rounded-corner flicker on dismiss) traces back to iOS's
    /// system-level lift/dismiss pipeline. Custom picker = single code
    /// path, no platter, no z-order conflicts.
    @State private var pickerForEntry: UUID? = nil

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
        // Drag-down gesture covers the empty state + avatar header
        // (where there's no scrollview to swipe). The messages
        // ScrollView has its own .scrollDismissesKeyboard(.immediately)
        // so this gesture is overshadowed there — touches inside the
        // ScrollView go to the scroll, not this gesture.
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
        )
    }

    private var avatarHeader: some View {
        let isAway = peerId.flatMap { sessionClient.peerAway[$0] } != nil
        return awayDimmedAvatar(
            data: peerProfile?.photoData,
            fallbackInitial: initial(from: peerProfile?.name ?? "?"),
            diameter: 56,
            isAway: isAway
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
                    // Spacing 16 clears the badge's `.offset(y: 14)`
                    // protrusion below each bubble (see `reactionBadge`)
                    // with 2pt of air. The picker is a sibling of the
                    // bubble inside the row's VStack, so it lives in
                    // normal layout flow — no z-index hacks needed.
                    LazyVStack(spacing: 16) {
                        ForEach(sessionClient.chatEntries) { entry in
                            chatBubble(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollDismissesKeyboard(.immediately)
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

    /// iMessage Tapback set. Reaction picker rendered inside the
    /// `.contextMenu` on each peer bubble.
    private static let reactionSet = ["❤️", "👍", "👎", "😂", "‼️", "❓"]

    /// Detects URLs (schemed + bare domains) via `NSDataDetector` and
    /// attributes them as tappable links. SwiftUI's `Text` renders `.link`
    /// ranges via the system `OpenURLAction` (default → Safari). Underline
    /// + bubble-text color keeps the link distinct without clashing with
    /// any of the six accent themes.
    private func attributedTextWithLinks(_ text: String, color: Color) -> AttributedString {
        var attributed = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        for match in detector.matches(in: text, range: fullRange) {
            guard let url = match.url,
                  let stringRange = Range(match.range, in: text),
                  let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                  let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
            else { continue }
            let attrRange = lower..<upper
            attributed[attrRange].link = url
            attributed[attrRange].underlineStyle = .single
            attributed[attrRange].foregroundColor = color
        }
        return attributed
    }

    @ViewBuilder
    private func chatBubble(entry: ChatEntry) -> some View {
        // Bubble + (conditional) picker stack vertically. Picker is a
        // SIBLING of the bubble (not an overlay) so it sits in normal
        // layout below the bubble — no horizontal overflow, no z-order
        // games with neighbouring bubbles, and the next message is
        // naturally pushed down while the picker is open.
        VStack(alignment: entry.isMine ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 0) {
                if entry.isMine { Spacer(minLength: 48) }
                ZStack(alignment: entry.isMine ? .bottomLeading : .bottomTrailing) {
                    Text(attributedTextWithLinks(entry.text, color: entry.isMine ? .black : .white))
                        .font(.subheadline)
                        .foregroundColor(entry.isMine ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(entry.isMine ? settings.fgColor : Color(white: 0.22))
                        .cornerRadius(14)
                        .onLongPressGesture(minimumDuration: 0.3) {
                            guard !entry.isMine else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                pickerForEntry = entry.id
                            }
                        }
                    reactionBadge(for: entry)
                }
                if !entry.isMine { Spacer(minLength: 48) }
            }
            if pickerForEntry == entry.id {
                HStack(spacing: 0) {
                    if entry.isMine { Spacer(minLength: 48) }
                    reactionPicker(for: entry)
                    if !entry.isMine { Spacer(minLength: 48) }
                }
                .transition(
                    .scale(
                        scale: 0.6,
                        anchor: entry.isMine ? .topTrailing : .topLeading
                    )
                    .combined(with: .opacity)
                )
            }
        }
    }

    /// Custom reaction picker. Six emoji + an X dismiss, in a horizontal
    /// capsule rendered as a SIBLING of the bubble (see `chatBubble`).
    /// Each emoji is a plain `Text` with `.onTapGesture` instead of a
    /// `Button` — Buttons (even with `.buttonStyle(.plain)`) inherit
    /// iOS's foreground tint which absorbs colored emoji glyphs and
    /// renders them invisible. Tap-targets are the padded glyph itself.
    @ViewBuilder
    private func reactionPicker(for entry: ChatEntry) -> some View {
        let currentReaction = entry.myReaction
        HStack(spacing: 4) {
            ForEach(Self.reactionSet, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: 22))
                    .padding(6)
                    .background(
                        Circle().fill(
                            currentReaction == emoji
                                ? Color.white.opacity(0.18) : Color.clear
                        )
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        let next: String? = (currentReaction == emoji) ? nil : emoji
                        sessionClient.setReaction(messageId: entry.id, emoji: next)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            pickerForEntry = nil
                        }
                    }
            }
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        pickerForEntry = nil
                    }
                }
                .padding(.leading, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 10, y: 3)
    }

    /// Small emoji-on-pill badge, offset to peek over the bubble corner
    /// iMessage-style. With own-message reactions disabled, at most one
    /// reaction lives on any bubble: peer's reaction on my message
    /// (`peerReaction`), or my reaction on peer's message (`myReaction`).
    /// Renders instantly on add/remove — earlier animation attempts all
    /// clipped or flickered.
    @ViewBuilder
    private func reactionBadge(for entry: ChatEntry) -> some View {
        let emoji: String? = entry.isMine ? entry.peerReaction : entry.myReaction
        if let emoji {
            Text(emoji)
                .font(.system(size: 14))
                .padding(4)
                .background(Circle().fill(Color(white: 0.12)))
                // Pulled diagonally off the bubble corner so the badge
                // sits half-outside (clear of leftmost/rightmost text).
                // x = ±12 keeps the badge's inner edge ~10pt inside the
                // bubble (clear of the 12pt text padding); y = 14 puts
                // the badge's top right at the text region's bottom
                // edge — no descender clipping. LazyVStack spacing 16
                // (set in chatMessagesScroll) clears the protrusion.
                .offset(x: entry.isMine ? -12 : 12, y: 14)
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
            .background(translucentInputBackground ? Color.black.opacity(0.4) : Color(white: 0.15))
            .clipShape(Capsule())

            Button(action: sendCurrentDraft) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(canSendDraft ? settings.fgColor : .gray.opacity(0.35))
            }
            .disabled(!canSendDraft)
            .padding(.bottom, 6)
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

// MARK: - Previews

#Preview("Paired w/ chat") {
    CollabChatPanel(showAvatarHeader: true)
        .environmentObject(MockSessionClient.pairedWithChat())
        .environmentObject(GlobalSettings.shared)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Empty (just paired)") {
    CollabChatPanel(showAvatarHeader: true)
        .environmentObject(MockSessionClient.paired())
        .environmentObject(GlobalSettings.shared)
        .background(Color.black)
        .preferredColorScheme(.dark)
}

#Preview("Translucent input bg") {
    CollabChatPanel(showAvatarHeader: false, translucentInputBackground: true)
        .environmentObject(MockSessionClient.pairedWithChat())
        .environmentObject(GlobalSettings.shared)
        .background(Color.black)
        .preferredColorScheme(.dark)
}
