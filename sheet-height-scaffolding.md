# Dynamic Sheet Heights — Assessment & Future Refactor

Parking-lot doc. Captures the current ad-hoc approach to fit-to-content
sheets in Forge and a sketch of what a reusable scaffolding would look
like if/when we decide to extract it.

## Problem statement

iOS provides `.presentationDetents([.medium, .large, .height(CGFloat)])`
but **no `.fitContent` / `.intrinsic` detent**. To render a sheet that
hugs its content height (no wasted bottom space, no clipping), you have
to:

1. Render the content at a placeholder size.
2. Measure it via `GeometryReader`.
3. Pipe the measurement through a `PreferenceKey` into a `@State`.
4. Bind that `@State` to `.presentationDetents([.height(state)])`.
5. Hope the iOS version honors mid-presentation detent updates cleanly.

Nine concrete reasons this is fragile in SwiftUI:

1. **No native fit-to-content detent** — must measure manually.
2. **Chicken-and-egg layout** — sheet needs height to lay out, content
   needs layout to be measurable. Two-phase render means at least one
   "wrong size" frame.
3. **iOS partially caches the initial detent** — first frame is locked
   to whatever you seed. Big mid-presentation jumps (e.g. 230 → 420)
   animate awkwardly or get clipped on some iOS versions; small jumps
   smooth out invisibly.
