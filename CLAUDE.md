# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Forge is a minimal native iOS app (SwiftUI, Swift 5) for tracking weightlifting workouts. No external dependencies — uses only system frameworks (SwiftUI, Combine, UIKit, UserNotifications, ActivityKit, WidgetKit, HealthKit, WatchConnectivity). Dark-mode only. Includes an Apple Watch companion app for break timer haptic alerts.

User flow: History screen → Plan Selector → Active Workout → back to History with the completed workout logged.

## Build, Run & Test

```bash
# Open in Xcode
open Forge.xcodeproj

# Command-line build
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Debug

# Release build
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Release

# Run unit tests (any iPhone simulator name works)
xcodebuild test -project Forge.xcodeproj -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- iOS deployment target: 18.6 (`Forge` and `ForgeWidgetsExtension` targets). watchOS deployment target: 11.0 (`ForgeWatch`). The `ForgeTests` target uses iOS 26.4 — Xcode's default for newly-created targets — which is fine because tests only run on the simulator.
- Bundle ID: `Ryan-Div.Forge`. Widget extension: `Ryan-Div.Forge.ForgeWidgets`. Watch app: `Ryan-Div.Forge.watchkitapp`. Test bundle: `Ryan-Div.ForgeTests`.
- Builds should be **warning-free**. If you introduce a deprecation warning, fix it in the same change.

## Architecture

**MVVM with SwiftUI EnvironmentObjects.** Five objects are injected at the app root (`ForgeApp.swift`):

- `CompletedWorkoutsViewModel` — workout history CRUD, date/time formatting
- `PlanViewModel` — workout plan CRUD, reordering, duration estimation, exercise transfer between plans
- `ExerciseViewModel` — active exercise state during editing
- `WorkoutHealthManager` — HealthKit authorization, live workout sessions (iOS 26+), manual workout saves
- `GlobalSettings.shared` — theming singleton (see below), also injected as `@EnvironmentObject` so views reactively update when the color theme changes

All ViewModels are `ObservableObject` with `@Published` properties, accessed in views via `@EnvironmentObject`.

**Persistence:** UserDefaults with JSON encoding/decoding (`Codable`). Keys: `"workoutPlans"`, `"completedWorkouts"`, `"breakDurationSeconds"`, `"colorTheme"`. `PlanViewModel` and `CompletedWorkoutsViewModel` accept an optional `userDefaults: UserDefaults = .standard` init parameter so tests can inject an isolated `UserDefaults(suiteName:)` — production code calls them with no arguments.

**Global theming:** `GlobalSettings.shared` singleton (`Forge/View Model/GlobalSettings.swift`) — an `ObservableObject` injected as `@EnvironmentObject` from `ForgeApp`. `fgColor` is a computed property derived from `@Published colorTheme: ColorTheme` (persisted to UserDefaults via a Combine sink — **not** `didSet`, which breaks `objectWillChange` on `@Published` properties). Six accent color themes: red (default, `#FF436B`), blue, green, orange, purple, yellow. Background `#161616`. All views reference `settings.fgColor` (not a local `let` copy) so the accent color updates reactively. Static layout constants: `darkGray` (0.25) for workout/history connectors, `editorDarkGray` (0.33) for editor labels, `buttonCircleBgColor`, `setButtonSize`, `setsFontSize`, `setsSpacing`, `bottomToolbarHeight`. `breakDuration` is a UserDefaults-backed computed property (default 60s, configurable 5–300s via in-workout picker).

## Data Models (`Forge/Data Model/`)

- `WorkoutPlan` → has `[Exercise]` → each has `[Set]` (weight, reps, tillFailure, completed). All `Identifiable + Codable` with UUID identifiers.
- `CompletedWorkout` — snapshot with date, elapsed time, completion percentage, optional `caloriesBurned: Double?` (nil for workouts without Apple Watch).
- `Exercise.sets` has a `didSet` observer that auto-computes `areSetsUnique` (via `doesExerciseHaveUniqueSets()`) and `completed` (true when every set is completed).
- `EditorMode.swift` — three enums replacing the old string-based mode flags: `PlanEditorMode` (`.add`/`.edit`), `ExerciseEditorMode` (`.add`/`.edit`/`.log`), `ReorderDeleteMode` (`.plan`/`.exercise`).
- `WorkoutActivityAttributes` — ActivityKit data contract for Live Activities. Static: `planName`. Dynamic `ContentState`: `percentCompleted`, `isResting`, `restEndDate`, `nextExerciseName`, `nextSetDescription`. Compiled into both `Forge` and `ForgeWidgetsExtension` targets.

