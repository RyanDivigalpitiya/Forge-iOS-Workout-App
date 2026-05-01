# CLAUDE.md

Guidance for Claude Code in this repository.

## Project Overview

Forge — minimal native iOS weightlifting app (SwiftUI, Swift 5). Only system frameworks (SwiftUI, Combine, UIKit, UserNotifications, ActivityKit, WidgetKit, HealthKit, WatchConnectivity). Dark-mode only. Apple Watch companion (haptic break-timer alerts) + self-hosted Swift server (`server/`) for collab. Flow: History → Plan Selector → Active Workout → History.

## Build, Run & Test

```bash
open Forge.xcodeproj
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Debug
xcodebuild test -project Forge.xcodeproj -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- Targets: iOS 18.6 (`Forge`, `ForgeWidgetsExtension`), watchOS 11.0 (`ForgeWatch`), iOS 26.4 sim-only (`ForgeTests`).
- Bundle IDs: `Ryan-Div.Forge`, `Ryan-Div.Forge.ForgeWidgets`, `Ryan-Div.Forge.watchkitapp`, `Ryan-Div.ForgeTests`.
- Builds must be **warning-free**. Fix new deprecation warnings in the same change.

## Architecture

**MVVM + SwiftUI EnvironmentObjects** injected at `ForgeApp.swift`:

- `CompletedWorkoutsViewModel` — history CRUD/formatting
- `PlanViewModel` — plan CRUD, reorder, duration estimation, exercise transfer
- `ExerciseViewModel` — active exercise state during editing
- `WorkoutHealthManager` — HealthKit auth, live workout sessions (iOS 26+), manual saves
- `GlobalSettings.shared` — theming singleton, also `@EnvironmentObject` for reactive theme

All ViewModels are `ObservableObject` with `@Published`.

**Persistence:** UserDefaults + JSON `Codable`. Keys: `"workoutPlans"`, `"completedWorkouts"`, `"breakDurationSeconds"`, `"colorTheme"`, `"collabProfile"`. `PlanViewModel`/`CompletedWorkoutsViewModel` accept `userDefaults:` for test isolation.

**Theming:** `GlobalSettings.shared`. `fgColor` from `@Published colorTheme` (persisted via Combine sink — **not** `didSet`, which breaks `objectWillChange`). Six themes, default red `#FF436B`. Bg `#161616`. Use `settings.fgColor` directly. Constants: `darkGray`, `editorDarkGray`, `buttonCircleBgColor`, `setButtonSize`, `setsFontSize`, `setsSpacing`, `bottomToolbarHeight`, `cornerRadiusSmall/Medium/Large` (5/8/16), `animationQuick/Standard/Slow` (0.2/0.5/1.0). `breakDuration` UserDefaults-backed (default 60s, 5–300s).

## Data Models (`Forge/Data Model/`)

- `WorkoutPlan` → `[Exercise]` → `[Set]` (weight, reps, tillFailure, completed). All `Identifiable + Codable` with UUIDs. `WorkoutPlan` carries `lineageId: UUID?` (preserved through `importPlan` + collab auto-import) and `fingerprint: String?` (SHA-256 over ordered `(lowercased+trimmed name, setCount)` pairs; auto-refreshed via `exercises.didSet`; defines structural equality). Both optional for backward-compat decode; `migrateLineageAndFingerprintIfNeeded()` in `PlanViewModel.init()` backfills. `PlanSnapshot` (wire) carries both.
- `CompletedWorkout` — date, elapsed time, completion %, optional `caloriesBurned: Double?`.
- `Exercise.sets` `didSet` auto-computes `areSetsUnique` and `completed`.
- `EditorMode.swift` — `PlanEditorMode`/`ExerciseEditorMode`/`ReorderDeleteMode` enums.
- `WorkoutActivityAttributes` — ActivityKit. Static: `planName`. Dynamic: `percentCompleted`, `isResting`, `restEndDate`, `nextExerciseName`, `nextSetDescription`. Compiled into Forge + ForgeWidgetsExtension.
- `PlanTransferType.swift` — `UTType.forgePlan` + `WorkoutPlan: Transferable`. `sharePreviewImage` pre-renders `dumbbell.fill` to 160pt UIImage (handing `Image(systemName:)` to `SharePreview` renders blank).