4. **`GeometryReader` is greedy** — defaults to filling available space,
   the opposite of intrinsic measurement. The `.background(GeometryReader)`
   trick works (the background adopts the view's size) but it's a
   workaround, not an obvious API.
5. **`PreferenceKey` fires multiple times** — emits 0pt and partial
   layouts before a final value. Need a sanity floor, hand-tuned per sheet.
6. **`ScrollView` + `.fixedSize` + intrinsic height interact awkwardly** —
   sheets in this codebase are wrapped in scroll-disabled ScrollViews
   purely to fix the top-edge gap (see point 7), which complicates the
   intrinsic-sizing math.
7. **Drag-handle safe area is invisible chrome** — even with
   `.presentationDragIndicator(.hidden)`, iOS reserves ~22pt at the top
   of the sheet. Your content height + system chrome ≠ the detent you
   set, so the math drifts. The ScrollView wrapper sidesteps this
   because ScrollView content can extend under the safe area inset.
8. **iOS version drift** — custom detents shipped iOS 16; iOS 17/18/26
   each tweaked timing, animation curves, and how aggressively
   mid-presentation detent changes are honored.
9. **`@State` defaults can't depend on init parameters** — a sheet with
   multiple modes (e.g. add vs delete) needs `_height = State(initialValue: ...)`
   in init to seed the right per-mode initial. Easy to miss; hardcoded
   `@State` defaults break for whichever mode they don't match.

## Current ad-hoc approach in Forge

Each fit-to-content sheet (`UpdateWeightSheet`, `EditHeightSheet`)
copy-pastes the same six-piece scaffolding:

```swift
private struct SheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MySheet: View {
    @State private var measuredContentHeight: CGFloat = 220 // hand-tuned seed

    var body: some View {
        ScrollView {                                          // (1) gap-free top
            VStack(spacing: 0) { /* content */ }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true) // (2) force intrinsic
                .background(                                  // (3) measure
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: SheetContentHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
        }
        .scrollDisabled(true)                                 // (4) no real scroll
        .onPreferenceChange(SheetContentHeightKey.self) { h in // (5) write back
            let rounded = h.rounded()
            guard rounded > 150 else { return }               // sanity floor (hand-tuned)
            if abs(rounded - measuredContentHeight) > 1 {
                measuredContentHeight = rounded
            }
        }
        .presentationDetents([.height(measuredContentHeight)]) // (6) dynamic detent
        .presentationDragIndicator(.hidden)
    }
}
```

For multi-mode sheets, the seed has to be set via init:

```swift
init(editingEntry: BodyWeightEntry? = nil) {
    self.editingEntry = editingEntry
    _measuredContentHeight = State(initialValue: editingEntry == nil ? 420 : 230)
}
```

### What's hand-tuned per sheet

- **Initial seed value** — eyeballed from content. Wrong → first-frame size flash.
- **Sanity floor** in `onPreferenceChange` — must be below smallest
  realistic content but above pre-layout noise. Currently 120pt for
  EditHeightSheet, 150pt for UpdateWeightSheet.
- **Per-mode initial seed** via init when content varies by mode.

### Failure modes seen during development

- Content clipped because seed too small + iOS doesn't grow detent reliably.
- Empty space below content because seed too large + iOS doesn't shrink reliably.
- Toolbar pushed down by drag-handle safe area inset (fixed by ScrollView wrap).
- Sanity floor too high → smaller-mode measurements rejected.
- Sanity floor too low → pre-layout 0pt readings accepted, sheet flashes tiny.

## Proposed reusable scaffolding

Goal: collapse the six-piece recipe into one view modifier so every
sheet just declares "I hug my content."

### API sketch

```swift
extension View {
    /// Sizes the sheet's detent to the modified view's intrinsic
    /// content height. Use as a replacement for
    /// `.presentationDetents(...)` on sheet bodies.
    ///
    /// - Parameter minHeight: floor for measurement noise rejection.
    ///   Default 100pt covers typical pre-layout noise; raise if your
    ///   sheet's smallest valid content is taller than ~120pt and the
    ///   noise floor needs to discriminate.
    func intrinsicHeightSheet(minHeight: CGFloat = 100) -> some View {
        modifier(IntrinsicHeightSheetModifier(minHeight: minHeight))
    }
}

private struct IntrinsicHeightSheetModifier: ViewModifier {
    let minHeight: CGFloat
    @State private var measured: CGFloat = 100  // small seed, lets it grow

    func body(content: Content) -> some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: IntrinsicSheetHeightKey.self,
                            value: geo.size.height
                        )
                    }
                )
        }
        .scrollDisabled(true)
        .onPreferenceChange(IntrinsicSheetHeightKey.self) { h in
            let rounded = h.rounded()
            guard rounded > minHeight else { return }
            if abs(rounded - measured) > 1 { measured = rounded }
        }
        .presentationDetents([.height(measured)])
        .presentationDragIndicator(.hidden)
    }
}

private struct IntrinsicSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

Call site becomes:

```swift
struct EditHeightSheet: View {
    var body: some View {
        VStack(spacing: 0) { /* content */ }
            .intrinsicHeightSheet()
    }
}
```

### Trade-offs vs. current approach

**Wins:**
- One line per sheet instead of ~30 lines of scaffolding.
- New sheets can't forget the recipe — it's enforced by the modifier.
- Single place to fix iOS-version regressions.
- No more hand-tuned seeds (modifier defaults to small initial; iOS
  grows the sheet on first measurement).

**Costs:**
- **Always one frame of size flash** at presentation. The current
  per-sheet approach eliminates this for the common mode by hand-seeding.
  For multi-mode sheets (UpdateWeightSheet) we already accept the flash
  in the secondary mode, so this is only a regression for single-mode
  sheets.
- **Less control over the sanity floor.** Some sheets might want a
  higher floor; the modifier exposes `minHeight:` but it's one number,
  not e.g. a per-state floor.
- **Doesn't solve async content.** If the sheet loads data after present,
  the detent grows mid-flight. iOS handles this awkwardly. The modifier
  doesn't fix this — it just makes the awkwardness uniform.

### Multi-mode handling

For sheets where the seed needs to differ by mode (UpdateWeightSheet
add vs delete), two options:

1. **Pass the seed as a parameter:**
   `.intrinsicHeightSheet(initialEstimate: editingEntry == nil ? 420 : 230)`.
   Adds back some hand-tuning but keeps the rest of the recipe hidden.

2. **Skip the seed entirely** and accept the size flash in both modes.
   Acceptable if the flash is fast enough not to register visually.
   Worth user-testing before committing.

Recommendation: ship the modifier with `initialEstimate:` defaulted to
the `minHeight` floor, optional override for sheets that need it.

## When to actually build this

**Trigger condition: third or fourth fit-to-content sheet added to the codebase.**

Currently we have two: `UpdateWeightSheet` and `EditHeightSheet`. Two
copies of the recipe is annoying but not painful. Adding a third (e.g.
a future "edit profile photo" sheet, "edit break duration" sheet, etc.)
is the inflection point where copy-paste cost > extraction cost.

**Don't build it preemptively** because:
- iOS versions keep changing this behavior. The modifier we write today
  may need a rewrite for iOS 27/28.
- Each new sheet teaches us a new failure mode. Extracting too early
  means generalizing on incomplete data.
- The current copy-paste pattern is well-understood and easy to debug.

## Open questions for when we extract

1. **Should the modifier handle the X / title / save toolbar layout
   too?** Both current sheets share that pattern. Could be a separate
   `.sheetToolbar(title:onDismiss:onSave:)` modifier or part of the
   intrinsic-height one.
2. **How to test height correctness?** Manual visual verification only.
   Snapshot tests across iOS versions might catch regressions but are
   expensive to maintain.
3. **Async content** — should the modifier offer a way to "hold" the
   sheet at a placeholder height while content loads, then animate to
   measured height? Or punt to the call site?
4. **Apple shipping `.intrinsic` natively** — if/when this lands, the
   whole modifier should become a one-line passthrough or be deleted.
   Worth tracking WWDC release notes annually.

## Related Apple radars / forum threads

(Not yet filed. If this becomes a recurring pain, file a feedback for
`PresentationDetent.intrinsic` to Apple. Their existing API surface
strongly suggests they've considered it; lack of shipping it is likely
behavioral edge cases around safe areas, drag indicators, and animation.)
