import SwiftUI

/// Supporting types for the joint-mode avatar gutter rendered in
/// `WorkoutInProgressView`. Kept as a sibling file so the anchor-preference
/// plumbing isn't inlined at the top of the 1000+ line view. Visibility is
/// `internal` (the default) rather than `fileprivate` because the view lives
/// in a separate file.

/// Identifies the `(exerciseIndex, setIndex)` of the set whose break timer
/// is currently running. Used by `recomputeMyPosition` to decide whether to
/// place the avatar on a rest row vs. on the next incomplete set.
struct RestingSet: Equatable {
    let exercise: Int
    let set: Int
}

/// Identifies a row within a single exercise card. Scoped per-exercise:
/// each exercise's overlayPreferenceValue resolves its own dict of these,
/// so `exerciseIndex` isn't part of the case.
enum RowID: Hashable {
    case setRow(Int)   // setIndex
    case restRow(Int)  // setIndex (the rest row sits BELOW the set with this index)
}

/// PreferenceKey carrying anchors for each row in an exercise card. The card
/// publishes one anchor per set / rest row; the overlay reads them via a
/// GeometryReader and absolutely positions an avatar at each row's `midY`.
/// Makes avatar alignment immune to row-height variation (e.g. when an
/// exercise name wraps to two lines).
struct RowAnchorKey: PreferenceKey {
    static let defaultValue: [RowID: Anchor<CGRect>] = [:]
    static func reduce(
        value: inout [RowID: Anchor<CGRect>],
        nextValue: () -> [RowID: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}