## Key Views (`Forge/Views/`)

The two largest views were decomposed into focused child components. Parent views coordinate state and animation; children render specific subsystems.

| View | Lines | Purpose |
|------|---|---------|
| `CompletedWorkoutsView` | ~125 | Home screen — workout history list, settings gear icon in nav bar |
| `SettingsView` | ~95 | Color theme picker (6 accent colors) + per-plan "Reset Last Completed" |
| `SelectPlanView` | ~240 | Choose/manage workout plans — inline swipe-to-delete + drag-to-reorder via List |
| `PlanEditorView` | ~310 | Create/edit a plan and its exercises — inline reorder/delete + swipe-right transfer |
| `ExerciseEditorView` | ~410 | Add/edit exercises — coordinator only |
| `HomogeneousSetPicker` | ~200 | 3-column wheel pickers (sets × weight × reps) — used by ExerciseEditorView |
| `HeterogeneousSetEditor` | ~235 | Per-set rows with weight/reps/till-failure controls — used by ExerciseEditorView |
| `WorkoutInProgressView` | ~720 | Active workout — coordinator + Live Activity + HealthKit + stopwatch + break timer config |
| `StartingCountdownView` | ~100 | 3-second pre-workout countdown — self-contained |
| `BreakTimerView` | ~155 | Configurable rest timer (TimelineView-based) + notification + "Up Next" exercise/set info — used by WorkoutInProgressView |
| `WorkoutBottomToolbarView` | ~120 | Add / Done / Edit toolbar — used by WorkoutInProgressView |
| `SetView` | ~140 | Reusable set-row rendering — used by PlanEditorView, HistoryView, WorkoutInProgressView. Parameterized via `Content` (`.individual` / `.summary`) and `Appearance` (`.standard` / `.muted` / `.workoutActive(isCompleted:)`) enums. |
| `HistoryView` | ~200 | Read-only detail view of a past workout — stats row (calories, completion ring, duration) + Dismiss toolbar |
| `ReorderDeleteView` | ~100 | Reorder/delete sheet for plans or exercises |
| `BreakTimerWatchView` | ~110 | watchOS break timer — countdown ring + haptic on expiry (ForgeWatch target) |

## Live Activity & Widget Extension (`ForgeWidgets/`)

The `ForgeWidgetsExtension` target provides a Live Activity that shows workout progress on the Lock Screen and Dynamic Island while the app is backgrounded.

**Files:**
- `ForgeWidgetsBundle.swift` — `@main` widget bundle, registers `WorkoutLiveActivity`
- `WorkoutLiveActivity.swift` — `ActivityConfiguration` with Lock Screen view and Dynamic Island (compact + expanded)
- `WorkoutActivityAttributes.swift` — shared data contract (lives in `Forge/Data Model/`, compiled into both targets)

**Lock Screen banner** shows: plan name, % complete, countdown timer (when resting), and "Up next" exercise/set info.

**Dynamic Island compact:** leading icon switches between dumbbell (active) and timer (resting). Trailing shows `%` when active or a countdown via `Text(timerInterval:)` when resting — constrained to `frame(width: 36)` + `minimumScaleFactor(0.6)` to prevent the island from stretching.

**Dynamic Island expanded** (long-press): plan name, %, timer countdown (when resting), and next exercise/set info.

**Lifecycle hooks** in `WorkoutInProgressView`:
- `startLiveActivity()` — called after the 3-second countdown completes
- `updateLiveActivity()` — called on set completion, timer start (`breakTimerEndDate` set), and timer end (`breakTimerEndDate` cleared)
- `endLiveActivity()` — called in both `finishWorkout()` and `cancelWorkout()`

**Colors:** `GlobalSettings` is not compiled into the widget extension target. `WorkoutLiveActivity` defines its own `fgColor` locally. The `WidgetBackground` asset color is set to `#161616`.

## HealthKit Integration

**`WorkoutHealthManager`** (`Forge/View Model/WorkoutHealthManager.swift`) — injected as `@EnvironmentObject` from `ForgeApp`.