## Key Views (`Forge/Views/`)

Views with non-obvious behaviors:

- `WorkoutInProgressView` — active workout. Live Activity + HealthKit + stopwatch + break timer + collab + chat. Joint-mode avatar gutter + anchor-driven row positioning.
- `HistoryView` — read-only past workout. Segmented tabs: Most Recent (calories/completion/duration + per-exercise sets) and Full History (per-exercise progress cards: Weight PR / Reps PR + Weight↔Reps line chart via SwiftUI Charts).
- `SetView` — reusable row. `Content`(`.individual`/`.summary`) × `Appearance`(`.standard`/`.muted`/`.workoutActive`/`.workoutActiveCollab`).
- `BreakTimerView` — configurable rest timer (`TimelineView`) + `UNTimeIntervalNotificationTrigger`.
- `WorkoutChatToolbar` — mid-workout chat. ZStack sibling of bottom toolbar; expands upward; rises with keyboard via parent's manual avoidance.
- `WorkoutWithFriendView` — collab Copy/Share. `activeWorkoutPlan` switches History entry vs mid-workout invite.
- `PlanSuggestionView` — collab carousel + chat + Ready. `resolveCoverState()` runs match-and-route on appear + `workoutInProgress.id` change so re-joiners auto-route into active workout.
- `CollabChatPanel` — chat + `KeyboardPersistentTextView`. Custom long-press iMessage-Tapback reaction picker.
- `CollabStatusBanner` — capsule overlay. `.waitingForPeer` shows "Re-invite" reusing existing `sessionId`. `peerExitInfo` override for clean exits.

Other views (`SettingsView`, `SelectPlanView`, `PlanEditorView`, `ExerciseEditorView`, `HomogeneousSetPicker`, `HeterogeneousSetEditor`, `StartingCountdownView`, `WorkoutBottomToolbarView`, `ReorderDeleteView`, `BreakTimerWatchView`, `ConnectingView`, `JoinSessionView`) — read the file.

## Live Activity (`ForgeWidgets/`)

- `ForgeWidgetsBundle.swift` registers `WorkoutLiveActivity`. `WorkoutActivityAttributes.swift` lives in `Forge/Data Model/`, shared.
- Lock Screen, Dynamic Island compact + expanded.
- **Dynamic Island compact trailing % or countdown must be `frame(width: 36)` + `minimumScaleFactor(0.6)` to prevent island stretch.**
- Lifecycle hooks in `WorkoutInProgressView`: `startLiveActivity()`, `updateLiveActivity()`, `endLiveActivity()`.
- **`GlobalSettings` is NOT compiled into the widget — `WorkoutLiveActivity` defines its own `fgColor`.** `WidgetBackground` asset is `#161616`.

## HealthKit (`Forge/View Model/WorkoutHealthManager.swift`)

`@EnvironmentObject`. Authorizes write on `HKObjectType.workoutType()`, read on `activeEnergyBurned` + `heartRate`.

- Live session (iOS 26+): `startWorkoutSession()` → `HKWorkoutSession` + `HKLiveWorkoutBuilder` (HR + calories from Watch). `endWorkoutSession(completion:)` extracts calories via `workout.statistics(for: .activeEnergyBurned)`. Live Activity auto-surfaces on Watch.
- Calorie capture: `finishWorkout()` saves `CompletedWorkout` immediately with nil calories, patches via completion handler.
- Manual save fallback: `saveWorkout(...)` uses `HKWorkoutBuilder` for `.functionalStrengthTraining`.
- Lifecycle: session starts after the 3s countdown. `finishWorkout` ends if active else manual-saves; `cancelWorkout` ends unconditionally.
- **Gotcha:** Use `Swift.Set` (not `Set`) when calling HealthKit APIs — the project's `Set` data model shadows Swift's built-in.

