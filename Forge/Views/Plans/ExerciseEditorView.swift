import SwiftUI

/// Standalone editor sheet — the original full-screen-style editor used by
/// the plan editor and the in-workout exercise-name + set-row pathways.
///
/// Now a thin wrapper around `ExerciseEditorContent`. The wrapper owns the
/// `selectedDetent` state, the `homoModeDetent` math, and the `dismiss`
/// behaviour; the content view does the actual UI.
///
/// External API is unchanged: callers still write `ExerciseEditorView()` or
/// `ExerciseEditorView(focusNameOnAppear: true)`.
struct ExerciseEditorView: View {

    /// When true, the editor brings up the keyboard with focus on the name
    /// field after the present transition settles. Used by the in-workout
    /// "tap exercise name" pathway that wants to drop the user straight
    /// into renaming.
    let focusNameOnAppear: Bool

    init(focusNameOnAppear: Bool = false) {
        self.focusNameOnAppear = focusNameOnAppear
    }

    @Environment(\.dismiss) private var dismiss

    /// Sheet detent. Owned locally so the editor can size itself to its
    /// content height. Two detents are defined in the body:
    ///  - `homoModeDetent`: tight fit for homogeneous mode
    ///  - `.large`: roomy for heterogeneous mode (variable per-set rows)
    @State private var selectedDetent: PresentationDetent = .height(380)

    /// Bottom safe-area inset of the active window (home-indicator height,
    /// 0 on SE / phones with a physical home button). Added to the homo
    /// detent so the visible content area is identical across devices.
    private var bottomSafeAreaInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.bottom ?? 0
    }

    /// Tight detent for homogeneous mode. Base = ~360pt of usable content
    /// (title bar + name field + 200pt picker + toggle).
    /// On home-indicator phones we add the bottom safe-area inset so the
    /// indicator doesn't eat into the toggle. SE-class phones have no
    /// indicator AND no bleed-room (the sheet edge hard-clips), so we
    /// substitute a fixed 40pt buffer.
    private var homoModeDetent: PresentationDetent {
        let baseHeight: CGFloat = 360
        let buffer: CGFloat = bottomSafeAreaInset > 0 ? bottomSafeAreaInset : 40
        return .height(baseHeight + buffer)
    }

    var body: some View {
        ExerciseEditorContent(
            focusNameOnAppear: focusNameOnAppear,
            selectedDetent: $selectedDetent,
            homoModeDetent: homoModeDetent,
            onClose: { dismiss() },
            onSaved: { dismiss() }
        )
        .presentationDetents([homoModeDetent, .large], selection: $selectedDetent)
        .presentationDragIndicator(.hidden)
    }
}

struct ExerciseEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseEditorView()
            .environmentObject(CompletedWorkoutsViewModel())
            .environmentObject(ExerciseViewModel())
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
