# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Project Overview

Forge is a minimal native iOS app (SwiftUI, Swift 5) for tracking weightlifting workouts. No external dependencies — only system frameworks (SwiftUI, Combine, UIKit, UserNotifications, ActivityKit, WidgetKit, HealthKit, WatchConnectivity). Dark-mode only. Includes an Apple Watch companion (haptic break-timer alerts) and a self-hosted Swift server (`server/`) for the collaborative workout feature.

User flow: History → Plan Selector → Active Workout → back to History with the completed workout logged.

## Build, Run & Test

```bash
open Forge.xcodeproj                                                    # Xcode
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Debug  # CLI build
xcodebuild test -project Forge.xcodeproj -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'              # tests
```

- Deployment targets: iOS 18.6 (`Forge`, `ForgeWidgetsExtension`), watchOS 11.0 (`ForgeWatch`), iOS 26.4 simulator-only for `ForgeTests`.
- Bundle IDs: `Ryan-Div.Forge`, `Ryan-Div.Forge.ForgeWidgets`, `Ryan-Div.Forge.watchkitapp`, `Ryan-Div.ForgeTests`.
- Builds must be **warning-free**. Fix new deprecation warnings in the same change.

## Architecture

**MVVM with SwiftUI EnvironmentObjects**, injected at `ForgeApp.swift`:

- `CompletedWorkoutsViewModel` — workout history CRUD, date/time formatting
- `PlanViewModel` — plan CRUD, reorder, duration estimation, exercise transfer
- `ExerciseViewModel` — active exercise state during editing
- `WorkoutHealthManager` — HealthKit auth, live workout sessions (iOS 26+), manual saves
- `GlobalSettings.shared` — theming singleton, also `@EnvironmentObject` so views update reactively on theme change

All ViewModels are `ObservableObject` with `@Published` properties.

**Persistence:** UserDefaults + JSON `Codable`. Keys: `"workoutPlans"`, `"completedWorkouts"`, `"breakDurationSeconds"`, `"colorTheme"`, `"collabProfile"`. `PlanViewModel` and `CompletedWorkoutsViewModel` accept `userDefaults: UserDefaults = .standard` so tests inject isolated `UserDefaults(suiteName:)`.

**Theming:** `GlobalSettings.shared` (`Forge/View Model/GlobalSettings.swift`). `fgColor` is computed from `@Published colorTheme: ColorTheme` (persisted via Combine sink — **not** `didSet`, which breaks `objectWillChange` on `@Published`). Six themes: red (default `#FF436B`), blue, green, orange, purple, yellow. Background `#161616`. Reference `settings.fgColor` (not local copies) so views update reactively. Constants: `darkGray`, `editorDarkGray`, `buttonCircleBgColor`, `setButtonSize`, `setsFontSize`, `setsSpacing`, `bottomToolbarHeight`, `cornerRadiusSmall/Medium/Large` (5/8/16), `animationQuick/Standard/Slow` (0.2/0.5/1.0). `breakDuration` is UserDefaults-backed (default 60s, range 5–300s).

## Data Models (`Forge/Data Model/`)

- `WorkoutPlan` → `[Exercise]` → `[Set]` (weight, reps, tillFailure, completed). All `Identifiable + Codable` with UUIDs.
- `CompletedWorkout` — date, elapsed time, completion %, optional `caloriesBurned: Double?` (nil without Apple Watch).
- `Exercise.sets` `didSet` auto-computes `areSetsUnique` (via `doesExerciseHaveUniqueSets()`) and `completed`.
- `EditorMode.swift` — `PlanEditorMode` / `ExerciseEditorMode` / `ReorderDeleteMode` enums replacing string flags.
- `WorkoutActivityAttributes` — ActivityKit contract. Static: `planName`. Dynamic: `percentCompleted`, `isResting`, `restEndDate`, `nextExerciseName`, `nextSetDescription`. Compiled into both Forge + ForgeWidgetsExtension targets.
- `PlanTransferType.swift` — `UTType.forgePlan` (UTI `Ryan-Div.Forge.workoutPlan`) + `WorkoutPlan: Transferable`. `WorkoutPlan.sharePreviewImage` pre-renders `dumbbell.fill` to a 160pt UIImage (handing `Image(systemName:)` directly to `SharePreview` renders blank).

## Key Views (`Forge/Views/`)

The two largest views were decomposed into focused child components. Parent views coordinate state and animation; children render specific subsystems.

| View | Lines | Purpose |
|------|---|---------|
| `CompletedWorkoutsView` | ~125 | Home screen — history list, settings + Add Friend nav-bar buttons |
| `SettingsView` | ~95 | 6-color theme picker + per-plan "Reset Last Completed" |
| `SelectPlanView` | ~250 | Choose/manage plans — swipe-right to share `.forgeplan`, swipe-left to delete, drag to reorder |
| `PlanEditorView` | ~310 | Create/edit a plan + exercises — inline reorder/delete + swipe-right exercise transfer |
| `ExerciseEditorView` | ~410 | Add/edit exercises — coordinator only |
| `HomogeneousSetPicker` | ~200 | 3-column wheel pickers (sets × weight × reps) |
| `HeterogeneousSetEditor` | ~235 | Per-set rows w/ weight/reps/till-failure controls |
| `WorkoutInProgressView` | ~860 | Active workout — Live Activity + HealthKit + stopwatch + break timer + collab joint mode + mid-workout chat panel |
| `StartingCountdownView` | ~100 | 3s pre-workout countdown — self-contained |
| `BreakTimerView` | ~155 | Configurable rest timer (`TimelineView`) + notification + "Up Next" info |
| `WorkoutBottomToolbarView` | ~120 | Add / Done / Edit toolbar (3-button row only; ignores keyboard) |
| `WorkoutChatToolbar` | ~70 | Mid-workout chat container (chat panel + Open/Minimize Chat row + divider) — sibling of `WorkoutBottomToolbarView`. Animated rounded top corners + height grow expanding upward; rises with keyboard via parent's manual avoidance. |
| `SetView` | ~140 | Reusable set-row rendering. Parameterized via `Content` (`.individual`/`.summary`) and `Appearance` (`.standard`/`.muted`/`.workoutActive(isCompleted:)`/`.workoutActiveCollab(isCompleted:)`) enums. |
| `HistoryView` | ~200 | Read-only past workout — calories/completion/duration stats + Dismiss |
| `ReorderDeleteView` | ~100 | Reorder/delete sheet for plans or exercises |
| `BreakTimerWatchView` | ~110 | watchOS break timer — countdown ring + haptic on expiry |
| `WorkoutWithFriendView` | ~220 | Collab — feature explainer + Copy/Share Link buttons. `activeWorkoutPlan` parameter switches between History entry (push to `ConnectingView`) and mid-workout invite (dismiss back to workout). |
| `ConnectingView` | ~75 | Collab — state-driven banner; auto-advances to `JoinSessionView` |
| `JoinSessionView` | ~220 | Collab — name + `PhotosPicker` + peer banner. `onSoloProfileSaved` closure flips into solo-profile-entry mode (used by `WorkoutWithFriendView` mid-workout). |
| `PlanSuggestionView` | ~390 | Collab — plan carousel + chat (via `CollabChatPanel`) + Ready buttons. Auto-routes re-joiners into the active workout when `workoutInProgress` is set. Shimmer sweep on suggested-plan name via `TimelineView`. |
| `CollabChatPanel` | ~210 | Collab — extracted reusable chat surface (scroll + input bar + `KeyboardPersistentTextView`). `showAvatarHeader` opt-in renders a peer-only avatar at top with "stepped away" dim + moon badge. Drag-down + scroll-down both dismiss keyboard. Used by `PlanSuggestionView` AND `WorkoutChatToolbar`. |
| `CollabStatusBanner` | ~170 | Collab — capsule overlay. Surfaces `.waitingForPeer` / `.connecting` / `.disconnected` / `.error` with appropriate copy + Re-invite button. Override: shows "Friend finished workout" / "Friend left session" with auto-dismiss when `peerExitInfo` is set. |

