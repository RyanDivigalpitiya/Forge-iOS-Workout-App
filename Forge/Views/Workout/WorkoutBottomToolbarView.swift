import SwiftUI

/// Bottom toolbar shown during an active workout: Add | Done | Edit.
/// Owns the sheet presentations for ExerciseEditorView (Add) and ReorderDeleteView (Edit).
/// The Add and Edit buttons are disabled while the break timer is active.
///
/// In a collab session, the chat panel + Open/Minimize Chat row are
/// rendered by `WorkoutChatToolbar` as a SEPARATE sibling positioned just
/// above this toolbar. Splitting them lets the chat container rise with
/// the keyboard while this 3-button row stays anchored at the bottom
/// (via `.ignoresSafeArea(.keyboard)` applied at the call site).
struct WorkoutBottomToolbarView: View {

    @Binding var exerciseEditorIsPresented: Bool
    @Binding var reorderDeleteViewPresented: Bool

    let isDoneCheckMarkVisible: Bool
    let timerEnabled: Bool
    let exerciseCount: Int
    let onAddTapped: () -> Void
    let onDoneTapped: () -> Void

    @EnvironmentObject var settings: GlobalSettings
    private let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight

    /// Initial detent for the reorder/delete sheet. Set by the Edit button
    /// action right before the sheet presents — `.large` when the plan has
    /// more than 4 exercises (so the user doesn't have to drag up to see
    /// them all), `.medium` otherwise. The user can still drag between
    /// `.medium` and `.large` once the sheet is open.
    @State private var reorderDetent: PresentationDetent = .medium

    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                // ADD BUTTON
                HStack {
                    Button(action: { onAddTapped() }) {
                        Text("Add")
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                    }
                    .foregroundColor(settings.fgColor)
                    .disabled(timerEnabled)
                    .sheet(isPresented: $exerciseEditorIsPresented) {
                        ExerciseEditorView()
                            .environment(\.colorScheme, .dark)
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(timerEnabled ? 0 : 1)


                // DONE BUTTON
                Button(action: { onDoneTapped() }) {
                    ZStack {
                        HStack {
                            Text("Done")
                                .font(.system(size: 20))
                                .bold()
                        }
                        .frame(width: 75, height: 35)
                        .background(settings.fgColor)
                        .foregroundColor(.black)
                        .cornerRadius(500)
                        .opacity(isDoneCheckMarkVisible ? 0 : 1)
                        .shadow(color: settings.fgColor.opacity(0.7), radius: 10, x: 0, y: 0)

                        HStack {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20))
                                .bold()
                        }
                        .frame(width: 75, height: 35)
                        .background(settings.fgColor)
                        .foregroundColor(.black)
                        .cornerRadius(500)
                        .opacity(isDoneCheckMarkVisible ? 1 : 0)
                    }
                }
                .foregroundColor(settings.fgColor)


                // REORDER BUTTON
                HStack {
                    Button(action: {
                        reorderDetent = exerciseCount > 4 ? .large : .medium
                        reorderDeleteViewPresented = true
                    }) {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .resizable()
                            .frame(width: 15, height: 15)
                            .padding(.trailing, 3)
                        Text("Edit")
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(settings.fgColor)
                    .disabled(timerEnabled)
                    .sheet(isPresented: $reorderDeleteViewPresented) {
                        ReorderDeleteView(mode: .exercise)
                            .presentationDetents([.medium, .large], selection: $reorderDetent)
                            .environment(\.colorScheme, .dark)
                    }
                }
                .frame(maxWidth: .infinity)
                .opacity(timerEnabled ? 0 : 1)
            }
            .frame(height: bottomToolbarHeight)
            .background(BlurView(style: .systemChromeMaterial))
        }
    }
}
