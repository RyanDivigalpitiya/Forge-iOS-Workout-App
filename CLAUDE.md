# CLAUDE.md

Guidance for Claude Code in this repository.

## Project Overview

Forge — minimal native iOS weightlifting app (SwiftUI, Swift 5). Only system frameworks (SwiftUI, Combine, UIKit, UserNotifications, ActivityKit, WidgetKit, HealthKit, WatchConnectivity). Dark-mode only. Apple Watch companion (haptic break-timer alerts) + self-hosted Swift server (`server/`) for collaborative workouts. Flow: History → Plan Selector → Active Workout → History.

## Build, Run & Test

```bash
open Forge.xcodeproj
xcodebuild -project Forge.xcodeproj -scheme Forge -configuration Debug
xcodebuild test -project Forge.xcodeproj -scheme Forge \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- Targets: iOS 18.6 (`Forge`, `ForgeWidgetsExtension`), watchOS 11.0 (`ForgeWatch`), iOS 26.4 simulator-only (`ForgeTests`).
- Bundle IDs: `Ryan-Div.Forge`, `Ryan-Div.Forge.ForgeWidgets`, `Ryan-Div.Forge.watchkitapp`, `Ryan-Div.ForgeTests`.
- Builds must be **warning-free**. Fix new deprecation warnings in the same change.

## Architecture

**MVVM + SwiftUI EnvironmentObjects** injected at `ForgeApp.swift`:

- `CompletedWorkoutsViewModel` — workout history CRUD/formatting
- `PlanViewModel` — plan CRUD, reorder, duration estimation, exercise transfer
- `ExerciseViewModel` — active exercise state during editing
- `WorkoutHealthManager` — HealthKit auth, live workout sessions (iOS 26+), manual saves
- `GlobalSettings.shared` — theming singleton, also `@EnvironmentObject` for reactive theme

All ViewModels are `ObservableObject` with `@Published`.

**Persistence:** UserDefaults + JSON `Codable`. Keys: `"workoutPlans"`, `"completedWorkouts"`, `"breakDurationSeconds"`, `"colorTheme"`, `"collabProfile"`. `PlanViewModel`/`CompletedWorkoutsViewModel` accept `userDefaults:` so tests inject isolated suites.

**Theming:** `GlobalSettings.shared` (`Forge/View Model/GlobalSettings.swift`). `fgColor` from `@Published colorTheme: ColorTheme` (persisted via Combine sink — **not** `didSet`, which breaks `objectWillChange` on `@Published`). Six themes: red (default `#FF436B`), blue, green, orange, purple, yellow. Background `#161616`. Reference `settings.fgColor` (not local copies). Constants: `darkGray`, `editorDarkGray`, `buttonCircleBgColor`, `setButtonSize`, `setsFontSize`, `setsSpacing`, `bottomToolbarHeight`, `cornerRadiusSmall/Medium/Large` (5/8/16), `animationQuick/Standard/Slow` (0.2/0.5/1.0). `breakDuration` UserDefaults-backed (default 60s, range 5–300s).

## Data Models (`Forge/Data Model/`)