## Live Activity (`ForgeWidgets/`)

- Files: `ForgeWidgetsBundle.swift` (registers `WorkoutLiveActivity`), `WorkoutLiveActivity.swift` (Lock Screen + Dynamic Island compact/expanded), `WorkoutActivityAttributes.swift` (lives in `Forge/Data Model/`, shared between targets).
- **Lock Screen:** plan name, %, countdown timer (when resting), "Up next" exercise/set info.
- **Dynamic Island compact:** dumbbell↔timer leading icon. Trailing % or `Text(timerInterval:)` countdown — must be `frame(width: 36)` + `minimumScaleFactor(0.6)` to prevent island stretching.
- **Dynamic Island expanded:** plan name, %, countdown, next exercise/set.
- **Lifecycle hooks** in `WorkoutInProgressView`: `startLiveActivity()` (post-3s countdown), `updateLiveActivity()` (set completion / timer start / timer end), `endLiveActivity()` (finishWorkout + cancelWorkout).
- **Colors:** `GlobalSettings` is NOT compiled into the widget extension — `WorkoutLiveActivity` defines its own `fgColor` locally. `WidgetBackground` asset is `#161616`.

## HealthKit (`Forge/View Model/WorkoutHealthManager.swift`)

Injected as `@EnvironmentObject`. Authorizes write on `HKObjectType.workoutType()`, read on `activeEnergyBurned` + `heartRate`.

- **Live session (iOS 26+):** `startWorkoutSession()` → `HKWorkoutSession` + `HKLiveWorkoutBuilder` (collects HR + calories from Watch). `endWorkoutSession(completion:)` extracts calories from `workout.statistics(for: .activeEnergyBurned)` via the `(Double?) -> Void` handler. Live Activity also surfaces on Watch automatically.
- **Calorie capture:** `finishWorkout()` saves `CompletedWorkout` immediately with nil calories, then patches via the completion handler.
- **Manual save (fallback):** `saveWorkout(startDate:endDate:elapsedTime:)` uses `HKWorkoutBuilder` for `.functionalStrengthTraining` when no live session.
- **Lifecycle:** Session starts after the 3s countdown. `finishWorkout` ends the session if active, else manual-saves; `cancelWorkout` ends unconditionally.
- **Gotcha:** Use `Swift.Set` (not `Set`) when calling HealthKit APIs — the project's `Set` data model shadows Swift's built-in.

## Apple Watch (`ForgeWatch/`)

Standalone watchOS app receiving break-timer state via WatchConnectivity. iOS won't route notifications to the Watch while the phone is in foreground, so the Watch handles haptic alerts.

- `ForgeWatchApp.swift` — activates `WatchSessionManager` on init.
- `WatchSessionManager.swift` — `WCSessionDelegate` singleton; `@Published timerState` (`.idle`/`.counting`/`.expired`).
- `BreakTimerWatchView.swift` — three visual states. `TimelineView` countdown.
- Phone side: `PhoneSessionManager.swift` (singleton activated in `ForgeApp.init()`), called at three sites in `WorkoutInProgressView`: timer start, dismiss, workout end.
- **Wire protocol:** `timerStarted` (endDate, duration, exerciseName, setDescription), `timerDismissed`, `workoutEnded`.
- **Dual delivery:** every message via both `sendMessage` (real-time when reachable) AND `updateApplicationContext` (guaranteed eventual). Watch checks `receivedApplicationContext` on activation.
- **Haptic:** `WKInterfaceDevice.current().play(.notification)` when countdown hits zero or `timerStarted` arrives with already-past `endDate`.

## Plan Sharing (`.forgeplan`)

Plans travel as `.forgeplan` files (JSON-encoded `WorkoutPlan` under exported UTI `Ryan-Div.Forge.workoutPlan`).

- `Forge/Data Model/PlanTransferType.swift` — `UTType.forgePlan` + `WorkoutPlan: Transferable`. Exports a temp file named after the plan; decodes on import.
- `Forge/Info.plist` — `UTExportedTypeDeclarations` + `CFBundleDocumentTypes` (`LSHandlerRank=Owner`, `LSSupportsOpeningDocumentsInPlace=false` — Forge always copies to its own library).
- `SelectPlanView` — leading-edge `.swipeActions` with blue `ShareLink(item: plan)`.
- `PlanViewModel.importPlan(_:)` — single funnel for incoming plans. Strips `completed` flags, clears `lastCompleted`, auto-suffixes name collisions (`" (Imported)"`, `" (Imported) 2"`).
- `CompletedWorkoutsView.onOpenURL` decodes incoming `.forgeplan` files.

**Info.plist setup:** Forge target uses `GENERATE_INFOPLIST_FILE=YES` + `INFOPLIST_KEY_*` for most values, but array-of-dictionary entries (document types, UTI, URL schemes) need a real plist file. `Forge/Info.plist` holds only those (`CFBundleDocumentTypes` + `UTExportedTypeDeclarations` for `.forgeplan`, `CFBundleURLTypes` for `forge://`). `INFOPLIST_FILE = Forge/Info.plist` merges `INFOPLIST_KEY_*` on top. Extend this file for new array-of-dict keys; don't flip back to pure build-settings generation.