## Apple Watch (`ForgeWatch/`)

Standalone watchOS app receiving break-timer state via WatchConnectivity. iOS won't route notifications to Watch while phone is foreground, so Watch handles haptics. `WatchSessionManager` (watch) ↔ `PhoneSessionManager` (phone, singleton activated in `ForgeApp.init()`); called from `WorkoutInProgressView` at timer start, dismiss, workout end.

- Wire: `timerStarted` (endDate, duration, exerciseName, setDescription), `timerDismissed`, `workoutEnded`.
- **Dual delivery:** every message via both `sendMessage` (real-time) AND `updateApplicationContext` (guaranteed eventual). Watch checks `receivedApplicationContext` on activation.
- **Haptic:** `WKInterfaceDevice.current().play(.notification)` when countdown hits zero or `timerStarted` arrives with already-past `endDate`.

## Plan Sharing (`.forgeplan`)

JSON-encoded `WorkoutPlan` under exported UTI `Ryan-Div.Forge.workoutPlan`. `SelectPlanView` swipe-right `ShareLink(item: plan)`. `PlanViewModel.importPlan(_:)` is the single import funnel — strips `completed`, clears `lastCompleted`, auto-suffixes name collisions, preserves `lineageId`. `CompletedWorkoutsView.onOpenURL` handles incoming files.

**Info.plist setup:** Forge target uses `GENERATE_INFOPLIST_FILE=YES` + `INFOPLIST_KEY_*`, but array-of-dict entries (document types, UTI, URL schemes) need a real plist. `Forge/Info.plist` holds only those; `INFOPLIST_FILE = Forge/Info.plist` merges keys on top. Extend it for new array-of-dict keys; don't flip back to pure build-settings generation.

## Collaborative Workout Feature

Two friends each running Forge join a shared real-time session. Host taps invite (`person.2.fill` on History or in-workout) → `WorkoutWithFriendView` → Copy/Share generates `forge://session/<uuid>`. Receiver auto-joins. Paired users see each other's set completions, break timers, profile avatars; chat during plan selection AND mid-workout. Clean exits broadcast `peerFinished`/`peerCancelled` → labeled banner. Backgrounding does NOT surface a disconnect — server marks slot `.away` for 5 min, peer sees dimmed avatar + moon badge, stable per-device participant ID rebinds the slot on reconnect.

**Stack:** self-hosted Swift server in `server/` (Hummingbird 2 + HummingbirdWebSocket, separate SwiftPM package). Public exposure via Cloudflare Quick Tunnel. Single WebSocket per client. In-memory session state. Capacity 2.

### Running the server (Mac mini)

```bash
cd server
swift build                                          # first time ~2 min
swift run ForgeServer                                # binds 127.0.0.1:8080
# In a second terminal:
cloudflared tunnel --url http://localhost:8080       # prints a trycloudflare.com URL
```

iOS hardcodes hostname in `SessionClient.serverHost`. `ForgeServer` restarts don't change tunnel URL; `cloudflared` restarts DO (must update + rebuild app).

### Server source layout (`server/Sources/ForgeServer/`)

- `main.swift` — top-level async entry.
- `Application+build.swift` — HTTP `/` health + `WS /sessions/:id` upgrade + per-connection task group.
- `Protocol.swift` — `ServerMessage`/`ClientMessage` enums + `Profile`/`PeerInfo`/`PlanSnapshot`. **Every protocol change requires server redeploy + app rebuild in lockstep.**
- `SessionManager.swift` — actor holding `[UUID: Session]`; lazy-creates on first `addParticipant`, deletes when empty. Per-session: `suggestedPlan`, `workoutInProgress`, per-participant `isReady` + `state: ParticipantState (.connected/.away(since:))` + `awayTimeout: Task`.

### Feature-specific gotchas

