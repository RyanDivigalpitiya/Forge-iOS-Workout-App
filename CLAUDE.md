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
- `PlanTransferType.swift` — `UTType.forgePlan` (exported UTI `Ryan-Div.Forge.workoutPlan`) + `WorkoutPlan: Transferable` via `FileRepresentation`. Also exposes `WorkoutPlan.sharePreviewImage` — a pre-rendered `UIImage` of `dumbbell.fill` (handing `Image(systemName:)` to `SharePreview` renders blank).

## Key Views (`Forge/Views/`)

The two largest views were decomposed into focused child components. Parent views coordinate state and animation; children render specific subsystems.

| View | Lines | Purpose |
|------|---|---------|
| `CompletedWorkoutsView` | ~125 | Home screen — workout history list, settings gear icon in nav bar |
| `SettingsView` | ~95 | Color theme picker (6 accent colors) + per-plan "Reset Last Completed" |
| `SelectPlanView` | ~250 | Choose/manage workout plans — swipe-right to share `.forgeplan`, swipe-left to delete, drag-to-reorder via List |
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
| `WorkoutWithFriendView` | ~80 | Collab — Copy Link / Share Link buttons that generate a `forge://session/<id>` URL |
| `ConnectingView` | ~75 | Collab — state-driven "Connecting… / Waiting for friend… / Connected." screen, auto-advances to JoinSession |
| `JoinSessionView` | ~190 | Collab — name + photo picker, peer-profile banner, "Join Session →"; auto-submits cached profile when rejoining an active workout (Stage 7b') |
| `PlanSuggestionView` | ~470 | Collab — plan carousel + Suggest/Preview + chat (UIKit-backed `KeyboardPersistentTextField`) + Ready button + auto-route into the active workout when `workoutInProgress` is set (Stage 7b') |
| `CollabStatusBanner` | ~95 | Collab — capsule overlay shown on PlanSuggestionView + WorkoutInProgressView when state is non-healthy. In `.waitingForPeer` includes a "Re-invite" button that share-sheets the current sessionId URL (Stage 7b) |

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

## Plan Sharing (`.forgeplan` files)

Users share workout plans device-to-device via the iOS share sheet (AirDrop / Messages / Mail / Save to Files). Plans travel as `.forgeplan` files — JSON-encoded `WorkoutPlan`s under a custom exported UTType.

**Files:**
- `Forge/Data Model/PlanTransferType.swift` — defines `UTType.forgePlan` + `WorkoutPlan: Transferable` via `FileRepresentation`. Exports a temp file named after the plan; decodes the file back into a `WorkoutPlan` on import.
- `Forge/Info.plist` — `UTExportedTypeDeclarations` (makes the UTI known) + `CFBundleDocumentTypes` with `LSHandlerRank=Owner` (claims `.forgeplan` files for Forge). `LSSupportsOpeningDocumentsInPlace=false` — Forge always copies to its own library rather than editing the source file.
- `Forge/Views/SelectPlanView.swift` — leading-edge `.swipeActions` with a blue `ShareLink(item: plan)` button.
- `Forge/View Model/PlanViewModel.swift` — `importPlan(_:)` is the single funnel for incoming plans. Strips `completed` flags on every set, clears `lastCompleted` (shared plans are templates, not snapshots), and auto-suffixes name collisions with `" (Imported)"` / `" (Imported) 2"` / ...
- `Forge/Views/CompletedWorkoutsView.swift` — `.onOpenURL` decodes incoming `.forgeplan` files and routes them through `planViewModel.importPlan(_:)`.

**SharePreview icon caveat:** `Image(systemName:)` handed directly to `SharePreview` renders blank in the share-sheet thumbnail. `WorkoutPlan.sharePreviewImage` pre-renders `dumbbell.fill` to a 160pt `UIImage` tinted Forge-red so the preview shows an actual icon.

**Info.plist setup:** The Forge target uses `GENERATE_INFOPLIST_FILE=YES` with the `INFOPLIST_KEY_*` pattern for most values, but array-of-dictionary entries (document types, UTI declarations, URL schemes) can't be expressed as build settings — they need a real plist file. `Forge/Info.plist` contains only those entries (`CFBundleDocumentTypes` + `UTExportedTypeDeclarations` for `.forgeplan`, and `CFBundleURLTypes` for the collab feature's `forge://` scheme); `INFOPLIST_FILE = Forge/Info.plist` in both Debug/Release configs tells Xcode to merge the `INFOPLIST_KEY_*` values on top. If you add another array-of-dict Info.plist key later, extend this file — don't flip back to pure build-settings generation.

## Collaborative Workout Feature (In Progress)

Two friends each running Forge can join a shared, real-time workout session. Person 1 taps **Add Friend** (`person.2.fill` in the History nav bar) → `WorkoutWithFriendView` → **Copy Link** or **Share Link**, which generates a `forge://session/<uuid>` URL. Person 2 taps the link (AirDrop/Messages/Mail/any app that recognises URLs); Forge opens and auto-joins. Once paired they'll (eventually) see each other's set completions, break timers, and profile avatars during the workout, and can chat while selecting a plan.

**Stack:** self-hosted Swift server in `server/` (separate SwiftPM package, lives alongside the iOS project in the same git repo) running on the user's Mac mini. Public HTTPS exposure via Cloudflare Quick Tunnel (`*.trycloudflare.com`). Single WebSocket per client carries all real-time state and, in later stages, chat. Server holds session state in memory — no database.

### Stage roadmap

| # | Goal | Status |
|---|------|--------|
| 0 | Plumbing spike — iOS → Cloudflare Tunnel → Hummingbird echo | done (replaced by Stage 1) |
| 1 | Session pairing — Add Friend → link → Connecting → Connected. Includes scenePhase-driven auto-reconnect and server-side lazy-create so backgrounded phones can revive sessions. | **DONE** |
| 2 | Profile + Join Session view — name (required) + optional photo, persisted to UserDefaults, exchanged over the socket | **DONE** |
| 3 | Plan Suggestion view — horizontal plan carousel with Suggest/Preview (reuses `PlanEditorView` in read-only or editable mode), header with plan name + X end-session button, bounce animation on suggestion change, dot indicators below carousel | **DONE** |
| 4 | Chat over the same WebSocket + in-panel TextField with UIKit wrapper (so Send key doesn't dismiss keyboard and QuickType bar stays hidden) + scroll-dismisses-keyboard + auto-scroll on keyboard show | **DONE** |
| 5 | Ready flag + immediate server-signalled workout start (collab layer dropped its own 3-sec countdown; `WorkoutInProgressView`'s existing `StartingCountdownView` handles the pre-workout buffer) | **DONE** |
| 6a | Dual per-row set-completion checkboxes (grey = peer, red = self) + set-completion sync over the WebSocket | **DONE** |
| 6b | Avatar column with right-arrow indicators positioned next to each participant's current set or rest-break row + position sync | **DONE** |
| 6c | Break-timer sync (peer's parallel countdown banner) + cross-phone position-change animations | **DONE** |
| 6d (post-6c polish) | Avatar position rewrite: explicit `@State` + `recomputeMyPosition()` single-rule (first-incomplete + rest-row adjustment) + anchor-preference gutter geometry (immune to wrap) + `SetView.workoutActiveCollab` chip layout for narrow joint-mode rows | **DONE** |
| 7a | Client-side WebSocket heartbeat (URLSessionWebSocketTask.sendPing every 30s) + auto-reconnect on `.disconnected` with exponential backoff (2/4/8/16/32s, capped). Hummingbird's autoPing was already on at 30s but iOS wasn't pinging. | **DONE** |
| 7b | Peer-disconnect status banner (`CollabStatusBanner`) with in-banner "Re-invite" button that share-sheets the current sessionId URL — recovery without ending the session | **DONE** |
| 7b' | Mid-workout rejoin handling: server tracks `workoutInProgress: PlanSnapshot?` on the session, includes it in welcome; iOS `JoinSessionView` auto-submits cached profile; `PlanSuggestionView` auto-routes into `WorkoutInProgressView` with the active plan instead of letting the rejoiner re-suggest and stomp the partner's workout | **DONE** |
| 7c | Cloudflare Named Tunnel on `forge-ws.ryan-div.com` + launchd plists for ForgeServer + cloudflared auto-start on Mac mini boot | **current focus** |

### Current focus — Stage 7c

Cloudflare Named Tunnel + launchd auto-start. Pure infrastructure — no behavioral change. Steps:

1. **Named tunnel** on the Mac mini:
   ```bash
   cloudflared tunnel login                    # one-time, opens browser
   cloudflared tunnel create forge-ws          # outputs tunnel ID
   cloudflared tunnel route dns forge-ws forge-ws.ryan-div.com
   # Write ~/.cloudflared/config.yml with tunnel id, credentials path,
   # ingress hostname → http://localhost:8080.
   cloudflared tunnel run forge-ws             # test in tmux
   ```
2. **iOS host swap** — change `SessionClient.serverHost` to `forge-ws.ryan-div.com`. One-line commit.
3. **Launchd plists** at `~/Library/LaunchAgents/com.ryandiv.forgeserver.plist` and `com.ryandiv.forgeserver-tunnel.plist` for auto-start on boot. `RunAtLoad + KeepAlive`. Optionally commit copies into `server/launchd/` for repo-tracked reference.

Once 7c lands, the collab feature is "done" for v1: idle-resilient connection, recoverable peer disconnects, mid-workout re-invite, and a permanent server URL that survives Mac mini reboots. Identity continuity across reconnect (server still issues fresh `myId` on rejoin) is intentionally deferred.

### File map

**Server (`server/`):**
- `Package.swift` — Hummingbird 2 + HummingbirdWebSocket deps
- `Sources/ForgeServer/main.swift` — top-level async entry (file is literally `main.swift`, so no `@main` struct; see gotcha below)
- `Sources/ForgeServer/Application+build.swift` — HTTP `/` health + `WS /sessions/:id` upgrade + per-connection task group (inbound reader + outbound stream drain). On `setReady`'s just-became-all-ready transition, broadcasts `startWorkout` AND the SessionManager records `workoutInProgress = current suggestedPlan` so re-joiners can be routed back into the active workout.
- `Sources/ForgeServer/Protocol.swift` — `ServerMessage` / `ClientMessage` enums + `Profile` / `PeerInfo` / `PlanSnapshot` / `ExerciseSnapshot` / `SetSnapshot` value types. All Codable + Sendable. `welcome` carries `suggestedPlan` AND `workoutInProgress`. Incompatible-upgrade territory: every protocol change requires both server redeploy and app rebuild in lockstep.
- `Sources/ForgeServer/SessionManager.swift` — actor holding `[UUID: Session]`; lazy-creates sessions on first `addParticipant`; deletes when empty. Capacity = 2. Per-session state: `suggestedPlan: PlanSnapshot?`, `workoutInProgress: PlanSnapshot?` (set as a side effect of `setReady`'s just-became-all-ready transition; persists for session lifetime), per-participant `isReady: Bool`. Server returns `true` from `setReady` when both phones just hit ready so the caller can broadcast `startWorkout` immediately (no authoritative countdown — `WorkoutInProgressView` handles that locally with `StartingCountdownView`). Hummingbird's autoPing default of 30s is implicitly enabled — server-side WebSocket keepalive needs no per-call code.

**iOS (Forge target):**
- `Forge/View Model/SessionClient.swift` — `@MainActor` ObservableObject. Methods: `createSession()` / `joinSession(id:)` / `reconnect()` / `disconnect()` / `submitProfile(_:)` / `suggestPlan(from: WorkoutPlan)` / `sendChat(text:)` / `toggleReady()` / `sendSetCompletion(...)` / `sendPositionUpdate(_:)` / `sendBreakTimerUpdate(...)`. Mirrors wire types (`Profile`, `PeerInfo`, `PlanSnapshot`, `ChatEntry`, `PeerSetKey`, `UserPosition`, `PeerBreakTimer`). `@Published` session-scoped state: `peerProfiles`, `suggestedPlan`, `chatEntries`, `peerReady`, `startWorkoutSignal`, `peerCompletedSets`, `peerPositions`, `peerBreakTimer`, `workoutInProgress`. Owned by `CompletedWorkoutsView` as `@StateObject` — deliberately NOT on `ForgeApp` — and **injected at the NavigationStack root** via `.environmentObject(sessionClient)` so every nav destination AND every modal presented from within them (e.g. SelectPlanView's `.fullScreenCover` into WorkoutInProgressView) inherits it. **Heartbeat**: `pingTask` runs alongside `receiveLoop`, calling `URLSessionWebSocketTask.sendPing` every 30s; pong-error cancels the task → readLoop throws → state becomes `.disconnected`. **Auto-reconnect**: a Combine sink on `$state.zip($state.dropFirst())` schedules `reconnect()` on every transition into `.disconnected` with active `sessionId`, with exponential backoff (2/4/8/16/32s capped). Counter resets on `.welcome`. Both `reconnect()` AND the `peerLeft` handler clear `peerPositions` / `peerBreakTimer` / `peerReady` for the leaving/replaced UUID so stale entries don't render as ghost "?" avatars. On `.welcome` auto-resends profile if `hasSubmittedProfile`. `PlanSnapshot.toWorkoutPlan()` preserves UUIDs on the plan and each exercise.
- `Forge/Views/Collab/` (synchronized group) — one file per view now:
  - `WorkoutWithFriendView.swift` — Copy/Share Link buttons
  - `ConnectingView.swift` — state-driven banner, auto-advances to `JoinSessionView`
  - `JoinSessionView.swift` — name + `PhotosPicker` + peer banner. `autoSubmitIfRejoiningActiveWorkout()` fires on appear AND on `.onChange(of: workoutInProgress?.id)`: when the server reports a workout is active and the user has a cached profile, auto-submits to skip the manual "Join Session →" tap during a mid-workout rejoin.
  - `PlanSuggestionView.swift` — carousel + chat + Ready buttons + `KeyboardPersistentTextField` (UIViewRepresentable wrapping UITextField) + single `.fullScreenCover(item:)` driven by an enum that covers both `PlanEditorView` (preview) and `WorkoutInProgressView` (post-ready hand-off). `routeIntoActiveWorkoutIfNeeded()` fires on appear AND on `.onChange(of: workoutInProgress?.id)`: when `sessionClient.workoutInProgress` is non-nil, immediately presents the workout cover with that plan as `activePlan` — re-joiner skips the suggest/Ready surface so they can't broadcast a fresh `startWorkout` and stomp the partner's active workout.
  - `CollabStatusBanner.swift` — capsule overlay reading `sessionClient.state`. Hidden when `.connected`/`.idle`; shows context-appropriate text (+ spinner) for `.connecting`/`.disconnected`/`.error`/`.waitingForPeer`. In `.waitingForPeer`, includes a "Re-invite" button that share-sheets `sessionClient.shareLinkURL()` (the EXISTING sessionId — does NOT call `createSession()`). Embedded as `.overlay(alignment: .top)` on PlanSuggestionView and WorkoutInProgressView.
  - `PlanCarouselCard.swift`, `PlanInfoBlock.swift` — shared plan-display pieces
  - `CollabHelpers.swift` — `avatar`/`initial`/`resizeImage` free functions, `ShareSheet`, `ShareableURL`
- `Forge/Views/History/CompletedWorkoutsView.swift` — Add Friend toolbar button (`person.2.fill`, top-leading), `forge://session/<id>` routing in `.onOpenURL`, `.onChange(of: scenePhase)` → `sessionClient.reconnect()` when the app returns to `.active`, `.onChange(of: sessionClient.state)` → resets both collab `navigationDestination` flags when state becomes `.idle` (so End Session anywhere in the stack collapses back to History). The `NavigationStack` is closed by `.environmentObject(sessionClient)` so all descendants inherit it without per-destination re-injection.
- `Forge/Views/Workout/WorkoutInProgressView.swift` — gains `@EnvironmentObject var sessionClient: SessionClient`. In joint mode (`sessionClient.state == .connected`) each per-exercise card is wrapped in an HStack with an empty `Color.clear.frame(width: gutterWidth)` placeholder on the leading edge; an `.overlayPreferenceValue(RowAnchorKey.self)` reads each set/rest row's bounds anchor (published via `.anchorPreference`) and absolutely positions one `avatarColumn` per row at its measured midY. **No hardcoded row offsets** — wrap-resilient. `myPosition` is `@State` (not derived); `recomputeMyPosition()` applies a single rule: position = first-incomplete-set, with a rest-row adjustment when an active break timer's source set immediately precedes it. Called on every set tap, every break-timer dismiss, and workout start. `restingForSet: RestingSet?` tracks which set's break is running. Set toggle broadcasts `sendSetCompletion`; `.onChange(of: myPosition)` broadcasts `sendPositionUpdate`; `.onChange(of: sessionClient.state)` to `.connected` calls `rebroadcastJointStateForPeer()` which re-pushes my position + every completed set + active break-timer state — so a freshly-(re)paired peer sees my full state without waiting for my next action.
- `Forge/Views/Shared/SetView.swift` — `Appearance` enum has a `.workoutActiveCollab(isCompleted:)` case for joint-mode rows, used when `sessionClient.state == .connected`. Renders weight/reps as a single grey chip (e.g. `100 lb x 12 reps`) with `.lineLimit(1)` so the compressed horizontal budget on small phones still fits. Set # label drops to 13pt + a narrower 46/54pt frame to match.
- `Forge/Info.plist` — `CFBundleURLTypes` registers `forge://` scheme alongside existing `.forgeplan` document types.

### Running the server

On the Mac mini (which hosts the server 24/7):

```bash
cd server
swift build                                          # first time: ~2 min
swift run ForgeServer                                # binds 127.0.0.1:8080
# In a second terminal, left running alongside:
cloudflared tunnel --url http://localhost:8080       # prints a trycloudflare.com URL
```

The iOS client hardcodes the hostname in `SessionClient.serverHost`. **`cloudflared` can stay up indefinitely; `ForgeServer` can be killed + restarted without changing the tunnel URL.** If `cloudflared` itself is restarted, the Quick Tunnel URL changes and the constant must be updated + the app rebuilt. Stage 7 migrates to a Named Tunnel on `forge-ws.ryan-div.com` for a permanent URL and adds a launchd plist at `~/Library/LaunchAgents/com.ryandiv.forgeserver.plist` so the server auto-starts on boot.

### Feature-specific gotchas

- **iOS backgrounding kills WebSockets within seconds.** Copy-Link-via-iMessage exposed this: Phone 1 backgrounds to paste the link, socket dies. Two mitigations coexist and neither alone suffices: (a) **server lazy-creates sessions** on first WS connect, so a returning Phone 1 (or a Phone 2 arriving later) always materialises the session for its ID; (b) **client auto-reconnects** via `.onChange(of: scenePhase)` at `CompletedWorkoutsView` level, calling `SessionClient.reconnect()` whenever the app returns to `.active`.
- **`SessionClient.disconnect()` clears `sessionId`; the read-loop error path does NOT.** This split is load-bearing for reconnect — if sessionId were cleared on socket error, there'd be no way to know what to rejoin. `disconnect()` is user-initiated (Cancel button in `ConnectingView`). Socket failures surface as `state = .disconnected(reason:)` with sessionId intact.
- **Hummingbird 2 `onUpgrade` context lacks `.parameters`.** Only the `shouldUpgrade` closure's context has route params. In `onUpgrade`, parse from `context.request.uri.path.split(separator: "/").last` (or equivalent).
- **Reconnect gets a new `myId` from the server.** The server assigns a fresh UUID on each WebSocket connection, so the peer briefly sees `peerLeft → peerJoined` during a reconnect. Stage 2+ will need identity continuity: client sends its last-known `myId` (+ profile) on rejoin so the server can merge the slot.
- **`main.swift` in Swift cannot contain `@main`.** The filename itself makes it the entry point, conflicting with the attribute. Use top-level async code (what `server/Sources/ForgeServer/main.swift` does) or rename the file.
- **Cloudflare Quick Tunnel URL is ephemeral per `cloudflared` invocation.** Survives `ForgeServer` restarts but not `cloudflared` restarts. Treat as session-scoped during development.
- **Hummingbird's default `maxFrameSize` is 16 KB.** Profile photos push messages well past that. `inbound.messages(maxSize:)`'s parameter is the reassembled-*message* cap, NOT the per-frame cap. The per-frame limit comes from `WebSocketServerConfiguration.maxFrameSize` and must be raised explicitly: `.init(maxFrameSize: 1 << 20, extensions: [.perMessageDeflate()])`. Without this, oversized frames cause Hummingbird to close the connection at the protocol layer *before* the onUpgrade handler sees anything, so the iOS client reports a successful send and then "Socket is not connected" a moment later with no server-side trace. Diagnosed in Stage 2 when 87 KB profile payloads silently vanished.
- **`UIGraphicsImageRenderer` uses `UIScreen.main.scale` by default.** A "256 × 192 pt" request on a 3× Retina iPhone produces 768 × 576 backing pixels — 9× the intended pixel count, 3× the wire size. For wire-transport rendering (profile photos), force `format.scale = 1.0` on a `UIGraphicsImageRendererFormat` and pass it to the renderer. The Stage 2 `resizeImage` helper in `CollabViews.swift` does this.
- **Collab navigation unwinds via state observer, not chained `dismiss()` calls.** `CompletedWorkoutsView` watches `sessionClient.state`; when it becomes `.idle`, it resets both `workoutWithFriendActive` and `joinerConnectingActive` to `false`, which collapses the entire collab stack in one step regardless of how deep the user was. Deep views like `PlanSuggestionView` only need to call `sessionClient.disconnect()` — no `dismiss()` chain, no shared navigation path binding.
- **Two `.fullScreenCover(isPresented:)` on the same view silently conflict** — only the first attaches, the second is ignored by SwiftUI with no warning. When a view needs to drive more than one full-screen cover (as in `PlanSuggestionView`, which presents both `PlanEditorView` for preview and `WorkoutInProgressView` for the post-ready hand-off), use a single `.fullScreenCover(item:)` driven by an `Identifiable` enum. Diagnosed in Stage 5 when the workout-start navigation silently did nothing.
- **`PlanSnapshot.toWorkoutPlan()` must preserve UUIDs on the plan + each exercise**, or joint-mode set-completion sync can't address the same row across phones. `Exercise.init(name:sets:)` and `WorkoutPlan.init(name:exercises:)` both generate fresh UUIDs — our extension explicitly copies `id` from the snapshot after construction. Set positions use positional index within an exercise (`SetSnapshot` has no id field), so Stage 6 keys off `(exerciseId: UUID, setIndex: Int)`.
- **SwiftUI's TextField with `.submitLabel(.send)` + `.onSubmit` always dismisses the keyboard before the handler fires**, causing a visible flicker even if `@FocusState` is immediately re-asserted in the handler. `KeyboardPersistentTextField` in `PlanSuggestionView.swift` is a `UIViewRepresentable` wrapping `UITextField`; its `textFieldShouldReturn` delegate method calls the submit closure and returns `false`, which keeps first-responder and therefore the keyboard. As a bonus, `autocorrectionType = .no` + `spellCheckingType = .no` at the UIKit level is the reliable way to suppress the QuickType predictive bar — SwiftUI's `.autocorrectionDisabled()` is inconsistent about it.
- **iOS QuickPath candidate ribbon is NOT app-disableable.** The ribbon that appears above the keyboard during an active swipe-to-type gesture is drawn by the system keyboard itself and isn't governed by any `UITextInputTraits` setting we can set on the field. Only Settings → General → Keyboard → Slide to Type (device-level, user-controlled) turns it off. Different from the persistent QuickType predictive bar, which `autocorrectionType = .no` does suppress.
- **Joint-mode chat auto-scroll on keyboard appearance** subscribes to `UIResponder.keyboardDidShowNotification` and `keyboardDidChangeFrameNotification` and re-fires the `scrollToLatest(using: proxy)` helper. SwiftUI's `.scrollDismissesKeyboard(.interactively)` on the ScrollView handles the iMessage-style drag-down-to-dismiss gesture.
- **`Forge/Views/` is a `PBXFileSystemSynchronizedRootGroup`.** The `file-restructure` branch converted it from a traditional PBXGroup, so any `.swift` file dropped into `Forge/Views/<subdir>/` is auto-picked up by the Forge target — no `project.pbxproj` edits required. `Forge/View Model/` and `Forge/Data Model/` are still traditional groups; adding files there still needs pbxproj surgery. Same conversion pattern is viable if it becomes painful.
- **`@EnvironmentObject` does NOT auto-propagate from a `@StateObject` declared on a parent view.** You must explicitly call `.environmentObject(...)` somewhere in the chain. SessionClient lives as `@StateObject` on `CompletedWorkoutsView`; until Stage 7b's fix it was only injected on the WorkoutWithFriendView/ConnectingView destinations and missing for the SelectPlanView path — which meant solo workouts crashed the moment WorkoutInProgressView's body read `sessionClient.state`. Fix: inject ONCE on the NavigationStack itself so every nav destination AND every modal presented from within them inherits it. Lesson: when an `@EnvironmentObject` is added to a downstream view, audit every code path that reaches it.
- **Avatar position must be `@State`, not derived.** The original `myPosition` was a computed property reading set-completion flags + `timerEnabled` + an `isEnteringRest` patch flag. These three sources never transition atomically inside a single SwiftUI body evaluation, so every reordering of writes inside the set-tap handler produced a different "intermediate-state flash" bug (avatar momentarily at the wrong row). Fixed by promoting `myPosition` to explicit `@State` and writing it ONCE per discrete event (set tap, break-timer dismiss, workout start) via a `recomputeMyPosition()` helper that applies the unified rule "first-incomplete-set, with a rest-row adjustment when an active break timer's source set immediately precedes it." Out-of-order toggling (un-checking a middle set) falls out for free. If you ever need to add another input to position logic, write it through `recomputeMyPosition` — don't sprinkle conditionals at the call sites.
- **Avatar gutter geometry is anchor-driven, not parallel-VStack-with-matching-heights.** The original gutter was a sibling VStack with hardcoded `setRowHeight` / `restRowHeight` / `exerciseNameRowOffset = 73`. When an exercise name wrapped to two lines, the header outgrew the offset and the entire gutter drifted out of alignment. Replaced with a `RowAnchorKey: PreferenceKey<[RowID: Anchor<CGRect>]>` published from each set/rest row via `.anchorPreference(value: .bounds)`, and resolved by an `.overlayPreferenceValue` on the per-exercise HStack that absolutely positions one `avatarColumn` per row at its measured `midY` via `.position(...)`. Card has a `Color.clear.frame(width: gutterWidth)` leading placeholder. Wrap-resilient and immune to any future row-content change. The card's row `.frame(height: setRowHeight)` modifiers are kept as soft floors for visual consistency but are no longer load-bearing for alignment.
- **Stale per-peer state must be cleared on BOTH `reconnect()` AND `peerLeft`.** Server assigns a fresh `myId` on every WebSocket connection, so post-reconnect the peer has a new UUID. `peerIds` and `peerProfiles` were always cleared, but `peerPositions` / `peerBreakTimer` / `peerReady` (all keyed by peer UUID) were not — old-UUID entries lingered and rendered as ghost "?" avatars next to the new peer. Fixed by mirroring the cleanup in both code paths. `peerCompletedSets` is keyed by `(exerciseId, setIndex)` (not peer UUID), so doesn't need this treatment.
- **After every transition into `.connected`, re-broadcast joint state.** Server doesn't persist position / completed sets / break-timer state — only the suggested plan and the `workoutInProgress` snapshot. So when a peer disconnects and reconnects (or a fresh peer joins), they have NO knowledge of my workout progress until I happen to do something. `WorkoutInProgressView`'s `.onChange(of: sessionClient.state)` calls `rebroadcastJointStateForPeer()` on every `.connected` transition: pushes current position + every completed set + active break-timer state. Symmetric on both phones, idempotent.
- **Hummingbird's autoPing default is 30s; iOS-side `sendPing` is the missing complement.** The server-side WebSocket layer keeps the connection alive transparently, but iOS doesn't ping on its own — so a dead-but-not-yet-noticed connection only surfaces when the next outbound message fails. Added a `pingTask` sibling to the receive loop in `SessionClient.openSocket` that calls `URLSessionWebSocketTask.sendPing` every 30s; pong-error cancels the task → readLoop throws → state becomes `.disconnected` → auto-reconnect kicks in. Combined with exponential backoff (2/4/8/16/32s capped) and an `onChange(of: state)` Combine sink that schedules reconnects when state transitions into `.disconnected` with active sessionId.
- **Mid-workout rejoin needs server-side `workoutInProgress` tracking.** Without it, the rejoiner is routed through the standard pair → JoinSession → PlanSuggestion flow and can suggest a different plan + tap Ready, broadcasting `startWorkout` again and stomping the partner's active workout. Stage 7b' adds `Session.workoutInProgress: PlanSnapshot?` set as a side effect of `setReady`'s just-became-all-ready transition, persisted for session lifetime, and included in the `welcome` message. iOS routes the rejoiner straight into `WorkoutInProgressView` with that plan, skipping the suggest/Ready surface entirely. Auto-submits cached profile in `JoinSessionView` to avoid a manual button tap on the way through.
- **`@StateObject` lifecycle vs. `disconnect()` vs. `reconnect()`.** `SessionClient.disconnect()` is user-initiated (Cancel button or End Session) and clears EVERYTHING including `sessionId` and `hasSubmittedProfile`, transitioning state to `.idle`. `reconnect()` is for transient drops — preserves `sessionId`, `hasSubmittedProfile`, `myProfile`, and `chatEntries` (so the chat history survives a network blip) but clears per-peer dicts (which all need fresh UUIDs anyway). The Combine state sink that auto-schedules reconnect guards on `sessionId != nil`, so a disconnected session never auto-reconnects.

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

**47 test cases** across four files:
- `ExerciseTests.swift` — `doesExerciseHaveUniqueSets()` and `sets` didSet observer (8 cases)
- `PlanViewModelTests.swift` — `calculateWorkoutDuration`, `isThereNonZeroDecimal`, save/load round-trip, move/delete plan/exercise, `importPlan` state-strip + collision suffixing (16 cases)
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
- **Don't put workflow-critical `@StateObject`s on the `App` struct if any view's `onAppear` resets navigation flags.** Promoting `PlanViewModel` to `@StateObject` on `ForgeApp` caused the Scene body to re-evaluate on every `planViewModel` publish, which re-fired `CompletedWorkoutsView.onAppear` and reset `isSelectPlanViewActive = false` — popping `SelectPlanView` and the workout fullScreenCover every time a plan was tapped (the 3-sec countdown appeared, then the whole stack collapsed back to the history screen). Keep VMs that mutate during active workflows out of `App`-level `@StateObject`s. The working pattern is inline `.environmentObject(PlanViewModel())` in `ForgeApp.body` + `@EnvironmentObject` in the views that need it. If you need app-wide access to a shared VM for something like `.onOpenURL`, attach the handler to the root *view* (`CompletedWorkoutsView`), not the Scene.

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
16. Plan sharing — swipe right on a plan in `SelectPlanView` to share a `.forgeplan` file via the iOS share sheet (AirDrop/Messages/Mail/Save to Files). Receiving iPhones open the file via `.onOpenURL` on `CompletedWorkoutsView`, routed through `PlanViewModel.importPlan(_:)` — strips set-completion state, clears `lastCompleted`, auto-suffixes name collisions. `WorkoutPlan: Transferable` via `FileRepresentation`; custom `Ryan-Div.Forge.workoutPlan` UTType exported in `Forge/Info.plist`. First use of a real Info.plist file for the Forge target (merged on top of `INFOPLIST_KEY_*` build settings).

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