## Collaborative Workout Feature

Two friends each running Forge join a shared real-time session. Host taps the invite-friend button (`person.2.fill` on History or in-workout) → `WorkoutWithFriendView` → Copy/Share Link generates a `forge://session/<uuid>` URL. Receiver taps the link, Forge auto-joins. Paired users see each other's set completions, break timers, profile avatars during workouts; chat both during plan selection AND mid-workout via the expanding bottom-toolbar chat panel. Clean exits (Done / Cancel) broadcast `peerFinished` / `peerCancelled` so the still-working friend sees a labeled banner instead of a generic disconnect. Backgrounding Forge does NOT surface a disconnect — server marks the slot `.away` for 5 min, the other peer sees a subtle dimmed-avatar + moon-badge indicator, and a stable per-device participant ID lets the reconnect rebind the same slot transparently.

**Stack:** self-hosted Swift server in `server/` (Hummingbird 2 + HummingbirdWebSocket, separate SwiftPM package). Public exposure via Cloudflare Quick Tunnel (`*.trycloudflare.com`). Single WebSocket per client. In-memory session state — no database. Capacity 2 per session.

### Running the server

On the Mac mini:

```bash
cd server
swift build                                          # first time ~2 min
swift run ForgeServer                                # binds 127.0.0.1:8080
# In a second terminal:
cloudflared tunnel --url http://localhost:8080       # prints a trycloudflare.com URL
```

iOS hardcodes the hostname in `SessionClient.serverHost`. `ForgeServer` can be killed/restarted without changing the tunnel URL; restarting `cloudflared` DOES change it (must update + rebuild app). Future Named-Tunnel migration captured in "Future roadmap".

### File map

**Server (`server/`):**

- `Sources/ForgeServer/main.swift` — top-level async entry (filename = `main.swift` so no `@main`; see gotcha).
- `Application+build.swift` — HTTP `/` health + `WS /sessions/:id` upgrade + per-connection task group (inbound reader + outbound stream drain). Parses stable `?participantId=<uuid>` query param (UUID fallback for old clients). Handles `setReady` (broadcasts `startWorkout`, records `workoutInProgress` on just-became-all-ready), `workoutFinished` / `workoutCancelled` (clears `workoutInProgress`, broadcasts `peerFinished` / `peerCancelled`), `goingBackground` (marks slot `.away`, schedules 5-min timeout, broadcasts `peerAway`), `returningToForeground` (marks `.connected`, broadcasts `peerReturned`). Cleanup path skips `removeParticipant` when state is `.away` so the slot persists for timeout/reconnect.
- `Protocol.swift` — `ServerMessage` / `ClientMessage` enums + `Profile` / `PeerInfo` / `PlanSnapshot` value types. Codable + Sendable. ServerMessage includes `peerAway` / `peerReturned`; ClientMessage includes `goingBackground` / `returningToForeground`. **Every protocol change requires server redeploy + app rebuild in lockstep.**
- `SessionManager.swift` — actor holding `[UUID: Session]`; lazy-creates on first `addParticipant`; deletes when empty. Per-session: `suggestedPlan`, `workoutInProgress` (set on all-ready transition; persists for session lifetime; cleared on `workoutFinished`/`Cancelled`), per-participant `isReady` + `state: ParticipantState (.connected / .away(since:))` + `awayTimeout: Task`. `addParticipant` returns `.added` (fresh slot → broadcast `peerJoined`) or `.rebound` (reconnect into existing `.away` slot, continuation rebound + timeout cancelled → broadcast `peerReturned`). `markAway` / `markReturned` / `scheduleAwayTimeout` / `participantState` drive the away lifecycle. `setReady` returns true on just-became-all-ready transition so the caller broadcasts `startWorkout`. Hummingbird's autoPing default 30s — server keepalive needs no per-call code.

**iOS (Forge target):**