- **iOS backgrounding kills WebSockets within seconds (iOS 18 reliably; iOS 26 sometimes survives).** Mitigations: server lazy-creates sessions on first WS connect; client auto-reconnects via `.onChange(of: scenePhase)`; the away/return architecture makes brief backgrounds invisible.
- **Background-aware presence (away/return).** On `scenePhase → .background`, client awaits `goingBackground` (must flush during iOS's ~5s grace). Server marks slot `.away`, broadcasts `peerAway` (NOT `peerLeft`), starts 5-min timeout. Reconnect within window → `?participantId=<uuid>` lets `addParticipant` return `.rebound` → timeout cancelled, broadcast `peerReturned`. Timeout fires → real `peerLeft`. Other phone shows dimmed avatar + moon badge for `.away`; loud "Friend disconnected" only for true disconnects.
- **`peerReturned` re-broadcast must trigger from the still-paired peer, NOT the returning peer.** When OTHER peer was `.away` and returns, my `state` stayed `.paired`, so `.onChange(of: state) { case .paired }` doesn't fire. Returning peer's `reconnect()` cleared their per-peer dicts — they need ME to replay. `WorkoutInProgressView` has a SECOND observer on `peerAway` non-empty→empty calling `rebroadcastJointStateForPeer()`.
- **`disconnect()` clears `sessionId`; the read-loop error path does NOT.** Load-bearing for reconnect — clearing on socket error would lose rejoin target. Socket failures → `.disconnected(reason:)` with sessionId intact.
- **Hummingbird 2 `onUpgrade` context lacks `.parameters`.** Only `shouldUpgrade`'s context has route params. In `onUpgrade`, parse from `context.request.uri.path.split(separator: "/").last`. `participantId` from `context.request.uri.query`.
- **`main.swift` cannot contain `@main`** — filename itself makes it the entry point.
- **Cloudflare Quick Tunnel URL is ephemeral per `cloudflared` invocation.** Survives `ForgeServer` restarts, not `cloudflared` restarts.
- **Hummingbird's default `maxFrameSize` is 16 KB** — profile photos blow past it. `inbound.messages(maxSize:)` is the reassembled-*message* cap, NOT per-frame. Per-frame requires `WebSocketServerConfiguration.maxFrameSize: 1 << 20`. Without it, oversized frames close at protocol layer *before* `onUpgrade` sees anything.
- **`UIGraphicsImageRenderer` uses `UIScreen.main.scale` by default** — for wire transport, force `format.scale = 1.0`. `resizeImage` in `CollabHelpers.swift` does this.
- **Collab nav unwinds via state observer, not chained `dismiss()`.** `CompletedWorkoutsView` watches `sessionClient.state`; on `.idle` resets nav-destination flags. Deep views call only `sessionClient.disconnect()`.
- **Two `.fullScreenCover`/`.sheet` modifiers of the same flavor on the same view silently conflict** — only the first attaches. Use a single `.sheet(item:)` / `.fullScreenCover(item:)` driven by an `Identifiable` enum.
- **Joint-mode set sync is positional: `(exerciseIndex: Int, setIndex: Int)`.** Each peer may use their own local plan with their own UUIDs (same-plan-detection routing), so positional is the only encoding that resolves to "the same exercise" on both phones. `peerSetCompletion` wire and `PeerSetKey` carry no UUIDs. `SetSnapshot` has no id either.
- **`KeyboardPersistentTextView` intercepts `"\n"` in `shouldChangeTextIn` to fire `onSubmit` and return `false`,** keeping first-responder. SwiftUI `TextField` + `.submitLabel(.send)` + `.onSubmit` always dismisses the keyboard before the handler fires. Bonus: explicitly set `autocorrectionType = .no`, `spellCheckingType = .no`, `smartInsert/Dashes/QuotesType = .no` — SwiftUI's `.autocorrectionDisabled()` is inconsistent.
- **Multi-line chat input requires UITextView + `noIntrinsicMetric` width override.** Default UITextView (with `isScrollEnabled = false`) reports `intrinsicContentSize.width` = longest line — SwiftUI HStack honors that. `WrappingUITextView` returns `noIntrinsicMetric` for width. Height clamped via dynamic `@State` driven by `sizeThatFits`. Asymmetric `textContainerInset` (top: 8, bottom: 5) compensates for ascender > descender.
- **iOS QuickPath candidate ribbon is NOT app-disableable.** Drawn by system keyboard; only Settings → General → Keyboard → Slide to Type turns it off.
- **Mid-workout chat needs MANUAL keyboard avoidance.** SwiftUI default leaves Minimize Chat (below input field) hidden. `WorkoutInProgressView` opts the chat container out via `.ignoresSafeArea(.keyboard)`, manually tracks `keyboardHeight` (pulling animation duration from `userInfo`), drives `.padding(.bottom, X)` from it, AND shrinks `chatPanelHeight` by `(keyboardHeight - bottomToolbarHeight)` so chat container's TOP edge stays fixed.
- **Confetti must complete BEFORE collab disconnect fires.** Disconnect → `.idle` → state observer → nav unwind → `fullScreenCover` teardown happened mid-confetti. Disconnect now deferred inside the 2s `asyncAfter` block alongside `dismiss()`.
- **`Forge/Views/` is a `PBXFileSystemSynchronizedRootGroup`** — drop `.swift` files in subdirs and they auto-link. `Forge/View Model/` and `Forge/Data Model/` are traditional groups; new files need pbxproj surgery.
- **`@EnvironmentObject` does NOT auto-propagate from `@StateObject` parent** — must explicitly `.environmentObject(...)`. SessionClient lives as `@StateObject` on `CompletedWorkoutsView`; inject ONCE on NavigationStack.
- **Avatar position must be `@State`, not derived.** Computing it from set-completion + `timerEnabled` + `isEnteringRest` caused intermediate-state flash bugs because those don't transition atomically inside one body eval. Promoted to `@State`, written ONCE per discrete event via `recomputeMyPosition()`. New inputs go through `recomputeMyPosition`.
- **Avatar gutter geometry is anchor-driven**, not parallel-VStack. Hardcoded row heights drifted when an exercise name wrapped. Use `RowAnchorKey: PreferenceKey<[RowID: Anchor<CGRect>]>` from each row via `.anchorPreference(value: .bounds)`, resolved by `.overlayPreferenceValue` absolutely positioning one `avatarColumn` per row at its measured `midY`.
- **Stale per-peer state must be cleared on BOTH `reconnect()` AND `peerLeft`.** Server assigns fresh `myId` per WS connection. `peerProfiles`/`peerPositions`/`peerBreakTimer`/`peerReady` (keyed by peer UUID) lingered as ghost "?" avatars without this. `peerCompletedSets` keyed positionally doesn't need this.
- **After every `.paired` transition, re-broadcast joint state.** Server only persists `suggestedPlan` + `workoutInProgress`. `WorkoutInProgressView`'s `.onChange(of: state) { case .paired }` calls `rebroadcastJointStateForPeer()`, iterating `activePlan.exercises.enumerated()` emitting positional `setCompletion`. Symmetric, idempotent.
- **Hummingbird autoPing is 30s; iOS-side `sendPing` is the missing complement.** Dead connections only surface when next outbound message fails. `pingTask` in `openSocket` calls `sendPing` every 30s; pong-error → `.disconnected` → auto-reconnect.
- **Mid-workout rejoin needs server-side `workoutInProgress` tracking.** Without it a rejoiner can stomp partner's active workout. Server records on all-ready transition, persists for session lifetime, sends in `welcome`. iOS routes rejoiner straight into `WorkoutInProgressView`.
- **`@StateObject` lifecycle vs `disconnect()` vs `reconnect()`.** `disconnect()` is user-initiated, clears EVERYTHING incl. `sessionId` + `hasSubmittedProfile` → `.idle`. `reconnect()` for transient drops — preserves `sessionId`, `hasSubmittedProfile`, `myProfile`, `chatEntries` but clears per-peer dicts. Combine state sink that schedules reconnect guards on `sessionId != nil`.
- **Clean exit broadcast must flush before close frame.** `sendWorkoutFinished/CancelledAndDisconnect()` use awaited `task.send` (not fire-and-forget) so message lands before `disconnect()` closes socket. Without await, peer sees a generic disconnect instead of the labeled exit banner.
- **Don't use `.contextMenu` for the chat reaction picker.** Native lift/dismiss produces platform-specific glitches: badge clipping during lift snapshot, iOS 18 bubble wobble (UIKit layer outside SwiftUI's transactions), behind-bubble flash on stamp. Custom long-press picker (`onLongPressGesture` + sibling capsule view in per-row VStack) sidesteps all of it.
- **Reaction picker emoji must be `Text` + `.onTapGesture`, not `Button`.** Even with `.buttonStyle(.plain)`, iOS button tint absorbs colored emoji glyphs.
- **Chat reactions wire protocol shares a `messageId` between peers.** `ChatEntry.id` is the shared id — sender mints it once, server forwards inside `peerChat`, both peers key the same row. Lets `setReaction`/`peerReactionChanged` address a specific message.
- **Same-plan-detection routing.** `PlanViewModel.findMatch(forFingerprint:lineageId:)` returns `.fingerprintMatch` (silent reuse of B's local plan, preserves B's weights/reps), `.lineageMatch` (divergence sheet), or `.none` (auto-import). Fingerprint excludes weights/reps/tillFailure — only structure (exercise names + set counts). `PlanSuggestionView.routeIntoActiveWorkout(snapshot:)` switches on it. Auto-import branches set `lastAutoImportedPlanName` → `CompletedWorkoutsView` shows a 4s capsule toast. **Divergence sheet has only "use friend's version" options — no "use my version".** Positional sync requires shared structure. Options: ephemeral (read-only, `activePlanIndex = -1`) or persistent (import as new plan with name suffix). Routing always sets a valid `activePlanIndex`, so the prior stale-index destructive overwrite at `WorkoutInProgressView.finishWorkout`/`cancelWorkout` is unreachable. Don't reintroduce a write site that bypasses this routing.

