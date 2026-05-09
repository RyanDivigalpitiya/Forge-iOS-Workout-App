import SwiftUI

/// In-workout ellipsis-button sheet. Opens at a small custom height showing
/// two side-by-side buttons (View History / Log Change). Tapping either
/// fades out the buttons, fades the chosen content into the same sheet, and
/// animates the sheet height to fit. Top-bar X always closes the whole
/// sheet (no morph back to the menu stage).
struct ExerciseOptionsSheet: View {

    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: GlobalSettings

    enum Stage { case menu, history, editor }

    @State private var stage: Stage = .menu
    @State private var selectedDetent: PresentationDetent = .height(220)

    private let menuDetent: PresentationDetent = .height(220)

    /// Same calculation as `ExerciseEditorView.homoModeDetent` so the editor
    /// stage's homo height matches the standalone editor exactly. Kept in
    /// sync by reading the active key window's safe-area inset at body
    /// evaluation time.
    private var bottomSafeAreaInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    private var homoModeDetent: PresentationDetent {
        let baseHeight: CGFloat = 360
        let buffer: CGFloat = bottomSafeAreaInset > 0 ? bottomSafeAreaInset : 40
        return .height(baseHeight + buffer)
    }

    var body: some View {
        ZStack {
            switch stage {
            case .menu:
                menuView
                    .transition(.opacity)
            case .history:
                historyView
                    .transition(.opacity)
            case .editor:
                editorView
                    .transition(.opacity)
            }
        }
        .presentationDetents(
            [menuDetent, homoModeDetent, .large],
            selection: $selectedDetent
        )
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Menu stage

    private var menuView: some View {
        VStack(spacing: 0) {
            topBarWithCloseOnly
                .padding(.top, 15)

            Spacer()

            HStack(spacing: 14) {
                menuButton(
                    title: "View History",
                    systemImage: "chart.line.uptrend.xyaxis"
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stage = .history
                        selectedDetent = .large
                    }
                }
                menuButton(
                    title: "Log Change",
                    systemImage: "square.and.pencil"
                ) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        stage = .editor
                        selectedDetent = homoModeDetent
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func menuButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 26))
                    .foregroundColor(settings.fgColor)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(GlobalSettings.shared.buttonCircleBgColor)
            .cornerRadius(settings.cornerRadiusMedium)
        }
        .buttonStyle(.plain)
    }

    // MARK: - History stage

    private var historyView: some View {
        VStack(spacing: 0) {
            topBarWithCloseOnly
                .padding(.top, 15)
            ScrollView {
                VStack(spacing: 12) {
                    ExerciseProgressCard(exercise: exercise)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - Editor stage

    private var editorView: some View {
        // ExerciseEditorContent provides its own top bar (X / title / Save),
        // so we don't add one here — avoids two stacked X buttons.
        ExerciseEditorContent(
            focusNameOnAppear: false,
            selectedDetent: $selectedDetent,
            homoModeDetent: homoModeDetent,
            onClose: { dismiss() },
            onSaved: { dismiss() }
        )
    }

    // MARK: - Shared chrome

    /// Top bar with only the X button (top-left). Used by .menu and .history
    /// stages. The .editor stage uses ExerciseEditorContent's own top bar
    /// instead.
    private var topBarWithCloseOnly: some View {
        HStack {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .frame(width: 28, height: 28)
                        .foregroundColor(GlobalSettings.shared.buttonCircleBgColor)
                    Image(systemName: "xmark")
                        .resizable()
                        .frame(width: 11, height: 11)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading, 20)
            Spacer()
        }
    }
}