- **Authorization:** Requests write access to `HKObjectType.workoutType()` and read access to `activeEnergyBurned` + `heartRate` on app launch.
- **Live session (iOS 26+):** `startWorkoutSession()` creates an `HKWorkoutSession` + `HKLiveWorkoutBuilder` that collects heart rate and calorie data from Apple Watch during the workout. `endWorkoutSession(completion:)` ends the session, extracts calories from `workout.statistics(for: .activeEnergyBurned)`, and returns them via a completion handler. The Live Activity also surfaces on the Apple Watch automatically.
- **Calorie capture:** `endWorkoutSession` accepts an `@escaping (Double?) -> Void` completion handler (default `{ _ in }`). On iOS 26+, calories are extracted from the finished workout's statistics and dispatched on the main thread. `finishWorkout()` saves the `CompletedWorkout` immediately with nil calories, then patches the value in via the completion handler. `cancelWorkout()` passes the default empty handler since cancelled workouts aren't saved.
- **Manual save (fallback):** `saveWorkout(startDate:endDate:elapsedTime:)` uses `HKWorkoutBuilder` to save a `.functionalStrengthTraining` workout without a live session. Used when the live session fails to start or on iOS < 26.
- **Lifecycle:** Session starts after the 3-second countdown (alongside `startLiveActivity()`). On `finishWorkout()`, the live session is ended if active; otherwise falls back to manual save. On `cancelWorkout()`, the session is ended unconditionally.
- **Note:** `Swift.Set` must be used instead of `Set` when calling HealthKit APIs, because the project's `Set` data model type shadows Swift's built-in `Set`.

## Apple Watch Companion App (`ForgeWatch/`)

The `ForgeWatch` target is a standalone watchOS app that receives break timer state from the iPhone via WatchConnectivity and fires a haptic alert when the timer expires — solving the problem that iOS won't route notifications to the watch while the phone is in the foreground.

**Files:**
- `ForgeWatchApp.swift` — `@main` App struct, activates `WatchSessionManager` on init
- `WatchSessionManager.swift` — `WCSessionDelegate` singleton, receives messages from phone, manages `@Published timerState` (`.idle` / `.counting` / `.expired`)
- `BreakTimerWatchView.swift` — single SwiftUI view with three visual states (idle, countdown ring, "Start Next Set" prompt). Uses `TimelineView` for countdown (same pattern as iOS `BreakTimerView`)

**Phone side:**
- `PhoneSessionManager.swift` (`Forge/View Model/`) — `WCSessionDelegate` singleton, activated in `ForgeApp.init()`
- Three call sites in `WorkoutInProgressView`: timer starts → `sendTimerStarted()`, timer dismissed → `sendTimerDismissed()`, workout ends → `sendWorkoutEnded()`

**Message protocol (phone → watch):**
- `timerStarted` — carries `endDate` (TimeInterval), `duration` (Int), `exerciseName`, `setDescription`
- `timerDismissed` / `workoutEnded` — signals watch to return to idle state

**Dual delivery:** Each message is sent via both `sendMessage` (real-time when watch is reachable) and `updateApplicationContext` (guaranteed eventual delivery). The watch checks `receivedApplicationContext` on activation to catch messages sent while the app was suspended.

**Haptic:** `WKInterfaceDevice.current().play(.notification)` fires once when the countdown reaches zero or when a `timerStarted` message arrives with an already-past `endDate`.

## Timer & Notification System

- **Workout start countdown:** 3 seconds (skippable). Owned entirely by `StartingCountdownView` — signals completion via `onCompletion` callback.
- **Rest timer:** Configurable duration (5–300s, default 60s) between sets. Owned by `BreakTimerView`, which uses `TimelineView(.periodic(from:by:))` for countdown updates (immune to parent view re-renders, unlike `Timer.publish`) and schedules a `UNTimeIntervalNotificationTrigger` so the user is alerted even when the app is backgrounded. The parent `WorkoutInProgressView` retains the scroll-view shrink/grow animation state. Duration is configured via a timer icon button in the workout toolbar that opens a `BreakDurationPickerView` wheel picker.
- **Foreground suppression:** `AppDelegate.userNotificationCenter(_:willPresent:)` suppresses any notification with category `"workoutCategory"` while the app is active.

### Critical: notification cancellation race

`dismissBreakTimerView` takes a `cancelPendingNotification: Bool = true` parameter. The natural-expiry path (`onExpired`) **must** pass `false`. Otherwise, when the in-app timer ticks down to 0 it cancels the notification at the exact moment iOS is about to deliver it. This bug bites hardest when running from Xcode with the debugger attached, because the debugger keeps the app alive in background indefinitely — which means the in-app timer keeps running and racing the system delivery. The X-button and Done-button paths both pass `true` (cancellation desired). Notification identifier is exposed as `BreakTimerView.notificationIdentifier`.

