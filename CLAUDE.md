# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Forge is a minimal native iOS app (SwiftUI, Swift 5) for tracking weightlifting workouts. No external dependencies — uses only system frameworks (SwiftUI, Combine, UIKit, UserNotifications). Dark-mode only.

User flow: History screen → Plan Selector → Active Workout → back to History with completed workout logged.

## Build & Run

```bash
# Open in Xcode
open Forge.xcodeproj

# Command-line build
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Debug

# Release build
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Release
```

- iOS deployment target: 18.6
- Bundle ID: `Ryan-Div.Forge`
- No unit test target (XCTest). Testing is done via Playgrounds in `Forge/Testing/` and inline playground files.

## Architecture

**MVVM with SwiftUI EnvironmentObjects.** Three ViewModels are injected at the app root (`ForgeApp.swift`):

- `CompletedWorkoutsViewModel` — workout history CRUD, date/time formatting
- `PlanViewModel` — workout plan CRUD, reordering, duration estimation
- `ExerciseViewModel` — active exercise state during editing

All ViewModels are `ObservableObject` with `@Published` properties, accessed in views via `@EnvironmentObject`.

**Persistence:** UserDefaults with JSON encoding/decoding (`Codable`). Keys: `"workoutPlans"`, `"completedWorkouts"`.

**Global theming:** `GlobalSettings.shared` singleton — accent color `#FF436B`, background `#161616`.

## Data Models (`Forge/Data Model/`)

`WorkoutPlan` → has `[Exercise]` → each has `[Set]` (weight, reps, tillFailure, completed).  
`CompletedWorkout` — snapshot with date, elapsed time, completion percentage.

All models are `Identifiable` + `Codable` with UUID identifiers.

## Key Views (`Forge/Views/`)

| View | Purpose |
|------|---------|
| `CompletedWorkoutsView` | Home screen — workout history list |
| `SelectPlanView` | Choose/manage workout plans |
| `PlanEditorView` | Create/edit a plan and its exercises |
| `ExerciseEditorView` | Add/edit exercises with picker wheels (845 lines, complex) |
| `WorkoutInProgressView` | Active workout — timers, set completion, notifications (851 lines, most complex) |
| `HistoryView` | Read-only detail view of a past workout |

## Timer & Notification System

- **Workout start timer:** 3 seconds (skippable)
- **Rest timer:** 60 seconds between sets, triggers local notification via `UNUserNotificationCenter`
- **Stopwatch:** `Timer.publish` for elapsed workout time
- Notifications suppressed in foreground via `AppDelegate` (`userNotificationCenter(_:willPresent:)`)

## Navigation

Uses boolean `@Published` flags on ViewModels (e.g., `isSelectPlanViewActive`, `activePlanMode`) combined with `NavigationStack`. Mode strings: `"AddMode"`, `"EditMode"`.

## Refactor Plan

7-stage refactor plan, each stage independently shippable and testable. Ordered by priority.

### Stage 1: Replace Stringly-Typed State with Enums
Create `Forge/Data Model/EditorMode.swift` with `PlanEditorMode` (.add/.edit), `ExerciseEditorMode` (.add/.edit/.log), `ReorderDeleteMode` (.plan/.exercise). Replace all `String` mode properties and comparisons across ViewModels and Views. Compiler enforces correctness.

**Files:** `PlanViewModel.swift`, `ExerciseViewModel.swift`, `ReorderDeleteView.swift`, `SelectPlanView.swift`, `PlanEditorView.swift`, `ExerciseEditorView.swift`, `WorkoutInProgressView.swift`
**Test:** All mode-dependent flows (create/edit plan, add/edit/log exercise, reorder plans vs exercises)
**Risk:** Low

### Stage 2: Consolidate Magic Values into GlobalSettings
Add to `GlobalSettings`: `darkGray` (0.25), `editorDarkGray` (0.33), `buttonCircleBgColor` (0.2), `setsSpacing`, `setButtonSize`, `breakDuration = 60`, `setRowFontSize = 20`. Remove local redeclarations from all views.

**Files:** `GlobalSettings.swift`, all Views
**Test:** Visual identity on every screen — no color/size/spacing changes
**Risk:** Low

### Stage 3: Consolidate Set-Row Rendering + Remove Dead Code
Refactor `SetView` to accept `Set` data directly (remove EnvironmentObject dependency). Add `SetRowDisplayMode` for visual variants. Replace inline set-row rendering in `PlanEditorView`, `HistoryView`, `WorkoutInProgressView`. Delete dead `ExerciseViewModel.containsUniqueSets()`.

**Files:** `SetView.swift`, `PlanEditorView.swift`, `HistoryView.swift`, `WorkoutInProgressView.swift`, `ExerciseViewModel.swift`
**Test:** Pixel-accurate set rows across all screens (unique sets, uniform sets, completed/incomplete, history view muted style)
**Risk:** Medium

### Stage 4: Decompose WorkoutInProgressView (851→~250 lines)
Extract `StartingCountdownView` (countdown timer), `BreakTimerView` (rest timer + notification), `WorkoutToolbarView` (Add/Done/Reorder bar). Parent keeps exercise list, animation coordination, and set-completion handler.

**Files:** Create 3 new Views, reduce `WorkoutInProgressView.swift`
**Test:** Full workout flow — countdown, set completion, break timer (auto-dismiss + manual dismiss), background/foreground timer sync, notifications, Done flow
**Risk:** High

### Stage 5: Decompose ExerciseEditorView (845→~200 lines)
Replace string picker state ("5 lbs") with typed `Int` state. Extract `HomogeneousSetPicker` (wheel pickers) and `HeterogeneousSetEditor` (per-set rows). Eliminates all `dropLast` string parsing.

**Files:** Create 2 new Views, reduce `ExerciseEditorView.swift`
**Test:** Add/edit/log exercises, homo↔hetero toggle, boundary clamping, picker selection, set completion preservation
**Risk:** Medium-High

### Stage 6: Add XCTest Target and Unit Tests
Create `ForgeTests` target. Test: `Exercise.doesExerciseHaveUniqueSets()`, `calculateWorkoutDuration()`, `isThereNonZeroDecimal()`, `format(timeInterval:)`, `numberOfDaysString()`, save/load round-trips. Make UserDefaults injectable in ViewModels.

**Test:** `xcodebuild test` — all tests pass
**Risk:** Low

### Stage 7: Update Deprecated APIs
Replace `@Environment(\.presentationMode)` with `@Environment(\.dismiss)` in 5 views. Update `.onChange(of:)` to new two-parameter signature in ExerciseEditorView.

**Files:** All views using `presentationMode`
**Test:** Zero deprecation warnings, all dismiss actions work
**Risk:** Low

#### Git usage

Do not credit yourself as a co-author when creating commits messages.
