import SwiftUI
import UIKit

struct WorkoutWithFriendView: View {
    @EnvironmentObject var sessionClient: SessionClient
    @EnvironmentObject var settings: GlobalSettings

    @State private var connectingActive = false
    @State private var shareURL: ShareableURL?

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
            instructionRow(icon: "dumbbell.fill", text: "Choose a workout plan together")
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
    }

    private var graphicGutter: some View {
        VStack(spacing: 0) {
            // Vertical offset matching card top padding (12) + exercise
            // name placeholder height (14) + bottom gap (8) = 34.
            Color.clear.frame(height: 34)
            avatarSlot(filled: true)    // set 1 → avatar 1
            avatarSlot(filled: false)   // rest 1
            avatarSlot(filled: false)   // set 2
            avatarSlot(filled: false)   // rest 2
            avatarSlot(filled: true)    // set 3 → avatar 2
            Spacer(minLength: 0)
        }
        .frame(width: 44)
    }

    private var graphicCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            flexiblePlaceholder(
                height: 14,
                leftColor: Color.gray,
                rightColor: .clear
            )
            .padding(.bottom, 8)

            graphicSetRow().frame(height: 26)
            graphicRestRow().frame(height: 26)
            graphicSetRow().frame(height: 26)
            graphicRestRow().frame(height: 26)
            graphicSetRow().frame(height: 26)
        }
        .padding(12)
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

    private func avatarSlot(filled: Bool) -> some View {
        Group {
            if filled {
                HStack(spacing: 4) {
                    Circle()
                        .fill(GlobalSettings.shared.darkGray)
                        .frame(width: 24, height: 24)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                }
            } else {
                Color.clear
            }
        }
        .frame(height: 26)
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
        .clipShape(RoundedRectangle(cornerRadius: height / 3))
    }

    /// Width-flexible variant — fills the available horizontal space inside
    /// its parent (used for placeholders that should stretch to the right
    /// edge of the exercise card).
    private func flexiblePlaceholder(
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
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 3))
    }

    private func graphicSetRow() -> some View {
        HStack(spacing: 0) {
            Circle()
                .stroke(Color.gray.opacity(0.6), lineWidth: 1.2)
                .frame(width: 14, height: 14)
                .padding(.trailing, 6)
            Circle()
                .stroke(settings.fgColor.opacity(0.6), lineWidth: 1.2)
                .frame(width: 14, height: 14)
                .padding(.trailing, 10)
            // Set + weight x reps placeholder — fg-tinted so it reads as
            // the "active" content row vs. the grey name/rest placeholders.
            // Stretches to the card's right edge.
            flexiblePlaceholder(
                height: 12,
                leftColor: settings.fgColor.opacity(0.3),
                rightColor: .clear
            )
        }
    }

    private func graphicRestRow() -> some View {
        HStack(spacing: 0) {
            graphicConnector
                .padding(.trailing, 6)
            graphicConnector
                .padding(.trailing, 10)
            flexiblePlaceholder(
                height: 10,
                leftColor: Color.gray,
                rightColor: .clear
            )
        }
    }

    private var graphicConnector: some View {
        VStack(spacing: 1) {
            Rectangle().frame(width: 1, height: 7)
            Circle().frame(width: 4, height: 4)
            Rectangle().frame(width: 1, height: 7)
        }
        .foregroundColor(GlobalSettings.shared.darkGray)
        .frame(width: 14)
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
