import SwiftUI

/// Bottom toolbar shown during an active workout: Add | Done | Edit.
/// Owns the sheet presentations for ExerciseEditorView (Add) and ReorderDeleteView (Edit).
/// The Add and Edit buttons are disabled while the break timer is active.
struct WorkoutBottomToolbarView: View {

    @Binding var exerciseEditorIsPresented: Bool
    @Binding var reorderDeleteViewPresented: Bool
    @Binding var selectedDetent: PresentationDetent

    let isDoneCheckMarkVisible: Bool
    let timerEnabled: Bool
    let onAddTapped: () -> Void
    let onDoneTapped: () -> Void

    // Collab-only chat row above the 3 buttons. When `showChatRow` is true,
    // the toolbar grows to accommodate a divider + Open/Minimize Chat button
    // styled to match `PlanEditorView`'s "New Exercise" row.
    var showChatRow: Bool = false
    var isChatOpen: Bool = false
    var onChatToggleTapped: () -> Void = {}

    @EnvironmentObject var settings: GlobalSettings
    private let bottomToolbarHeight = GlobalSettings.shared.bottomToolbarHeight
    private let chatRowAdditionalHeight: CGFloat = 50
    private let screenWidth = UIScreen.main.bounds.width

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                if showChatRow {
                    chatToggleRow
                        .frame(height: chatRowAdditionalHeight)
                    Divider()
                        .padding(.horizontal, 54)
                }
                buttonRow
                    .padding(.bottom, 15)
                    .frame(height: bottomToolbarHeight)
            }
            .background(BlurView(style: .systemChromeMaterial))
        }
    }

    private var chatToggleRow: some View {
        HStack {
            Button(action: { onChatToggleTapped() }) {
                HStack {
                    Image(systemName: isChatOpen ? "xmark.bubble.fill" : "bubble.left.fill")
                    Text(isChatOpen ? "Minimize Chat" : "Open Chat").fontWeight(.bold)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .foregroundColor(settings.fgColor)
            }
        }
    }

    private var buttonRow: some View {
        HStack {
                Spacer()

                // ADD BUTTON
                HStack {
                    Button(action: {
                        onAddTapped()
                    }) {
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
                        ExerciseEditorView(selectedDetent: $selectedDetent)
                            .presentationDetents([.medium, .large], selection: $selectedDetent)
                            .presentationDragIndicator(.hidden)
                            .environment(\.colorScheme, .dark)
                    }
                }
                .frame(width: 0.33 * screenWidth)


                // DONE BUTTON
                HStack {
                    Button(action: {
                        onDoneTapped()
                    }) {
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
                }
                .frame(width: 0.2 * screenWidth)


                // REORDER BUTTON
                HStack {
                    Button(action: {
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
                            .presentationDetents([.medium, .large])
                            .environment(\.colorScheme, .dark)
                    }
                }
                .frame(width: 0.33 * screenWidth)

                Spacer()
            }
        }
}