## Navigation

Uses boolean `@Published` flags on ViewModels (e.g., `isSelectPlanViewActive`) combined with `NavigationStack` and `.fullScreenCover` / `.sheet`. View dismissals use `@Environment(\.dismiss)` (the modern API — never `presentationMode`).

## Testing

**Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest. Xcode 16's default for new test targets and the cleaner of the two.

**Target:** `ForgeTests/`. Uses Xcode 16's `PBXFileSystemSynchronizedRootGroup`, so any `.swift` file dropped into the directory is auto-detected — no `project.pbxproj` edits needed for new test files.

**43 test cases** across four files:
- `ExerciseTests.swift` — `doesExerciseHaveUniqueSets()` and `sets` didSet observer (8 cases)
- `PlanViewModelTests.swift` — `calculateWorkoutDuration`, `isThereNonZeroDecimal`, save/load round-trip, move/delete plan/exercise (12 cases)
- `CompletedWorkoutsViewModelTests.swift` — `format(timeInterval:)`, `numberOfDaysString`, persistence round-trip, reverse-index `deleteCompletedWorkouts` (13 cases)
- `ValidationTests.swift` — input validation: whitespace, empty, max length, normal strings (10 cases)

**Persistence isolation pattern:** test classes that touch persistence are `final class` (not `struct`) so `init` + `deinit` act as setUp/tearDown. Each test gets its own `UserDefaults(suiteName: "ForgeTests.\(UUID().uuidString)")` and removes the persistent domain in `deinit`. This isolates tests from each other and from `.standard`.

**Mock data:** `Forge/View Model/MockData.swift` exposes `mockWorkoutPlans` and `mockCompletedWorkouts` as module-internal globals. Tests access them via `@testable import Forge`. Production code also references one of these globals (`completedWorkout2`) from `CompletedWorkoutsViewModel.init(mockCompletedWorkouts:)` — a pre-existing code smell where production depends on mock data, used only by SwiftUI Previews.

## Subtle gotchas

- **Picker wheel `Int` tags need explicit `.tag(value)`.** SwiftUI's `WheelPickerStyle` historically had bugs binding to non-String selections. The current Int-based pickers in `HomogeneousSetPicker` and `HeterogeneousSetEditor` use explicit `.tag(value)` on every `ForEach` element. If you add a new wheel picker, replicate that pattern.
- **`heterogenousSetRowHeight = 1000000`** in `ExerciseEditorView`. Yes, one million. This is an intentional layout hack: `heterogenousSetMaxViewHeight = CGFloat((count*Int(heterogenousSetRowHeight))+80)` makes the height effectively unbounded so the inner `clipped()` + outer `frame(maxHeight:)` can grow without limit. Don't "fix" it.
- **`homoHeteroControlsAreConnected` and `editedExerciseStartedWithUniqueSets` flags** in `ExerciseEditorView` gate the data sync between homogeneous and heterogeneous picker state. The `onAppear` ordering matters — set the connected flag false, load data, then set it true. Otherwise the toggle's `onChange` fires during init and wipes the loaded data. The big comment block in the toggle's `onChange` handler explains the second flag.
- **`activeExerciseIndex` is stale in `.add` mode.** When the user adds a new exercise during a workout, `ExerciseViewModel.activeExerciseIndex` still points at whichever exercise they last logged or edited. `ExerciseEditorView.saveExercise()` gates its `existingExercise` lookup on the mode being `.edit` or `.log` — never trust `activeExerciseIndex` in `.add` mode. (Without this gate, new exercises inherit completion state from the previously-edited exercise.)
- **`Timer.publish` in child views breaks when parents re-render frequently.** `WorkoutInProgressView` updates `elapsedSeconds` every second via a stopwatch, causing all child views to re-render. `BreakTimerView` originally used `Timer.publish` which got recreated (and thus never fired) on each re-render. The fix was migrating to `TimelineView(.periodic(from:by:))` which SwiftUI manages internally and survives re-renders. If you add a new timer-based child view, use `TimelineView`, not `Timer.publish`.
- **`didSet` on `@Published` properties breaks `objectWillChange`.** Never use `didSet` (or `willSet`) on `@Published` properties — the compiler-generated setter bypasses the property wrapper's `objectWillChange.send()`, so SwiftUI views won't update. `GlobalSettings.colorTheme` uses a Combine `$colorTheme.dropFirst().sink(...)` subscriber for UserDefaults persistence instead.
- **`navigationBarTitleTextColor` must force-update existing bars.** `UINavigationBar.appearance()` only applies to newly created navigation bars. The extension in `CompletedWorkoutsView.swift` uses `.onChange(of: color)` to traverse all `UIWindowScene` windows and directly set `standardAppearance`/`scrollEdgeAppearance` on existing `UINavigationBar` instances (via `.copy()` + reassign to trigger UIKit change detection).
- **Multiple `Button`s in a single `List` row require `.buttonStyle(.borderless)`.** Without it, SwiftUI's List treats the entire row as one tappable area and fires the last button's action regardless of where the user taps.
- **`UIScreen.main.bounds`** is used in 3 views for fixed-fraction layout (`0.33 * screenWidth` etc). It's deprecated in iOS 16+ in favor of `view.window.windowScene.screen`, but doesn't currently emit a warning at our deployment target. Migrating would require `GeometryReader` or environment-based screen access — out of scope for "polish" work.