## Timer & Notification System

- Workout start countdown: 3s, skippable. `StartingCountdownView` signals via `onCompletion`.
- Rest timer: 5–300s (default 60s). `BreakTimerView` uses `TimelineView(.periodic(from:by:))` (immune to parent re-renders, unlike `Timer.publish`); schedules `UNTimeIntervalNotificationTrigger` for backgrounded alert.
- Foreground suppression: `AppDelegate.userNotificationCenter(_:willPresent:)` suppresses `"workoutCategory"` notifications while app is active.

**Critical race:** `dismissBreakTimerView(cancelPendingNotification:)` — natural-expiry path (`onExpired`) MUST pass `false`, otherwise the in-app timer cancels the notification at the moment iOS is delivering it. Bites hardest under Xcode debugger (keeps app alive in background → in-app timer keeps ticking and races system delivery). X/Done paths pass `true`.

## Testing

- Framework: Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest.
- Target: `ForgeTests/` (`PBXFileSystemSynchronizedRootGroup`).
- Suites: `ExerciseTests` (8), `PlanViewModelTests` (28), `CompletedWorkoutsViewModelTests` (23), `ValidationTests` (6), `WorkoutPlanFingerprintTests` (12), `SessionClientTests` (31) — 108 cases.
- Persistence isolation: test classes touching persistence are `final class` (init/deinit = setUp/tearDown). Each gets its own `UserDefaults(suiteName: "ForgeTests.\(UUID().uuidString)")`, removes domain in `deinit`.
- Mock data: `Forge/View Model/MockData.swift` exposes `mockWorkoutPlans` + `mockCompletedWorkouts` as module-internal globals. Tests use `@testable import Forge`.