- `Forge/View Model/SessionClient.swift` — `@MainActor` ObservableObject. State enum: `.idle` / `.connecting` / `.waitingForPeer` / `.paired(peerIds: [UUID])` / `.disconnected(reason:)` / `.error(_)`. Methods: `createSession()`, `joinSession(id:)`, `reconnect()`, `disconnect()`, `submitProfile(_:)`, `suggestPlan(from:)`, `sendChat(text:)`, `toggleReady()`, `sendSetCompletion(...)`, `sendPositionUpdate(_:)`, `sendBreakTimerUpdate(...)`, `sendWorkoutFinishedAndDisconnect()`, `sendWorkoutCancelledAndDisconnect()`, `sendGoingBackgroundAndAwait()`, `sendReturningToForeground()`, `startSharedSessionForActiveWorkout(plan:)`. Wire types: `Profile`, `PeerInfo`, `PlanSnapshot`, `ChatEntry`, `PeerSetKey`, `UserPosition`, `PeerBreakTimer`, `PeerExitInfo`. `@Published`: `peerProfiles`, `suggestedPlan`, `chatEntries`, `peerReady`, `startWorkoutSignal`, `peerCompletedSets`, `peerPositions`, `peerBreakTimer`, `workoutInProgress`, `peerExitInfo`, `peerAway: [UUID: Date]`. **Stable participant ID:** `stableParticipantId` lazy var, generated once + persisted in UserDefaults under `"collabParticipantId"`. Sent on every WS connect via `?participantId=<uuid>` query — server uses it to rebind reconnects to existing `.away` slots. Owned by `CompletedWorkoutsView` as `@StateObject` — NOT `ForgeApp` — and **injected at the NavigationStack root** so all nav destinations + their modals inherit it. **Heartbeat:** `pingTask` calls `URLSessionWebSocketTask.sendPing` every 30s; pong-error cancels task → readLoop throws → `.disconnected` → auto-reconnect. **Auto-reconnect:** Combine sink on `$state.zip($state.dropFirst())` schedules `reconnect()` with exponential backoff (2/4/8/16/32s capped); resets on `.welcome`. `reconnect()` AND `peerLeft` clear `peerPositions`/`peerBreakTimer`/`peerReady`/`peerAway` to avoid ghost "?" avatars after fresh-UUID re-pairing. `sendWorkoutFinished/Cancelled/GoingBackgroundAndAwait()` use an awaited `task.send` so the message flushes before the close frame / iOS suspension races.
- `Forge/Views/Collab/`:
  - `WorkoutWithFriendView.swift` — explainer + Copy/Share buttons. `activeWorkoutPlan: WorkoutPlan?` switches behavior: nil (History entry) → `createSession()` + push `ConnectingView`; non-nil (mid-workout) → `startSharedSessionForActiveWorkout(plan:)` + dismiss back to workout. Single unified `.sheet(item: $activeSheet)` covers both the iOS share sheet AND a workout-mode profile prompt (avoids the two-`.sheet` SwiftUI conflict). When the host has no profile in workout mode, taps to Copy/Share present `JoinSessionView(onSoloProfileSaved:)` as a nested sheet; the closure dismisses it then re-fires the action one runloop tick later (UIKit needs the hop or the next sheet/dismiss collides with the in-flight teardown).
  - `ConnectingView.swift` — state-driven banner; auto-advances to `JoinSessionView`.
  - `JoinSessionView.swift` — name + `PhotosPicker` + peer banner. `autoSubmitIfCachedProfile()` skips the form for returning users. Optional `onSoloProfileSaved: (() -> Void)?` activates solo-profile-entry mode (used by `WorkoutWithFriendView`): hides peer half + connector, suppresses End Session toolbar, button label becomes "Save", title becomes "Your Profile", skips auto-submit + `PlanSuggestionView` nav. `@FocusState` auto-focuses the empty name field 0.4s after appear (delay survives the present transition; guarded by `!hasSubmittedProfile`).
  - `PlanSuggestionView.swift` — carousel + `CollabChatPanel()` + Ready buttons + single `.fullScreenCover(item:)` enum-driven cover for both `PlanEditorView` (preview) and `WorkoutInProgressView` (post-ready). `routeIntoActiveWorkoutIfNeeded()` (on appear + `onChange(of: workoutInProgress?.id)`) auto-routes re-joiners straight into the active workout — they can't broadcast a fresh `startWorkout` and stomp the partner.
  - `CollabChatPanel.swift` — extracted reusable chat surface (scroll + bubble + input bar) + `KeyboardPersistentTextView` (UIViewRepresentable wrapping `WrappingUITextView`, a UITextView subclass returning `noIntrinsicMetric` for width so long lines wrap instead of expanding the bar). `showAvatarHeader: Bool` opt-in renders peer-only avatar at the top with the away dim treatment. `simultaneousGesture(DragGesture)` + `.scrollDismissesKeyboard(.immediately)` both dismiss keyboard on downward drag. Used by both `PlanSuggestionView` and `WorkoutChatToolbar`.
  - `CollabStatusBanner.swift` — capsule overlay. Hidden in `.paired`/`.idle`. State-based copy + spinner for `.connecting`/`.disconnected`/`.error`/`.waitingForPeer`. `.waitingForPeer` shows a "Re-invite" button that share-sheets the EXISTING `sessionId` URL (does NOT call `createSession()`). **Clean-exit override:** when `peerExitInfo` is set (server reported peer's `workoutFinished` / `workoutCancelled`), shows "Friend finished workout" / "Friend left session" with checkmark/xmark icon for ~5s then auto-dismisses; presence of `peerExitInfo` (even after auto-dismiss) suppresses the disconnect/Re-invite chrome for the rest of the session. **Note:** does NOT surface peer backgrounding — that's an avatar-level signal only (peerAway → dim + moon badge).
  - `PlanCarouselCard.swift`, `PlanInfoBlock.swift` — shared plan-display pieces.
  - `CollabHelpers.swift` — `avatar`, `initial`, `resizeImage`, `ShareSheet`, `ShareableURL`, `awayDimmedAvatar` (opacity 0.45 + moon.fill badge for peer-away state, used by `CollabChatPanel`'s avatar header; the workout gutter uses inline opacity-only since the small avatar size makes the badge cramped).
- `Forge/Views/History/CompletedWorkoutsView.swift` — Add Friend toolbar button, `forge://session/<id>` routing in `.onOpenURL`, `.onChange(of: scenePhase)` switch: `.active` → `reconnect()` + `sendReturningToForeground()`, `.background` → `Task { await sessionClient.sendGoingBackgroundAndAwait() }` (must flush before iOS suspends), `.inactive` ignored. `.onChange(of: sessionClient.state)` → resets nav-destination flags on `.idle` (collapses the entire collab stack to History). `NavigationStack` is closed by `.environmentObject(sessionClient)`.
- `Forge/Views/Workout/WorkoutInProgressView.swift` — gains `@EnvironmentObject var sessionClient`. In joint mode (`sessionClient.isPaired`) per-exercise cards have an empty `Color.clear.frame(width: gutterWidth)` leading placeholder; `.overlayPreferenceValue(RowAnchorKey.self)` reads each set/rest row's bounds anchor (published via `.anchorPreference`) and absolutely positions one `avatarColumn` per row at its measured `midY` — **no hardcoded row offsets, wrap-resilient.** Peer avatars in the gutter dim to 0.45 opacity when `sessionClient.peerAway[peerId] != nil`. `myPosition` is `@State` (not derived); `recomputeMyPosition()` applies a single rule (first-incomplete-set, with rest-row adjustment when an active break timer's source set immediately precedes it) — called on every set tap, break-timer dismiss, workout start. `.onChange(of: myPosition)` broadcasts `sendPositionUpdate`; `.onChange(of: sessionClient.state)` matching `.paired` AND `.onChange(of: sessionClient.peerAway)` going non-empty → empty BOTH call `rebroadcastJointStateForPeer()`. `finishWorkout` / `cancelWorkout` send `workoutFinished` / `workoutCancelled` via async `sendAndAwait`; the disconnect is DEFERRED inside the 2s confetti `asyncAfter` so the animation completes before nav unwinds. Mid-workout invite button (`person.2.fill`, visible when `sessionId == nil` OR `peerExitInfo != nil`) presents `WorkoutWithFriendView(activeWorkoutPlan: planViewModel.activePlan)` as a sheet. Mid-workout chat: `WorkoutChatToolbar` rendered as ZStack sibling of `WorkoutBottomToolbarView`; manual keyboard avoidance via `keyboardWillShow/Hide` notifications drives the chat container's bottom padding (= keyboardHeight when up, bottomToolbarHeight when down) AND shrinks `chatPanelHeight` so the avatar at the top edge stays fixed while the chat-bubbles area compresses. Set-tap flow: `handleSetTap(exerciseIndex:setIndex:)` + `scheduleBreakTimerStart(...)` helpers. Anchor-preference types live in sibling `WorkoutAvatarGutter.swift`.
- `Forge/Views/Shared/SetView.swift` — `Appearance.workoutActiveCollab(isCompleted:)` joint-mode case: weight/reps as a single grey chip (e.g. `100 lb x 12 reps`), `.lineLimit(1)` so the compressed horizontal budget fits on small phones. Set # label drops to 13pt + 46/54pt frame.
- `Forge/Info.plist` — `CFBundleURLTypes` registers `forge://`.

### Feature-specific gotchas

- **iOS backgrounding kills WebSockets within seconds (iOS 18 reliably; iOS 26 sometimes survives a brief blip).** Mitigation stack: (a) server lazy-creates sessions on first WS connect so a returning peer always materialises the session for its ID; (b) client auto-reconnects via `.onChange(of: scenePhase)` at `CompletedWorkoutsView`; (c) the **background-aware presence layer** below makes brief backgrounds invisible to the other peer.
- **Background-aware presence (the away/return architecture).** When `scenePhase` transitions to `.background`, client awaits a `goingBackground` send (must flush during iOS's ~5s grace before suspension). Server marks the slot `.away`, broadcasts `peerAway` (NOT `peerLeft`) to the other peer, and starts a 5-min timeout. If client reconnects within the window, the `?participantId=<uuid>` query (stable per-device UUID persisted in UserDefaults under `"collabParticipantId"`) lets `addParticipant` return `.rebound` — continuation rebound, timeout cancelled, broadcast `peerReturned`. If timeout fires (peer never returned), server promotes to real `peerLeft`. The other phone's UI shows a subtle dimmed-avatar + moon-badge for `.away`, the loud "Friend disconnected" banner only for true disconnects (force-quit, network drop, crash — none of which sent `goingBackground`).
- **`peerReturned` re-broadcast must trigger from the still-paired peer, NOT the returning peer.** When the OTHER peer was `.away` and returns, my `state` stayed `.paired` throughout (server held them connected via `.away`), so the `.onChange(of: state) { case .paired }` re-broadcast observer doesn't fire on my side. But the returning peer's `reconnect()` cleared `peerPositions` / `peerCompletedSets` / `peerBreakTimer` — they need ME to replay state. `WorkoutInProgressView` has a SECOND observer on `sessionClient.peerAway` that fires `rebroadcastJointStateForPeer()` when the dict transitions from non-empty → empty. Without this, on iOS 18 the peer's avatar disappears from the gutter until they next complete a set.
- **`disconnect()` clears `sessionId`; the read-loop error path does NOT.** Load-bearing for reconnect — clearing on socket error would lose the rejoin target. `disconnect()` is user-initiated (Cancel / End Session). Socket failures surface as `.disconnected(reason:)` with sessionId intact.
- **Hummingbird 2 `onUpgrade` context lacks `.parameters`.** Only `shouldUpgrade`'s context has route params. In `onUpgrade`, parse from `context.request.uri.path.split(separator: "/").last`. The `participantId` query param is parsed from `context.request.uri.query` similarly.
- **`main.swift` cannot contain `@main`** — the filename itself makes it the entry point. Use top-level async code (what `server/Sources/ForgeServer/main.swift` does) or rename.
- **Cloudflare Quick Tunnel URL is ephemeral per `cloudflared` invocation.** Survives `ForgeServer` restarts but not `cloudflared` restarts.
- **Hummingbird's default `maxFrameSize` is 16 KB** — profile photos blow past it. `inbound.messages(maxSize:)` is the reassembled-*message* cap, NOT per-frame. Per-frame requires `WebSocketServerConfiguration.maxFrameSize: 1 << 20`. Without it, oversized frames close the connection at the protocol layer *before* `onUpgrade` sees anything; iOS reports successful send then "Socket is not connected" with no server trace.
- **`UIGraphicsImageRenderer` uses `UIScreen.main.scale` by default** — a 256×192pt request on a 3× phone produces 768×576 backing pixels (9× the intended count, 3× the wire size). For wire transport, force `format.scale = 1.0` on a `UIGraphicsImageRendererFormat`. The `resizeImage` helper in `CollabHelpers.swift` does this.
- **Collab navigation unwinds via state observer, not chained `dismiss()`.** `CompletedWorkoutsView` watches `sessionClient.state`; on `.idle` it resets both nav-destination flags, collapsing the entire collab stack in one step. Deep views like `PlanSuggestionView` only need `sessionClient.disconnect()` — no `dismiss()` chain, no shared nav-path binding.
- **Two `.fullScreenCover` / `.sheet` modifiers of the same flavor on the same view silently conflict** — only the first attaches. When a view needs more than one, use a single `.sheet(item:)` / `.fullScreenCover(item:)` driven by an `Identifiable` enum that switches content per case. `WorkoutWithFriendView` and `PlanSuggestionView` both use this pattern. The conflict is silent — no warning.
- **`PlanSnapshot.toWorkoutPlan()` must preserve UUIDs on the plan + each exercise**, or joint-mode set sync can't address rows across phones. `Exercise.init(name:sets:)` and `WorkoutPlan.init(name:exercises:)` generate fresh UUIDs — the extension copies `id` from the snapshot after construction. Set positions use positional index (`SetSnapshot` has no id), so set-completion sync keys off `(exerciseId: UUID, setIndex: Int)`.
- **SwiftUI `TextField` with `.submitLabel(.send)` + `.onSubmit` always dismisses the keyboard before the handler fires** — visible flicker even with immediate `@FocusState` re-assertion. `KeyboardPersistentTextView` in `CollabChatPanel.swift` is a `UIViewRepresentable` wrapping `UITextView` (multi-line — see chat-input gotcha below); its `textView(_:shouldChangeTextIn:replacementText:)` intercepts `"\n"` to fire `onSubmit` and returns `false`, keeping first-responder. Bonus: `autocorrectionType = .no` + `spellCheckingType = .no` + `smartInsert/Dashes/QuotesType = .no` at the UIKit level reliably suppress the QuickType + smart punctuation — SwiftUI's `.autocorrectionDisabled()` is inconsistent.
- **Multi-line chat input requires UITextView (not UITextField) + a `noIntrinsicMetric` width override.** UITextField is single-line and grows horizontally on long input. Switching to UITextView fixes wrap, BUT default UITextView (with `isScrollEnabled = false`) reports an `intrinsicContentSize` whose width = longest line — SwiftUI's HStack honors that and the input expands horizontally anyway. `WrappingUITextView` subclass overrides `intrinsicContentSize` to return `noIntrinsicMetric` for width, so SwiftUI's `.frame(maxWidth: .infinity)` constrains the field and UITextView wraps inside that width. `isScrollEnabled = false` makes it grow with content; SwiftUI clamps via a dynamic height `@State` driven by `sizeThatFits` in `textViewDidChange`. Asymmetric `textContainerInset` (top: 8, bottom: 5) compensates for font ascender > descender so visible glyphs sit centered with the placeholder UILabel (which uses centerY anchor).
- **iOS QuickPath candidate ribbon is NOT app-disableable.** The ribbon shown during swipe-to-type is drawn by the system keyboard. Only Settings → General → Keyboard → Slide to Type turns it off. Different from the persistent QuickType bar (which `autocorrectionType = .no` does suppress).
- **Joint-mode chat auto-scroll on keyboard appearance** subscribes to `UIResponder.keyboardDidShowNotification` + `keyboardDidChangeFrameNotification` and re-fires `scrollToLatest`. Drag-down dismissal: `.scrollDismissesKeyboard(.immediately)` on the messages ScrollView + a `simultaneousGesture(DragGesture)` on the panel root for the empty-state case (where there's no scrollview to dismiss against).
- **Mid-workout chat needs MANUAL keyboard avoidance, not SwiftUI's default.** SwiftUI's default keyboard avoidance positions the focused field above the keyboard top. The mid-workout chat layout has Minimize Chat sitting BELOW the input field in the VStack (chat panel + chat-toggle row + divider) — default avoidance leaves Minimize Chat hidden behind the keyboard. `WorkoutInProgressView` opts the chat container out via `.ignoresSafeArea(.keyboard)`, manually tracks `keyboardHeight` via `keyboardWillShow/Hide` notifications (pulling the system animation duration from `userInfo` so the chat slide matches the keyboard slide as one piece), drives the chat container's `.padding(.bottom, X)` from it (= `keyboardHeight` when up, `bottomToolbarHeight` when down), AND shrinks `chatPanelHeight` by `(keyboardHeight - bottomToolbarHeight)` so the chat container's TOP edge (avatar) stays fixed while the chat-bubbles area compresses. The 3-button `WorkoutBottomToolbarView` separately ignores `.keyboard` so the keyboard covers it instead of pushing it up.
- **Confetti / fade animation must complete BEFORE the collab disconnect fires.** `finishWorkout()` originally fired `sendWorkoutFinishedAndDisconnect()` immediately; the disconnect → state .idle → `CompletedWorkoutsView` state observer → nav unwind → `fullScreenCover` teardown happened mid-confetti, cutting the 2s animation short. Disconnect is now deferred inside the 2s `asyncAfter` block alongside `dismiss()`. Trade-off: the peer sees the "Friend finished" banner ~2s later — acceptable since they're typically still in their own workout.
- **`Forge/Views/` is a `PBXFileSystemSynchronizedRootGroup`** — drop `.swift` files in subdirectories and they're auto-picked up by the Forge target. `Forge/View Model/` and `Forge/Data Model/` are still traditional groups; adding files there needs pbxproj surgery.
- **`@EnvironmentObject` does NOT auto-propagate from a `@StateObject` parent** — must explicitly `.environmentObject(...)` somewhere in the chain. SessionClient lives as `@StateObject` on `CompletedWorkoutsView`; inject ONCE on the NavigationStack so all nav destinations + modals inherit it. When adding `@EnvironmentObject` to a downstream view, audit every code path that reaches it.
- **Avatar position must be `@State`, not derived.** Original `myPosition` was a computed property reading set-completion + `timerEnabled` + an `isEnteringRest` patch flag — these never transition atomically inside one body eval, so every reordering of writes inside the set-tap handler caused intermediate-state flash bugs. Promoted to explicit `@State`, written ONCE per discrete event via `recomputeMyPosition()` applying the unified rule "first-incomplete-set, with rest-row adjustment when an active break timer's source set immediately precedes it." Out-of-order toggling falls out for free. To add a new input to position logic, write it through `recomputeMyPosition` — don't sprinkle conditionals at the call sites.
- **Avatar gutter geometry is anchor-driven**, not parallel-VStack-with-matching-heights. The original used hardcoded row heights + `exerciseNameRowOffset = 73`; when an exercise name wrapped, the entire gutter drifted. Replaced with `RowAnchorKey: PreferenceKey<[RowID: Anchor<CGRect>]>` published from each row via `.anchorPreference(value: .bounds)`, resolved by `.overlayPreferenceValue` on the per-exercise HStack that absolutely positions one `avatarColumn` per row at its measured `midY`. Wrap-resilient.
- **Stale per-peer state must be cleared on BOTH `reconnect()` AND `peerLeft`.** Server assigns fresh `myId` per WS connection, so post-reconnect the peer has a new UUID. `peerProfiles` / `peerPositions` / `peerBreakTimer` / `peerReady` (all keyed by peer UUID) lingered as ghost "?" avatars without this. `peerCompletedSets` is keyed by `(exerciseId, setIndex)`, so doesn't need this treatment.
- **After every transition into `.paired`, re-broadcast joint state.** Server doesn't persist position / completed sets / break-timer state — only `suggestedPlan` and `workoutInProgress`. So a fresh peer (or post-reconnect peer) has no knowledge of my workout progress until I act. `WorkoutInProgressView`'s `.onChange(of: sessionClient.state)` matching `.paired` calls `rebroadcastJointStateForPeer()`. Symmetric on both phones, idempotent. The away-return path needs the SECOND `peerAway`-emptied observer (see separate gotcha) since the still-paired peer's `state` doesn't transition.
- **Hummingbird's autoPing default is 30s; iOS-side `sendPing` is the missing complement.** Server-side keepalive is transparent, but iOS doesn't ping on its own — a dead-but-not-yet-noticed connection only surfaces when the next outbound message fails. `pingTask` sibling in `SessionClient.openSocket` calls `sendPing` every 30s; pong-error cancels task → readLoop throws → `.disconnected` → auto-reconnect.
- **Mid-workout rejoin needs server-side `workoutInProgress` tracking.** Without it, a rejoiner is routed through the standard pair → JoinSession → PlanSuggestion flow and can broadcast a fresh `startWorkout`, stomping the partner's active workout. Server records `workoutInProgress` on the all-ready transition, persists for session lifetime, includes it in `welcome`. iOS routes the rejoiner straight into `WorkoutInProgressView` with that plan, skipping the suggest/Ready surface. `JoinSessionView` auto-submits cached profile to avoid a manual button tap.
- **`@StateObject` lifecycle vs `disconnect()` vs `reconnect()`.** `disconnect()` is user-initiated (Cancel / End Session) and clears EVERYTHING including `sessionId` and `hasSubmittedProfile` → `.idle`. `reconnect()` is for transient drops — preserves `sessionId`, `hasSubmittedProfile`, `myProfile`, `chatEntries` (chat survives a network blip) but clears per-peer dicts (which all need fresh UUIDs anyway). The Combine state sink that schedules reconnect guards on `sessionId != nil`, so a disconnected session never auto-reconnects.
- **Clean exit broadcast must flush before close frame.** `sendWorkoutFinishedAndDisconnect()` / `sendWorkoutCancelledAndDisconnect()` use awaited `task.send` (rather than fire-and-forget `sendClientMessage`) so the message lands before `disconnect()` closes the socket. Without the await, the close frame races the message and the peer sees a generic disconnect instead of the labeled exit banner.

## Timer & Notification System

- **Workout start countdown:** 3s, skippable. Owned by `StartingCountdownView` — signals via `onCompletion`.
- **Rest timer:** Configurable 5–300s (default 60s). `BreakTimerView` uses `TimelineView(.periodic(from:by:))` (immune to parent re-renders, unlike `Timer.publish`); schedules a `UNTimeIntervalNotificationTrigger` for backgrounded alert. Configured via timer-icon button in toolbar → `BreakDurationPickerView`.
- **Foreground suppression:** `AppDelegate.userNotificationCenter(_:willPresent:)` suppresses `"workoutCategory"` notifications while app is active.

**Critical race:** `dismissBreakTimerView(cancelPendingNotification:)` — natural-expiry path (`onExpired`) MUST pass `false`. Otherwise the in-app timer cancels the notification at the moment iOS is delivering it. Bites hardest under Xcode debugger (keeps app alive in background indefinitely → in-app timer keeps ticking and races system delivery). X/Done paths pass `true`. Notification id: `BreakTimerView.notificationIdentifier`.

## Navigation

Boolean `@Published` flags on ViewModels (e.g. `isSelectPlanViewActive`) + `NavigationStack` + `.fullScreenCover` / `.sheet`. Use `@Environment(\.dismiss)` (modern API — never `presentationMode`).

## Testing

- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest.
- **Target:** `ForgeTests/`. `PBXFileSystemSynchronizedRootGroup` — drop `.swift` files in, no pbxproj edits.
- **Suites:** `ExerciseTests` (8), `PlanViewModelTests` (16), `CompletedWorkoutsViewModelTests` (13), `ValidationTests` (10), `SessionClientTests` (16) — 64 cases.
- **Persistence isolation:** test classes touching persistence are `final class` (init/deinit = setUp/tearDown). Each gets its own `UserDefaults(suiteName: "ForgeTests.\(UUID().uuidString)")`, removes domain in `deinit`.
- **Mock data:** `Forge/View Model/MockData.swift` exposes `mockWorkoutPlans` + `mockCompletedWorkouts` as module-internal globals. Tests use `@testable import Forge`. `CompletedWorkoutsViewModel`'s Preview-only mock init no longer reaches into mock globals (production was depending on mock data).

## Subtle gotchas

- **Picker wheel `Int` tags need explicit `.tag(value)`** — SwiftUI's `WheelPickerStyle` historically had bugs binding to non-String selections. Replicate the pattern in `HomogeneousSetPicker` / `HeterogeneousSetEditor` for any new wheel picker.
- **`heterogenousSetRowHeight = 1000000`** in `ExerciseEditorView` is an intentional layout hack: `heterogenousSetMaxViewHeight = (count*Int(rowHeight))+80` makes height effectively unbounded so inner `clipped()` + outer `frame(maxHeight:)` can grow without limit. Don't "fix" it.
- **`homoHeteroControlsAreConnected` and `editedExerciseStartedWithUniqueSets` flags** in `ExerciseEditorView` gate sync between homogeneous/heterogeneous picker state. `onAppear` ordering matters — set connected flag false, load data, then set true. Otherwise the toggle's `onChange` fires during init and wipes the loaded data. The big comment block in the toggle handler explains the second flag.
- **`activeExerciseIndex` is stale in `.add` mode.** When the user adds a new exercise during a workout, `ExerciseViewModel.activeExerciseIndex` still points at the last logged/edited exercise. `ExerciseEditorView.saveExercise()` gates its `existingExercise` lookup on mode being `.edit` or `.log` — never trust `activeExerciseIndex` in `.add` mode (without the gate, new exercises inherit completion state from the previous one).
- **`Timer.publish` in child views breaks when parents re-render frequently.** `WorkoutInProgressView` updates `elapsedSeconds` every second; `BreakTimerView` originally used `Timer.publish` which got recreated (and never fired) on each re-render. Migrate any new timer-based child view to `TimelineView`, NOT `Timer.publish`.
- **`didSet` on `@Published` properties breaks `objectWillChange`** — the compiler-generated setter bypasses the property wrapper's `objectWillChange.send()`, so SwiftUI views don't update. Use a Combine `$prop.dropFirst().sink` subscriber for side effects (see `GlobalSettings.colorTheme`).
- **`navigationBarTitleTextColor` must force-update existing bars.** `UINavigationBar.appearance()` only applies to newly created bars. The extension in `CompletedWorkoutsView.swift` traverses all `UIWindowScene` windows on `.onChange(of: color)` and directly sets `standardAppearance`/`scrollEdgeAppearance` (via `.copy()` + reassign to trigger UIKit change detection).
- **Multiple `Button`s in a single `List` row require `.buttonStyle(.borderless)`.** Without it, SwiftUI's List treats the entire row as one tappable area and fires the last button's action regardless of where the user taps.
- **`UIScreen.main.bounds`** is used in 3 views for fixed-fraction layout (`0.33 * screenWidth` etc). Deprecated in iOS 16+ but doesn't currently warn at our deployment target. Migrating requires `GeometryReader` or environment-based screen access — see "Future roadmap".
- **Don't put workflow-critical `@StateObject`s on the `App` struct if any view's `onAppear` resets navigation flags.** Promoting `PlanViewModel` to `@StateObject` on `ForgeApp` caused the Scene body to re-evaluate on every publish, re-firing `CompletedWorkoutsView.onAppear` and resetting `isSelectPlanViewActive = false` — popping the workout fullScreenCover every time a plan was tapped. Working pattern: inline `.environmentObject(PlanViewModel())` in `ForgeApp.body` + `@EnvironmentObject` in views. For app-wide hooks (`.onOpenURL`), attach to the root *view* (`CompletedWorkoutsView`), not the Scene.
- **`SessionClient.State` carries peerIds in the `.paired` case** — there is no independent `@Published peerIds`, the "connected without peers" illegal state is unrepresentable. Read via `sessionClient.isPaired` (bool), pattern-match `case .paired(let ids) = state`, or use the `peerIds` computed accessor (returns `[]` in non-paired state). Don't reintroduce separate `peerIds` storage.
- **`Log.debug(_:)` is the project's logging channel** (`Forge/View Model/Log.swift`) — `@autoclosure` + `#if DEBUG`-guarded print. Use it instead of `print` in the Forge target. `ForgeWatch` still uses bare `print`. For user-visible error surfaces, still use a banner / alert per "Fail Loud, Never Fake".
- **Prefer `GlobalSettings` constants over magic numbers** for cornerRadius (`Small/Medium/Large` = 5/8/16) and animation durations (`Quick/Standard/Slow` = 0.2/0.5/1.0). Only when the semantic bucket matches — don't force idiosyncratic one-offs (2s finish-workout fade, 12pt collab sub-panel border) into the shared scale.
- **`LinearGradient`'s `startPoint`/`endPoint` are NOT animatable via `withAnimation`** — wrapping endpoint changes in `withAnimation(.linear...)` snaps to the final state. For continuously-animating gradients (shimmer, sweep, glow), drive phase from a `TimelineView(.animation) { context in ... }` that recomputes endpoints from wall-clock time, e.g. `context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycleSeconds) / cycleSeconds`. The shimmer on the suggested plan name in `PlanSuggestionView` uses this with a 2.5s cycle and UnitPoint phase mapped to `[-1.5, 1.5]`.
- **`@FocusState` set during a present transition gets silently dropped.** Auto-focusing a TextField in a sheet/nav-pushed view's `.onAppear` requires a small delay (~0.4s) so the host transition settles before SwiftUI accepts the focus change. `JoinSessionView` does this for the empty name field.

## Future development roadmap

High-level plan, ordered. Each item gets scoped + planned individually before execution.

- [ ] **Mid-workout chat enhancements** — the chat panel is shipped; remaining chat features:
  - [ ] Notifications (peer chat → local notification when Forge is backgrounded; coordinate with the existing `goingBackground` away-mode flow so we don't double-fire on every chat while the user is in-app)
  - [ ] Auto-detect URLs in chat bubbles + open in Safari on tap (`AttributedString` + `NSTextCheckingResult.Type.link`)
  - [ ] Long-press a bubble to add an emoji reaction; reactions sync via a new `ServerMessage.peerReactionAdded/Removed`
- [ ] **UI refactor: multi-iPhone-size support** — current layout assumes one iPhone class via `UIScreen.main.bounds`-derived widths (3 call sites flagged: `WorkoutBottomToolbarView`, `WorkoutInProgressView`, gutter). Goal: scale cleanly across SE-class through Pro Max via `GeometryReader` / size-class adjustments. Phone-only for now (iPad + landscape are out of scope).
- [ ] **Robust Plan Data Model with new Plan ID** — replaces per-plan `UUID` with an identity scheme that survives import/export round-trips, AirDrop dedup, server persistence. Ties together `dedupePlanIdsIfNeeded` migration logic + the `PlanSnapshot` wire type. Prerequisite for History Data Visualization (clean per-plan aggregation across renames + edits).
- [ ] **History Data Visualization** — trends across workouts (volume, frequency, per-exercise progress). New screen(s) reachable from `CompletedWorkoutsView`.
- [ ] **Production-grade server deployment** — Cloudflare Named Tunnel + launchd auto-start, replacing the current Quick Tunnel. Pure infrastructure; no behavioral change. Steps:
  ```bash
  cloudflared tunnel login                                       # one-time, browser
  cloudflared tunnel create forge-ws                             # outputs tunnel ID
  cloudflared tunnel route dns forge-ws forge-ws.ryan-div.com
  # ~/.cloudflared/config.yml: tunnel id, credentials, ingress → http://localhost:8080
  cloudflared tunnel run forge-ws                                # test in tmux
  ```
  Then change `SessionClient.serverHost` to `forge-ws.ryan-div.com` (one-line commit). Add launchd plists at `~/Library/LaunchAgents/com.ryandiv.forgeserver{,-tunnel}.plist` (`RunAtLoad + KeepAlive`) for boot-time auto-start. Optionally commit copies into `server/launchd/`.
- [ ] **Advanced UI / animation polish** — final pass before TestFlight. Visual + interaction refinements; small targeted commits.
- [ ] **TestFlight deployment** — first external testers.
- [ ] **App Store submission** — public release.

## Refactor history

The codebase has gone through ~18 stages of restructuring: string→enum modes, `WorkoutInProgressView` decomposition, `ExerciseEditorView` decomposition + Int picker state, deprecated-API replacement, dark-mode enforcement, Live Activity, HealthKit + calorie capture, Apple Watch companion, Settings + theming refactor, plan sharing, the full collab feature (sessions, profiles, plan suggestion, chat, ready/start, set sync, avatar gutter, break-timer sync, heartbeat + auto-reconnect, peer-disconnect banner, mid-workout rejoin), post-collab hardening (bug roll-up, `SessionClientTests`, `Log.debug`, `GlobalSettings` constants, `.connected → .paired(peerIds:)` invariant, conservative `WorkoutInProgressView` decomposition), the **mid-workout chat panel** (extracted `CollabChatPanel` + new `WorkoutChatToolbar` + multi-line `KeyboardPersistentTextView` + manual keyboard avoidance + animated rounded-top expansion), and **background-aware peer presence** (stable per-device participant ID + server-side `.away` slot lifecycle with 5-min timeout + `peerAway`/`peerReturned` protocol + subtle dimmed-avatar UI). See git log for `Stage N` commits and dated commits for detail.

## Git usage

- Don't credit yourself as a co-author in commit messages.
- Don't run git commands unless explicitly asked. Git operations supporting an explicitly-requested task are fine.

## Error Handling Philosophy: Fail Loud, Never Fake

Prefer a visible failure over a silent fallback.

- Never silently swallow errors to keep things "working." Surface the error. Don't substitute placeholder data.
- Fallbacks are acceptable only when disclosed (banner, log warning, annotation).
- Design for debuggability, not cosmetic stability.

Priority order:
1. Works correctly with real data
2. Falls back visibly — clearly signals degraded mode
3. Fails with a clear error message
4. Silently degrades to look "fine" ← never do this

Never build automated testing that finds shortcuts to a pass result. Passed tests must be due to genuinely correct code.