## Refactor history

The codebase went through a 7-stage refactor (see git log for `Stage N` commits):

1. String modes → enums (`EditorMode.swift`)
2. Magic values consolidated into `GlobalSettings`
3. Set-row rendering consolidated into `SetView`; dead `containsUniqueSets()` removed
4. `WorkoutInProgressView` decomposed into 4 focused files (parent shrunk 825 → 452 lines)
5. `ExerciseEditorView` decomposed + picker state migrated `String → Int` (parent shrunk 852 → 407 lines, ~20 `dropLast` parses eliminated)
6. `ForgeTests` target + 33 Swift Testing unit cases + injectable `UserDefaults`
7. Deprecated APIs replaced (`presentationMode → dismiss`, `.onChange` two-parameter form, `.alert → .banner/.list`); dead stopwatch scaffolding removed
8. Live Activity added — Lock Screen banner, Dynamic Island (compact + expanded), break timer integration via `ForgeWidgetsExtension`
9. Inline reorder/delete for plans (SelectPlanView) and exercises (PlanEditorView) — converted from ScrollView to List with swipe actions and edit mode toggle. Added swipe-right exercise transfer between plans.
10. Configurable break timer (5–300s) with UserDefaults persistence + wheel picker UI. BreakTimerView migrated from `Timer.publish` to `TimelineView` to survive parent re-renders.
11. HealthKit integration — completed workouts saved as Functional Strength Training. Live `HKWorkoutSession` on iOS 26+ with Apple Watch data collection.
12. Dark mode enforcement — `UIUserInterfaceStyle=Dark` in Info.plist, adaptive system colors replaced with fixed dark values, Liquid Glass sheet backgrounds.
13. HealthKit calorie capture — `endWorkoutSession` returns calories via completion handler, `CompletedWorkout.caloriesBurned` field, HistoryView stats row (calories/completion ring/duration), break timer "Up Next" display.
14. Apple Watch companion app — `ForgeWatch` watchOS target with WatchConnectivity. Phone sends break timer state to watch; watch shows countdown ring and fires haptic on expiry. `PhoneSessionManager` (phone) and `WatchSessionManager` (watch) singletons with dual `sendMessage` + `updateApplicationContext` delivery.
15. Settings view with color theme selector (6 accent colors persisted via UserDefaults). `GlobalSettings` converted to `ObservableObject`; all views use `@EnvironmentObject var settings: GlobalSettings` with `settings.fgColor` instead of static `let` copies. Navigation bar title color updates live via `onChange` + UINavigationBar hierarchy traversal. Static `Image("Checkmark")` assets replaced with SF Symbol `Image(systemName: "checkmark")`. Per-plan "Reset Last Completed" feature in Settings.

## Git usage

- Do not credit yourself as a co-author when creating commit messages.
- Do not perform any git commands unless explicitly asked in the most recent prompt to perform a git-related task. Git commands that are related to the task you are asked to perform in the most recent prompt are, of course, okay to use

## Error Handling Philosophy: Fail Loud, Never Fake

Prefer a visible failure over a silent fallback.

- Never silently swallow errors to keep things "working." Surface the error. Don't substitute placeholder data.
- Fallbacks are acceptable only when disclosed. Show a banner, log a warning, annotate the output.
- Design for debuggability, not cosmetic stability.

Priority order:
1. Works correctly with real data
2. Falls back visibly — clearly signals degraded mode
3. Fails with a clear error message
4. Silently degrades to look "fine" ← never do this

Never build automated testing that finds shortcuts that deliver a pass result. Passed test results must always be due to genuine correctly functioning code.
