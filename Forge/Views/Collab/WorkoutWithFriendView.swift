import SwiftUI
import UIKit

struct WorkoutWithFriendView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var connectingActive = false
    @State private var shareURL: ShareableURL?
    /// Tracks which gradient rectangles have run their on-appear stagger
    /// animation. Indices 0…5 cascade top-to-bottom inside the collab
    /// preview graphic; each rectangle reads `appearedIndices.contains`
    /// to drive its own opacity + offset.
    @State private var appearedIndices: Swift.Set<Int> = []

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
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareURL) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
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
            instructionRow(icon: "square.and.arrow.up.fill", text: "Share invite link with a friend")
            instructionRow(icon: "bubble.left.and.text.bubble.right.fill", text: "Choose a workout plan together")
            instructionRow(icon: "person.2.fill", text: "Workout with each other")
        }
    }

    private func instructionRow(icon: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
            Text(text)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                withAnimation(.easeOut(duration: 0.5)) {
                    _ = appearedIndices.insert(index)
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private var graphicGutter: some View {
        VStack(spacing: 0) {
            // Vertical offset matching card top padding (16) + exercise
            // name placeholder height (22) + bottom gap (12) = 50.
            Color.clear.frame(height: 50)
            avatarSlot(imageName: "collabAvatar1")    // set 1 → avatar 1
            avatarSlot(imageName: nil)                 // rest 1
            avatarSlot(imageName: "collabAvatar2")                 // set 2
            avatarSlot(imageName: nil)                 // rest 2
            avatarSlot(imageName: nil)    // set 3 → avatar 2
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
        sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        UIPasteboard.general.string = url.absoluteString
        connectingActive = true
    }

    private func generateAndShare() {
        sessionClient.createSession()
        guard let url = sessionClient.shareLinkURL() else { return }
        shareURL = ShareableURL(url: url)
        connectingActive = true
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