## Subtle gotchas

- **`Timer.publish` in child views breaks when parents re-render frequently.** `WorkoutInProgressView` updates `elapsedSeconds` every second; children using `Timer.publish` get recreated and never fire. Use `TimelineView`.
- **`didSet` on `@Published` properties breaks `objectWillChange`** — compiler-generated setter bypasses property wrapper's `objectWillChange.send()`. Use a Combine `$prop.dropFirst().sink` subscriber for side effects (see `GlobalSettings.colorTheme`).
- **`navigationBarTitleTextColor` must force-update existing bars.** `UINavigationBar.appearance()` only applies to newly created bars. Extension in `CompletedWorkoutsView.swift` traverses all `UIWindowScene` windows on `.onChange(of: color)` and directly sets `standardAppearance`/`scrollEdgeAppearance`.
- **Multiple `Button`s in a single `List` row require `.buttonStyle(.borderless)`.** Without it, List treats the whole row as one tappable area and fires the last button's action regardless of tap location.
- **`UIScreen.main.bounds`** still used in `WorkoutInProgressView`, `BreakTimerView`, `ConfettiView`, `WorkoutWithFriendView`, `ExerciseEditorView`. Deprecated in iOS 16+ but doesn't warn at our deployment target. Roadmap migrates to `GeometryReader`.
- **`activeExerciseIndex` is stale in `.add` mode.** `ExerciseEditorView.saveExercise()` gates `existingExercise` lookup on mode being `.edit`/`.log` — never trust `activeExerciseIndex` in `.add` mode.
- **Don't put workflow-critical `@StateObject`s on the `App` struct if any view's `onAppear` resets navigation flags.** Promoting `PlanViewModel` to `@StateObject` on `ForgeApp` caused Scene body to re-evaluate on every publish, popping the workout fullScreenCover every time a plan was tapped. Working pattern: inline `.environmentObject(PlanViewModel())` in `ForgeApp.body` + `@EnvironmentObject` in views. App-wide hooks like `.onOpenURL` attach to root *view*, not Scene.
- **`SessionClient.State` carries peerIds in the `.paired` case** — there is no independent `@Published peerIds`; the "connected without peers" illegal state is unrepresentable. Read via `sessionClient.isPaired`, pattern-match `case .paired(let ids) = state`, or use the `peerIds` computed accessor (returns `[]` in non-paired).
- **`Log.debug(_:)` is the project's logging channel** (`Forge/View Model/Log.swift`) — `@autoclosure` + `#if DEBUG`-guarded. Use it instead of `print` in the Forge target. `ForgeWatch` still uses bare `print`. For user-visible error surfaces, still use a banner / alert per "Fail Loud, Never Fake".
- **`LinearGradient`'s `startPoint`/`endPoint` are NOT animatable via `withAnimation`** — wrapping endpoint changes snaps to the final state. For continuously-animating gradients, drive phase from `TimelineView(.animation) { context in ... }` recomputing endpoints from wall-clock time.
- **`@FocusState` set during a present transition gets silently dropped.** Auto-focusing a TextField in a sheet/nav-pushed view's `.onAppear` requires a small delay (~0.4s).
- **`Charts` is imported only by `ExerciseProgressCard`** (Full History tab). Don't pull it into `ForgeWidgets` or `ForgeWatch`. `progressSeries`/`weightPR`/`repsPR` on `CompletedWorkoutsViewModel` exclude incomplete sets per "Fail Loud, Never Fake".

## Future development roadmap

- [ ] **Server upgrade: production deployment + background chat notifications** — Cloudflare Named Tunnel + launchd supervision + secrets baseline + server-side chat history + APNs push. Full plan in `server-upgrade-plan.md`.
- [~] **UI refactor: multi-iPhone-size support** — partial. Target SE 3rd gen → 17 Pro Max, portrait-only. Outstanding: replace remaining `UIScreen.main`, verify `SetView` strikethrough alignment on small/large screens, break-timer panel still uses `topToolBarHeight = screenHeight * 0.8` leaving excess space on Air / Pro Max.
- [x] **Plan identity layers + same-plan collab + progress history** — `lineageId`/`fingerprint`; collab same-plan detection + positional set sync + divergence sheet; per-exercise progress visualization in `HistoryView` Full History tab.
- [ ] **Advanced UI / animation polish** — final pass before TestFlight.
- [ ] **TestFlight deployment**.
- [ ] **App Store submission**.

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