- `WorkoutPlan` → `[Exercise]` → `[Set]` (weight, reps, tillFailure, completed). All `Identifiable + Codable` with UUIDs. `WorkoutPlan` also carries `lineageId: UUID?` (stable identity preserved through imports — `importPlan` propagates the source's; collab auto-import does too) and `fingerprint: String?` (SHA-256 over ordered `(lowercased trimmed exerciseName, setCount)` pairs via `WorkoutPlan.computeFingerprint(for:)`; auto-refreshed via `exercises.didSet`; defines structural equality for "same plan" matching). Both optional for backward-compat decode of legacy blobs and historical `CompletedWorkout.workout` snapshots; one-shot `migrateLineageAndFingerprintIfNeeded()` in `PlanViewModel.init()` backfills live records. `PlanSnapshot` (wire) carries the same two fields so the receiver can run `findMatch` on incoming suggestions.
- `CompletedWorkout` — date, elapsed time, completion %, optional `caloriesBurned: Double?`.
- `Exercise.sets` `didSet` auto-computes `areSetsUnique` and `completed`.
- `EditorMode.swift` — `PlanEditorMode`/`ExerciseEditorMode`/`ReorderDeleteMode` enums.
- `WorkoutActivityAttributes` — ActivityKit contract. Static: `planName`. Dynamic: `percentCompleted`, `isResting`, `restEndDate`, `nextExerciseName`, `nextSetDescription`. Compiled into Forge + ForgeWidgetsExtension.
- `PlanTransferType.swift` — `UTType.forgePlan` + `WorkoutPlan: Transferable`. `WorkoutPlan.sharePreviewImage` pre-renders `dumbbell.fill` to a 160pt UIImage (handing `Image(systemName:)` directly to `SharePreview` renders blank).

## Key Views (`Forge/Views/`)

| View | Purpose |
|------|---------|
| `CompletedWorkoutsView` | Home — history list, settings + Add Friend |
| `SettingsView` | Theme picker + per-plan "Reset Last Completed" |
| `SelectPlanView` | Manage plans — swipe-right share, swipe-left delete, drag reorder |
| `PlanEditorView` | Create/edit plan — inline reorder/delete + swipe-right exercise transfer |
| `ExerciseEditorView` | Add/edit exercises — coordinator |
| `HomogeneousSetPicker` | 3-column wheel pickers (sets × weight × reps) |
| `HeterogeneousSetEditor` | Per-set rows w/ weight/reps/till-failure |
| `WorkoutInProgressView` | Active workout — Live Activity + HealthKit + stopwatch + break timer + collab + chat |
| `StartingCountdownView` | 3s pre-workout countdown |
| `BreakTimerView` | Configurable rest timer (`TimelineView`) + notification |
| `WorkoutBottomToolbarView` | Add/Done/Edit (ignores keyboard) |
| `WorkoutChatToolbar` | Mid-workout chat container — ZStack sibling of bottom toolbar; expands upward; rises with keyboard via parent's manual avoidance |
| `SetView` | Reusable row. `Content`(`.individual`/`.summary`) × `Appearance`(`.standard`/`.muted`/`.workoutActive`/`.workoutActiveCollab`) |
| `HistoryView` | Read-only past workout — calories/completion/duration |
| `ReorderDeleteView` | Reorder/delete sheet |
| `BreakTimerWatchView` | watchOS break timer — countdown ring + haptic |
| `WorkoutWithFriendView` | Collab — Copy/Share. `activeWorkoutPlan` switches History entry vs mid-workout invite |
| `ConnectingView` | Collab — state-driven banner; auto-advances to `JoinSessionView` |
| `JoinSessionView` | Collab — name + `PhotosPicker`. `onSoloProfileSaved` enables solo-profile-entry mode (mid-workout invite) |
| `PlanSuggestionView` | Collab — carousel + chat + Ready. Auto-routes re-joiners via `workoutInProgress`. Shimmer via `TimelineView` |
| `CollabChatPanel` | Reusable chat (scroll + input + `KeyboardPersistentTextView`). `showAvatarHeader` opt-in. Drag-down + scroll-down dismiss keyboard. Custom long-press iMessage-Tapback reaction picker |
| `CollabStatusBanner` | Capsule overlay. `.waitingForPeer`/`.connecting`/`.disconnected`/`.error` + Re-invite. `peerExitInfo` override: "Friend finished/left" |

## Live Activity (`ForgeWidgets/`)

- `ForgeWidgetsBundle.swift` registers `WorkoutLiveActivity`. `WorkoutActivityAttributes.swift` lives in `Forge/Data Model/`, shared.
- **Lock Screen:** plan name, %, countdown timer (when resting), "Up next".
- **Dynamic Island compact:** dumbbell↔timer leading. Trailing % or `Text(timerInterval:)` countdown — must be `frame(width: 36)` + `minimumScaleFactor(0.6)` to prevent island stretch.
- **Dynamic Island expanded:** plan name, %, countdown, next exercise/set.
- **Lifecycle hooks** in `WorkoutInProgressView`: `startLiveActivity()`, `updateLiveActivity()`, `endLiveActivity()`.
- **Colors:** `GlobalSettings` is NOT compiled into widget extension — `WorkoutLiveActivity` defines its own `fgColor`. `WidgetBackground` asset is `#161616`.

## HealthKit (`Forge/View Model/WorkoutHealthManager.swift`)

`@EnvironmentObject`. Authorizes write on `HKObjectType.workoutType()`, read on `activeEnergyBurned` + `heartRate`.

- **Live session (iOS 26+):** `startWorkoutSession()` → `HKWorkoutSession` + `HKLiveWorkoutBuilder` (HR + calories from Watch). `endWorkoutSession(completion:)` extracts calories via `workout.statistics(for: .activeEnergyBurned)`. Live Activity auto-surfaces on Watch.
- **Calorie capture:** `finishWorkout()` saves `CompletedWorkout` immediately with nil calories, patches via completion handler.
- **Manual save (fallback):** `saveWorkout(...)` uses `HKWorkoutBuilder` for `.functionalStrengthTraining`.
- **Lifecycle:** Session starts after the 3s countdown. `finishWorkout` ends if active else manual-saves; `cancelWorkout` ends unconditionally.
- **Gotcha:** Use `Swift.Set` (not `Set`) when calling HealthKit APIs — the project's `Set` data model shadows Swift's built-in.

## Apple Watch (`ForgeWatch/`)

Standalone watchOS app receiving break-timer state via WatchConnectivity. iOS won't route notifications to Watch while phone is in foreground, so Watch handles haptic alerts.

- `ForgeWatchApp.swift` activates `WatchSessionManager` on init.
- `WatchSessionManager.swift` — `WCSessionDelegate` singleton; `@Published timerState` (`.idle`/`.counting`/`.expired`).
- Phone side: `PhoneSessionManager.swift` (singleton activated in `ForgeApp.init()`), called at three sites in `WorkoutInProgressView`: timer start, dismiss, workout end.
- **Wire protocol:** `timerStarted` (endDate, duration, exerciseName, setDescription), `timerDismissed`, `workoutEnded`.
- **Dual delivery:** every message via both `sendMessage` (real-time) AND `updateApplicationContext` (guaranteed eventual). Watch checks `receivedApplicationContext` on activation.
- **Haptic:** `WKInterfaceDevice.current().play(.notification)` when countdown hits zero or `timerStarted` arrives with already-past `endDate`.

## Plan Sharing (`.forgeplan`)

JSON-encoded `WorkoutPlan` under exported UTI `Ryan-Div.Forge.workoutPlan`.

- `Forge/Data Model/PlanTransferType.swift` — `UTType.forgePlan` + `WorkoutPlan: Transferable`.
- `Forge/Info.plist` — `UTExportedTypeDeclarations` + `CFBundleDocumentTypes` (`LSHandlerRank=Owner`, `LSSupportsOpeningDocumentsInPlace=false` — Forge always copies to its library).
- `SelectPlanView` leading-edge `.swipeActions` with blue `ShareLink(item: plan)`.
- `PlanViewModel.importPlan(_:)` — single funnel. Strips `completed`, clears `lastCompleted`, auto-suffixes name collisions.
- `CompletedWorkoutsView.onOpenURL` decodes incoming `.forgeplan`.

**Info.plist setup:** Forge target uses `GENERATE_INFOPLIST_FILE=YES` + `INFOPLIST_KEY_*` for most values, but array-of-dictionary entries (document types, UTI, URL schemes) need a real plist. `Forge/Info.plist` holds only those; `INFOPLIST_FILE = Forge/Info.plist` merges keys on top. Extend this file for new array-of-dict keys; don't flip back to pure build-settings generation.

## Collaborative Workout Feature

Two friends each running Forge join a shared real-time session. Host taps invite (`person.2.fill` on History or in-workout) → `WorkoutWithFriendView` → Copy/Share generates `forge://session/<uuid>`. Receiver taps link, Forge auto-joins. Paired users see each other's set completions, break timers, profile avatars; chat during plan selection AND mid-workout. Clean exits (Done/Cancel) broadcast `peerFinished`/`peerCancelled` so still-working friend sees a labeled banner. Backgrounding does NOT surface a disconnect — server marks slot `.away` for 5 min, peer sees dimmed-avatar + moon badge, stable per-device participant ID rebinds the slot on reconnect.

**Stack:** self-hosted Swift server in `server/` (Hummingbird 2 + HummingbirdWebSocket, separate SwiftPM package). Public exposure via Cloudflare Quick Tunnel (`*.trycloudflare.com`). Single WebSocket per client. In-memory session state. Capacity 2.

### Running the server (Mac mini)

```bash
cd server
swift build                                          # first time ~2 min
swift run ForgeServer                                # binds 127.0.0.1:8080
# In a second terminal:
cloudflared tunnel --url http://localhost:8080       # prints a trycloudflare.com URL
```

iOS hardcodes hostname in `SessionClient.serverHost`. `ForgeServer` restarts don't change tunnel URL; `cloudflared` restarts DO (must update + rebuild app).

### File map

**Server (`server/`):**

- `Sources/ForgeServer/main.swift` — top-level async entry (filename = `main.swift` so no `@main`).
- `Application+build.swift` — HTTP `/` health + `WS /sessions/:id` upgrade + per-connection task group. Parses `?participantId=<uuid>` from query. Handles `setReady`/`workoutFinished`/`workoutCancelled`/`goingBackground`/`returningToForeground`. Cleanup skips `removeParticipant` when `.away`.
- `Protocol.swift` — `ServerMessage`/`ClientMessage` enums + `Profile`/`PeerInfo`/`PlanSnapshot`. Codable + Sendable. **Every protocol change requires server redeploy + app rebuild in lockstep.**
- `SessionManager.swift` — actor holding `[UUID: Session]`; lazy-creates on first `addParticipant`; deletes when empty. Per-session: `suggestedPlan`, `workoutInProgress` (set on all-ready transition; persists for session lifetime; cleared on finish/cancel), per-participant `isReady` + `state: ParticipantState (.connected/.away(since:))` + `awayTimeout: Task`. `addParticipant` returns `.added` (fresh slot → `peerJoined`) or `.rebound` (reconnect into `.away` slot → `peerReturned`). `setReady` returns true on just-became-all-ready.

**iOS (Forge target):**

- `Forge/View Model/SessionClient.swift` — `@MainActor` ObservableObject. State: `.idle`/`.connecting`/`.waitingForPeer`/`.paired(peerIds: [UUID])`/`.disconnected(reason:)`/`.error(_)`. Wire types: `Profile`, `PeerInfo`, `PlanSnapshot`, `ChatEntry` (`myReaction`/`peerReaction`; `id` is shared message id minted by sender, forwarded by server in `peerChat`), `PeerSetKey`, `UserPosition`, `PeerBreakTimer`, `PeerExitInfo`. Owned by `CompletedWorkoutsView` as `@StateObject` (NOT `ForgeApp`) and injected at NavigationStack root. See gotchas below for stable participant ID, heartbeat, auto-reconnect, await-flush behavior.
- `Forge/Views/Collab/`:
  - `WorkoutWithFriendView.swift` — `activeWorkoutPlan: WorkoutPlan?` switches: nil (History) → `createSession()` + push `ConnectingView`; non-nil (mid-workout) → `startSharedSessionForActiveWorkout(plan:)` + dismiss. Single `.sheet(item: $activeSheet)` covers iOS share sheet AND workout-mode profile prompt. When host has no profile in workout mode, presents `JoinSessionView(onSoloProfileSaved:)`; closure dismisses then re-fires action one runloop tick later (UIKit needs the hop).
  - `JoinSessionView.swift` — name + `PhotosPicker`. `autoSubmitIfCachedProfile()` skips form for returning users. `onSoloProfileSaved` activates solo-profile-entry mode (hides peer half, suppresses End Session toolbar, button "Save", title "Your Profile", skips auto-submit + nav). `@FocusState` auto-focuses empty name field 0.4s after appear.
  - `PlanSuggestionView.swift` — carousel + `CollabChatPanel()` + Ready + single `.fullScreenCover(item:)` enum-driven cover for `PlanEditorView` (preview) and `WorkoutInProgressView` (post-ready). `routeIntoActiveWorkoutIfNeeded()` (on appear + `onChange(of: workoutInProgress?.id)`) auto-routes re-joiners straight into active workout.
  - `CollabChatPanel.swift` — chat surface + `KeyboardPersistentTextView` (UIViewRepresentable wrapping `WrappingUITextView`, a UITextView subclass returning `noIntrinsicMetric` for width). `showAvatarHeader` opt-in. Custom reaction picker: long-press peer bubble (0.3s) → medium haptic + spring-animates horizontal emoji capsule (six iMessage Tapbacks + X) as SIBLING of bubble in per-row VStack. Badge `Text(emoji).background(Circle())` with `.offset(x: ±12, y: 14)`; LazyVStack spacing 16 clears protrusion.
  - `CollabStatusBanner.swift` — capsule overlay. Hidden in `.paired`/`.idle`. `.waitingForPeer` shows "Re-invite" that share-sheets EXISTING `sessionId` URL (does NOT call `createSession()`). Clean-exit override: `peerExitInfo` set → "Friend finished/left workout" for ~5s then auto-dismisses; presence suppresses disconnect/Re-invite chrome for rest of session. Does NOT surface peer backgrounding — that's avatar-level only.
  - `PlanCarouselCard.swift`, `PlanInfoBlock.swift` — shared plan-display pieces.
  - `CollabHelpers.swift` — `avatar`, `initial`, `resizeImage`, `ShareSheet`, `ShareableURL`, `awayDimmedAvatar` (opacity 0.45 + moon.fill badge for chat header; workout gutter uses inline opacity-only).
- `Forge/Views/History/CompletedWorkoutsView.swift` — Add Friend toolbar, `forge://session/<id>` routing in `.onOpenURL`. `.onChange(of: scenePhase)`: `.active` → `reconnect()` + `sendReturningToForeground()`, `.background` → `Task { await sessionClient.sendGoingBackgroundAndAwait() }`. `.onChange(of: sessionClient.state)` → resets nav-destination flags on `.idle`. NavigationStack is closed by `.environmentObject(sessionClient)`.
- `Forge/Views/Workout/WorkoutInProgressView.swift` — gains `@EnvironmentObject var sessionClient`. In joint mode (`sessionClient.isPaired`) per-exercise cards get empty `Color.clear.frame(width: gutterWidth)` leading placeholder; `.overlayPreferenceValue(RowAnchorKey.self)` reads each row's bounds anchor and absolutely positions one `avatarColumn` per row at its measured `midY`. Peer avatars dim to 0.45 when `peerAway[peerId] != nil`. `myPosition` is `@State` written via `recomputeMyPosition()`. `.onChange(of: state)` matching `.paired` AND `.onChange(of: peerAway)` going non-empty → empty BOTH call `rebroadcastJointStateForPeer()`. `finishWorkout`/`cancelWorkout` send via async `sendAndAwait`; disconnect deferred inside 2s confetti `asyncAfter`. Mid-workout invite button (`person.2.fill`, visible when `sessionId == nil` OR `peerExitInfo != nil`). Mid-workout chat: `WorkoutChatToolbar` as ZStack sibling of `WorkoutBottomToolbarView`. Anchor-preference types in sibling `WorkoutAvatarGutter.swift`.
- `Forge/Views/Shared/SetView.swift` — `Appearance.workoutActiveCollab(isCompleted:)`: weight/reps as single grey chip (e.g. `100 lb x 12 reps`), `.lineLimit(1)`. Set # label drops to 13pt + 46/54pt frame.
- `Forge/Info.plist` — `CFBundleURLTypes` registers `forge://`.

### Feature-specific gotchas

- **iOS backgrounding kills WebSockets within seconds (iOS 18 reliably; iOS 26 sometimes survives a brief blip).** Mitigations: server lazy-creates sessions on first WS connect; client auto-reconnects via `.onChange(of: scenePhase)`; the away/return architecture below makes brief backgrounds invisible to peer.
- **Background-aware presence (away/return).** On `scenePhase → .background`, client awaits `goingBackground` (must flush during iOS's ~5s grace). Server marks slot `.away`, broadcasts `peerAway` (NOT `peerLeft`), starts 5-min timeout. If client reconnects within window, `?participantId=<uuid>` lets `addParticipant` return `.rebound` — timeout cancelled, broadcast `peerReturned`. If timeout fires, server promotes to real `peerLeft`. Other phone shows dimmed-avatar + moon-badge for `.away`; loud "Friend disconnected" banner only for true disconnects (force-quit, network drop, crash).
- **`peerReturned` re-broadcast must trigger from the still-paired peer, NOT the returning peer.** When OTHER peer was `.away` and returns, my `state` stayed `.paired` throughout, so `.onChange(of: state) { case .paired }` doesn't fire on my side. But returning peer's `reconnect()` cleared their per-peer dicts — they need ME to replay. `WorkoutInProgressView` has a SECOND observer on `peerAway` firing `rebroadcastJointStateForPeer()` when dict transitions non-empty → empty.
- **`disconnect()` clears `sessionId`; the read-loop error path does NOT.** Load-bearing for reconnect — clearing on socket error would lose rejoin target. `disconnect()` is user-initiated. Socket failures → `.disconnected(reason:)` with sessionId intact.
- **Hummingbird 2 `onUpgrade` context lacks `.parameters`.** Only `shouldUpgrade`'s context has route params. In `onUpgrade`, parse from `context.request.uri.path.split(separator: "/").last`. `participantId` parsed from `context.request.uri.query`.
- **`main.swift` cannot contain `@main`** — filename itself makes it the entry point. Use top-level async.
- **Cloudflare Quick Tunnel URL is ephemeral per `cloudflared` invocation.** Survives `ForgeServer` restarts, not `cloudflared` restarts.
- **Hummingbird's default `maxFrameSize` is 16 KB** — profile photos blow past it. `inbound.messages(maxSize:)` is the reassembled-*message* cap, NOT per-frame. Per-frame requires `WebSocketServerConfiguration.maxFrameSize: 1 << 20`. Without it, oversized frames close at protocol layer *before* `onUpgrade` sees anything; iOS reports successful send then "Socket is not connected" with no server trace.
- **`UIGraphicsImageRenderer` uses `UIScreen.main.scale` by default** — 256×192pt on a 3× phone produces 768×576 pixels (3× wire size). For wire transport, force `format.scale = 1.0`. `resizeImage` in `CollabHelpers.swift` does this.
- **Collab nav unwinds via state observer, not chained `dismiss()`.** `CompletedWorkoutsView` watches `sessionClient.state`; on `.idle` resets nav-destination flags, collapsing the whole stack. Deep views call only `sessionClient.disconnect()`.
- **Two `.fullScreenCover`/`.sheet` modifiers of the same flavor on the same view silently conflict** — only the first attaches. Use a single `.sheet(item:)` / `.fullScreenCover(item:)` driven by an `Identifiable` enum. `WorkoutWithFriendView` and `PlanSuggestionView` both do this.
- **Joint-mode set-completion sync keys off `(exerciseIndex: Int, setIndex: Int)` — purely positional.** Phase C introduced same-plan detection: each peer may be working from their own local plan with their own UUIDs (when fingerprints match). Positional addressing is the only encoding that resolves to "the same exercise" on both phones. `PlanSnapshot.toWorkoutPlan()` still preserves the snapshot's UUIDs (cosmetic — used for the read-only preview), but the wire `peerSetCompletion` and the `PeerSetKey` storage no longer reference any UUID. Set positions also use positional index (`SetSnapshot` has no id).
- **SwiftUI `TextField` with `.submitLabel(.send)` + `.onSubmit` always dismisses keyboard before handler fires** — visible flicker even with immediate `@FocusState` re-assertion. `KeyboardPersistentTextView` wraps `UITextView`; `textView(_:shouldChangeTextIn:replacementText:)` intercepts `"\n"` to fire `onSubmit` and returns `false`, keeping first-responder. Bonus: `autocorrectionType = .no` + `spellCheckingType = .no` + `smartInsert/Dashes/QuotesType = .no` reliably suppress QuickType + smart punctuation — SwiftUI's `.autocorrectionDisabled()` is inconsistent.
- **Multi-line chat input requires UITextView + `noIntrinsicMetric` width override.** UITextField is single-line. Default UITextView (with `isScrollEnabled = false`) reports `intrinsicContentSize.width` = longest line — SwiftUI's HStack honors that. `WrappingUITextView` overrides to return `noIntrinsicMetric` for width, so `.frame(maxWidth: .infinity)` constrains the field and UITextView wraps inside. SwiftUI clamps height via dynamic `@State` driven by `sizeThatFits` in `textViewDidChange`. Asymmetric `textContainerInset` (top: 8, bottom: 5) compensates for ascender > descender.
- **iOS QuickPath candidate ribbon is NOT app-disableable.** Drawn by system keyboard; only Settings → General → Keyboard → Slide to Type turns it off. Different from QuickType bar.
- **Joint-mode chat auto-scroll on keyboard appearance** subscribes to `keyboardDidShowNotification` + `keyboardDidChangeFrameNotification` and re-fires `scrollToLatest`. Drag-down dismissal: `.scrollDismissesKeyboard(.immediately)` on messages ScrollView + `simultaneousGesture(DragGesture)` on panel root for empty-state.
- **Mid-workout chat needs MANUAL keyboard avoidance.** SwiftUI default positions focused field above keyboard, leaving Minimize Chat (which sits BELOW the input field) hidden. `WorkoutInProgressView` opts the chat container out via `.ignoresSafeArea(.keyboard)`, manually tracks `keyboardHeight` via notifications (pulling system animation duration from `userInfo` so chat slide matches keyboard slide), drives `.padding(.bottom, X)` from it, AND shrinks `chatPanelHeight` by `(keyboardHeight - bottomToolbarHeight)` so chat container's TOP edge (avatar) stays fixed. The 3-button `WorkoutBottomToolbarView` separately ignores `.keyboard`.
- **Confetti must complete BEFORE collab disconnect fires.** Disconnect → `.idle` → state observer → nav unwind → `fullScreenCover` teardown happened mid-confetti. Disconnect now deferred inside the 2s `asyncAfter` block alongside `dismiss()`. Trade-off: peer sees "Friend finished" banner ~2s later — acceptable.
- **`Forge/Views/` is a `PBXFileSystemSynchronizedRootGroup`** — drop `.swift` files in subdirectories and they're auto-picked up. `Forge/View Model/` and `Forge/Data Model/` are still traditional groups; adding files needs pbxproj surgery.
- **`@EnvironmentObject` does NOT auto-propagate from a `@StateObject` parent** — must explicitly `.environmentObject(...)`. SessionClient lives as `@StateObject` on `CompletedWorkoutsView`; inject ONCE on the NavigationStack so all destinations + modals inherit it.
- **Avatar position must be `@State`, not derived.** Original `myPosition` was computed from set-completion + `timerEnabled` + `isEnteringRest` — these never transition atomically inside one body eval, so any reordering of writes inside the set-tap handler caused intermediate-state flash bugs. Promoted to `@State`, written ONCE per discrete event via `recomputeMyPosition()`. To add a new input, write through `recomputeMyPosition` — don't sprinkle conditionals at call sites.
- **Avatar gutter geometry is anchor-driven**, not parallel-VStack. Original used hardcoded row heights + `exerciseNameRowOffset = 73`; when an exercise name wrapped, gutter drifted. Replaced with `RowAnchorKey: PreferenceKey<[RowID: Anchor<CGRect>]>` published from each row via `.anchorPreference(value: .bounds)`, resolved by `.overlayPreferenceValue` on per-exercise HStack absolutely positioning one `avatarColumn` per row at its measured `midY`.
- **Stale per-peer state must be cleared on BOTH `reconnect()` AND `peerLeft`.** Server assigns fresh `myId` per WS connection. `peerProfiles`/`peerPositions`/`peerBreakTimer`/`peerReady` (all keyed by peer UUID) lingered as ghost "?" avatars without this. `peerCompletedSets` keyed by `(exerciseId, setIndex)` doesn't need this.
- **After every transition into `.paired`, re-broadcast joint state.** Server doesn't persist position / completed sets / break-timer — only `suggestedPlan` and `workoutInProgress`. So a fresh peer (or post-reconnect peer) has no knowledge until I act. `WorkoutInProgressView`'s `.onChange(of: state)` matching `.paired` calls `rebroadcastJointStateForPeer()`. Symmetric, idempotent. Iterates `activePlan.exercises.enumerated()` and broadcasts each completed set as `setCompletion(exerciseIndex: i, setIndex: j, completed: true)` (positional, post-Phase-C). Away-return needs the SECOND `peerAway`-emptied observer (separate gotcha) since still-paired peer's `state` doesn't transition.
- **Hummingbird's autoPing default is 30s; iOS-side `sendPing` is the missing complement.** A dead-but-not-yet-noticed connection only surfaces when next outbound message fails. `pingTask` in `SessionClient.openSocket` calls `sendPing` every 30s; pong-error → readLoop throws → `.disconnected` → auto-reconnect.
- **Mid-workout rejoin needs server-side `workoutInProgress` tracking.** Without it, a rejoiner is routed through pair → JoinSession → PlanSuggestion and can broadcast a fresh `startWorkout`, stomping partner's active workout. Server records on all-ready transition, persists for session lifetime, includes in `welcome`. iOS routes rejoiner straight into `WorkoutInProgressView` with that plan, skipping suggest/Ready surface.
- **`@StateObject` lifecycle vs `disconnect()` vs `reconnect()`.** `disconnect()` is user-initiated and clears EVERYTHING incl. `sessionId` and `hasSubmittedProfile` → `.idle`. `reconnect()` for transient drops — preserves `sessionId`, `hasSubmittedProfile`, `myProfile`, `chatEntries` but clears per-peer dicts (which need fresh UUIDs anyway). Combine state sink that schedules reconnect guards on `sessionId != nil`, so a disconnected session never auto-reconnects.
- **Clean exit broadcast must flush before close frame.** `sendWorkoutFinished/CancelledAndDisconnect()` use awaited `task.send` (rather than fire-and-forget `sendClientMessage`) so message lands before `disconnect()` closes socket. Without await, close frame races message and peer sees a generic disconnect instead of labeled exit banner.
- **Don't use `.contextMenu` for the chat reaction picker.** Native lift/dismiss pipeline produces platform-specific glitches unreachable from SwiftUI: badge clipping during lift snapshot, iOS 18 bubble wobble during dismiss (UIKit layer outside SwiftUI's transaction propagation), behind-the-bubble flash on stamp, rounded-corner flicker. Each fix exposed another. Custom long-press picker (`onLongPressGesture` + sibling capsule view in per-row VStack) sidesteps all of it. **Don't "fix" this back to native.**
- **Reaction picker emoji buttons MUST be `Text` + `.onTapGesture`, not `Button`.** Even with `.buttonStyle(.plain)`, iOS's button foreground tint absorbs colored emoji glyphs and renders them invisible. Plain `Text` + tap gesture has no inherited tint.
- **Chat reactions wire protocol shares a `messageId` between both peers.** `ChatEntry.id` is the shared id — sender mints it once at `sendChat`, server forwards inside `peerChat`, both peers key the same row. Lets `setReaction`/`peerReactionChanged` address a specific message. Old wire shape (no `messageId`) is incompatible — server redeploy + app rebuild in lockstep.
- **Phase C same-plan detection routing matrix.** When B receives A's `PlanSnapshot` (via `planSuggested` or `welcome.workoutInProgress`), `PlanViewModel.findMatch(forFingerprint:lineageId:)` returns one of three outcomes; `PlanSuggestionView.routeIntoActiveWorkout(snapshot:)` switches on it: `.fingerprintMatch` → silent reuse of B's local plan (preserves B's weights/reps + progress history); `.lineageMatch` → divergence sheet (`DivergenceSheet.swift`); `.none` → auto-import via `importPlan(_:)` then activate. Auto-import branches set `lastAutoImportedPlanName` so `CompletedWorkoutsView` surfaces a 4-second "Saved X to your plans" capsule toast post-workout. **Divergence sheet has only "use friend's version" options — no "use my version".** Positional set sync (above) requires shared structure; offering the user "use mine" would silently disable peer set-completion sync, which is worse UX than the honest constraint. Two recovery options: ephemeral (read-only snapshot, `activePlanIndex = -1` sentinel, library untouched) or persistent (auto-import as new plan with name suffix; B may end up with two plans sharing `lineageId` and can manually delete the old one).
- **Phase C subsumed the Option-1 sentinel fix.** Pre-Phase-C, finishing a collab workout could destructively overwrite an unrelated saved plan in B's library when `activePlanIndex` was stale. Post-Phase-C, `routeIntoActiveWorkout(snapshot:)` always sets a valid `activePlanIndex` (matched local index, freshly-imported index, or `-1` sentinel for ephemeral divergence path). The `if workoutPlans.indices.contains(activePlanIndex)` guards in `WorkoutInProgressView.finishWorkout()` / `cancelWorkout()` now either correctly target the matched/imported plan or correctly no-op via `-1`. Don't reintroduce a destructive write site that doesn't go through this routing.

## Timer & Notification System

- **Workout start countdown:** 3s, skippable. `StartingCountdownView` signals via `onCompletion`.
- **Rest timer:** 5–300s (default 60s). `BreakTimerView` uses `TimelineView(.periodic(from:by:))` (immune to parent re-renders, unlike `Timer.publish`); schedules `UNTimeIntervalNotificationTrigger` for backgrounded alert. Configured via timer-icon button → `BreakDurationPickerView`.
- **Foreground suppression:** `AppDelegate.userNotificationCenter(_:willPresent:)` suppresses `"workoutCategory"` notifications while app is active.

**Critical race:** `dismissBreakTimerView(cancelPendingNotification:)` — natural-expiry path (`onExpired`) MUST pass `false`. Otherwise the in-app timer cancels the notification at the moment iOS is delivering it. Bites hardest under Xcode debugger (keeps app alive in background → in-app timer keeps ticking and races system delivery). X/Done paths pass `true`. Notification id: `BreakTimerView.notificationIdentifier`.

## Navigation

Boolean `@Published` flags on ViewModels (e.g. `isSelectPlanViewActive`) + `NavigationStack` + `.fullScreenCover`/`.sheet`. Use `@Environment(\.dismiss)` (modern API — never `presentationMode`).

## Testing

- **Framework:** Swift Testing (`import Testing`, `@Test`, `#expect`). Not XCTest.
- **Target:** `ForgeTests/`. `PBXFileSystemSynchronizedRootGroup`.
- **Suites:** `ExerciseTests` (8), `PlanViewModelTests` (28), `CompletedWorkoutsViewModelTests` (15), `ValidationTests` (6), `WorkoutPlanFingerprintTests` (12), `SessionClientTests` (31) — 100 cases.
- **Persistence isolation:** test classes touching persistence are `final class` (init/deinit = setUp/tearDown). Each gets its own `UserDefaults(suiteName: "ForgeTests.\(UUID().uuidString)")`, removes domain in `deinit`.
- **Mock data:** `Forge/View Model/MockData.swift` exposes `mockWorkoutPlans` + `mockCompletedWorkouts` as module-internal globals. Tests use `@testable import Forge`. `CompletedWorkoutsViewModel`'s Preview-only mock init no longer reaches into mock globals.

## Subtle gotchas

- **Picker wheel `Int` tags need explicit `.tag(value)`** — SwiftUI's `WheelPickerStyle` historically had bugs binding to non-String selections.
- **`heterogenousSetRowHeight = 1000000`** in `ExerciseEditorView` is intentional: `heterogenousSetMaxViewHeight = (count*Int(rowHeight))+80` makes height effectively unbounded so inner `clipped()` + outer `frame(maxHeight:)` can grow without limit. Don't "fix" it.
- **`homoHeteroControlsAreConnected` and `editedExerciseStartedWithUniqueSets` flags** in `ExerciseEditorView` gate sync between homo/hetero picker state. `onAppear` ordering matters — set connected flag false, load data, then set true. Otherwise toggle's `onChange` fires during init and wipes loaded data.
- **`activeExerciseIndex` is stale in `.add` mode.** `ExerciseEditorView.saveExercise()` gates `existingExercise` lookup on mode being `.edit`/`.log` — never trust `activeExerciseIndex` in `.add` mode (without the gate, new exercises inherit completion state from previous).
- **`Timer.publish` in child views breaks when parents re-render frequently.** `WorkoutInProgressView` updates `elapsedSeconds` every second; `BreakTimerView` originally used `Timer.publish` which got recreated (and never fired) on each re-render. Migrate any new timer-based child view to `TimelineView`, NOT `Timer.publish`.
- **`didSet` on `@Published` properties breaks `objectWillChange`** — compiler-generated setter bypasses property wrapper's `objectWillChange.send()`. Use a Combine `$prop.dropFirst().sink` subscriber for side effects (see `GlobalSettings.colorTheme`).
- **`navigationBarTitleTextColor` must force-update existing bars.** `UINavigationBar.appearance()` only applies to newly created bars. Extension in `CompletedWorkoutsView.swift` traverses all `UIWindowScene` windows on `.onChange(of: color)` and directly sets `standardAppearance`/`scrollEdgeAppearance` (via `.copy()` + reassign).
- **Multiple `Button`s in a single `List` row require `.buttonStyle(.borderless)`.** Without it, List treats the whole row as one tappable area and fires the last button's action regardless of tap location.
- **`UIScreen.main.bounds`** is still used in `WorkoutInProgressView` (panel expansion + `isSmallScreen` + chat sizing), `BreakTimerView` (ring diameter), `ConfettiView` (particle x-distribution), `WorkoutWithFriendView` (≥414pt width gate), `ExerciseEditorView` (title-bar split). Deprecated in iOS 16+ but doesn't warn at our deployment target. B5 in roadmap migrates to `GeometryReader`.
- **Small-screen UX swap (`isSmallScreen`).** `WorkoutInProgressView` defines `isSmallScreen: Bool { screenHeight < 700 }` (true on SE-class). On these, the break-timer panel can't fit the in-ring X cancel button, so the disabled back chevron at top-left swaps to an `xmark` calling `dismissBreakTimerView()` while timer is active, and in-ring X hides. Reverts when timer dismisses/expires. `isSmallScreen` is passed to `BreakTimerView` as a parameter.
- **Content-aware sheet detent in `ExerciseEditorView`.** Sheet uses `.presentationDetents([homoModeDetent, .large])` where `homoModeDetent` is `.height(360 + buffer)`. `buffer` is bottom safe-area inset (read once from key window) on home-indicator phones, or fixed 40pt on SE. Detent ownership lives entirely inside `ExerciseEditorView` (no `selectedDetent` binding from parents); toggle's `onChange`/`onAppear` set `selectedDetent` directly.
- **Don't put workflow-critical `@StateObject`s on the `App` struct if any view's `onAppear` resets navigation flags.** Promoting `PlanViewModel` to `@StateObject` on `ForgeApp` caused Scene body to re-evaluate on every publish, re-firing `CompletedWorkoutsView.onAppear` and resetting `isSelectPlanViewActive = false` — popping the workout fullScreenCover every time a plan was tapped. Working pattern: inline `.environmentObject(PlanViewModel())` in `ForgeApp.body` + `@EnvironmentObject` in views. App-wide hooks like `.onOpenURL` attach to root *view*, not Scene.
- **`SessionClient.State` carries peerIds in the `.paired` case** — there is no independent `@Published peerIds`; the "connected without peers" illegal state is unrepresentable. Read via `sessionClient.isPaired` (bool), pattern-match `case .paired(let ids) = state`, or use the `peerIds` computed accessor (returns `[]` in non-paired). Don't reintroduce separate `peerIds` storage.
- **`Log.debug(_:)` is the project's logging channel** (`Forge/View Model/Log.swift`) — `@autoclosure` + `#if DEBUG`-guarded print. Use it instead of `print` in the Forge target. `ForgeWatch` still uses bare `print`. For user-visible error surfaces, still use a banner / alert per "Fail Loud, Never Fake".
- **Prefer `GlobalSettings` constants over magic numbers** for cornerRadius (`Small/Medium/Large` = 5/8/16) and animation durations (`Quick/Standard/Slow` = 0.2/0.5/1.0). Only when the semantic bucket matches — don't force one-offs into the shared scale.
- **`LinearGradient`'s `startPoint`/`endPoint` are NOT animatable via `withAnimation`** — wrapping endpoint changes snaps to the final state. For continuously-animating gradients (shimmer, sweep, glow), drive phase from `TimelineView(.animation) { context in ... }` recomputing endpoints from wall-clock time. Shimmer on suggested plan name in `PlanSuggestionView` uses 2.5s cycle, UnitPoint phase mapped to `[-1.5, 1.5]`.
- **`@FocusState` set during a present transition gets silently dropped.** Auto-focusing a TextField in a sheet/nav-pushed view's `.onAppear` requires a small delay (~0.4s) so host transition settles. `JoinSessionView` does this.

## Future development roadmap

High-level plan, ordered. Each item gets scoped + planned individually.

- [ ] **Server upgrade: production deployment + background chat notifications** — bundles Cloudflare Named Tunnel + launchd supervision + secrets baseline + server-side chat history + APNs push for backgrounded peers. Full plan in `server-upgrade-plan.md` at repo root. Replaces the prior standalone "production server deployment" and "background chat notifications" roadmap items.
- [~] **UI refactor: multi-iPhone-size support** — partial. Target: SE 3rd gen (375pt) → 17 Pro Max (430pt), portrait-only. Outstanding: B4 (`WorkoutWithFriendView` Pro Max vertical-spacing — paused, manual), B5 (replace remaining `UIScreen.main` — see gotcha for sites), B6 (verify `SetView` strikethrough alignment on SE / Pro Max). **Known issue:** break-timer panel still uses `topToolBarHeight = screenHeight * 0.8`, leaving excess empty space on Air / Pro Max. Content-aware panel-height attempted but broke expansion animation (75 + 163pt plan-info section above `BreakTimerView` competes for same panel height). Needs different approach — e.g. layoutPriority + capping `BreakTimerView`'s greedy `Spacer().frame(maxHeight:)`.
- [ ] **Robust Plan Data Model with new Plan ID** — replaces per-plan `UUID` with identity scheme that survives import/export round-trips, AirDrop dedup, server persistence. Ties together `dedupePlanIdsIfNeeded` + `PlanSnapshot`. Prerequisite for History Data Visualization.
- [ ] **History Data Visualization** — trends across workouts (volume, frequency, per-exercise progress).
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
