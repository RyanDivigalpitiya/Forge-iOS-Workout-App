# Server Upgrade Plan: Production Deployment + Background Chat Notifications

Combined scope. Bundles production-grade server deployment (Cloudflare Named Tunnel + launchd + secrets baseline) with full background chat notifications (APNs + chat-history persistence on the server). The two share enough operational scope — secret management, process supervision, deployment cadence — that doing them in one pass is cheaper than splitting.

This plan is self-contained. Read it cold. It captures the assessment from the conversation on 2026-04-27 so future-me doesn't have to reconstruct the reasoning.

---

## Why combined

- **Production deployment establishes the secret-management story.** The server currently has no secrets. APNs needs a `.p8` auth key, key ID, team ID. Setting that up alongside launchd supervision (which can pass env vars) is one operational pass instead of two.
- **Named Tunnel gives a stable hostname.** Push notifications carry deep links (`forge://session/<id>/chat`) — those don't depend on the tunnel hostname, but the iOS-hardcoded `SessionClient.serverHost` does. Pinning to `forge-ws.ryan-div.com` once removes the rebuild-on-tunnel-restart tax that complicates push testing.
- **Chat history persistence is the missing piece for "real" notifications.** Push delivers the alert text, but when the user returns to foreground, the in-app chat panel won't show messages they missed (chatEntries is client-only today, server has no history). Without this, push is a tease.

---

## Phase 1 — Production-grade server deployment

Goal: server runs unattended on Mac mini with stable hostname; secrets loadable; restart-resilient.

### 1.1 Cloudflare Named Tunnel

Replaces the ephemeral Quick Tunnel (`*.trycloudflare.com`).

```bash
cloudflared tunnel login                              # one-time, browser auth
cloudflared tunnel create forge-ws                    # creates tunnel + credentials JSON
cloudflared tunnel route dns forge-ws forge-ws.ryan-div.com
```

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: <tunnel-uuid-from-create>
credentials-file: /Users/ryandiv/.cloudflared/<tunnel-uuid>.json

ingress:
  - hostname: forge-ws.ryan-div.com
    service: http://localhost:8080
  - service: http_status:404
```

Smoke test in tmux: `cloudflared tunnel run forge-ws`

Then update `SessionClient.serverHost` to `forge-ws.ryan-div.com`. Rebuild app. Tunnel UUID is stable forever — no more rebuild-on-restart tax.

### 1.2 launchd auto-start

Two plists at `~/Library/LaunchAgents/`:

- `com.ryandiv.forgeserver.plist` — runs `swift run ForgeServer` (or pre-built binary, see below) from `/Users/ryandiv/Code/Forge/server`. `RunAtLoad`, `KeepAlive`, `StandardOutPath`/`StandardErrorPath` to a log file.
- `com.ryandiv.forgeserver-tunnel.plist` — runs `cloudflared tunnel run forge-ws`. Same flags.

Load with `launchctl load -w ~/Library/LaunchAgents/com.ryandiv.forgeserver.plist`.

**Decision: build a release binary or use `swift run`?** `swift run` rebuilds on every launch and leaves a build artifact tree. Cleaner: `swift build -c release` once, then have launchd run `.build/release/ForgeServer` directly. Faster cold start, no build during launch.

### 1.3 Secrets baseline

Before APNs, establish how secrets reach the process. `.p8` key + APNs key ID + team ID need to be available to the server but never committed.

Pattern: env vars passed via launchd plist `EnvironmentVariables` dict. The `.p8` itself is a file path on disk, mode 0600, owned by ryandiv. No tooling required.

```xml
<key>EnvironmentVariables</key>
<dict>
  <key>FORGE_APNS_KEY_PATH</key>
  <string>/Users/ryandiv/.config/forge/AuthKey_XXXXXXXXXX.p8</string>
  <key>FORGE_APNS_KEY_ID</key>
  <string>XXXXXXXXXX</string>
  <key>FORGE_APNS_TEAM_ID</key>
  <string>XXXXXXXXXX</string>
  <key>FORGE_APNS_BUNDLE_ID</key>
  <string>Ryan-Div.Forge</string>
</dict>
```

Server reads via `ProcessInfo.processInfo.environment[...]`. Fail loud at startup if missing in production builds.

### 1.4 Acceptance

- `forge-ws.ryan-div.com` resolves and serves the WS upgrade.
- Reboot Mac mini → server + tunnel come back without manual intervention.
- `kill -9` the server PID → launchd respawns within seconds.
- Logs land in a known file, rotated or at least bounded (manual `>` redirect is fine for now).

---

## Phase 2 — Server-side chat history

Goal: when a peer is `.away` and rejoins (or any new connection joins a session), the server replays the chat transcript so no messages are lost from the user's perspective.

### 2.1 Data model

In `SessionManager.swift`, extend `Session`:

```swift
struct StoredChatEntry: Codable, Sendable {
    let messageId: UUID
    let senderId: UUID
    let text: String
    let timestamp: Date
    var reactions: [UUID: String]  // peerId -> emoji
}

actor Session {
    // ...existing fields...
    var chatHistory: [StoredChatEntry] = []
}
```

In-memory only. Lifetime = session lifetime (already cleared when session goes empty). No disk persistence; that's a separate scope and out of bounds for this plan.

### 2.2 Wire protocol additions

`Protocol.swift`:

```swift
// ServerMessage
case chatHistory(entries: [StoredChatEntry])
```

Sent immediately after `welcome` on every connect (fresh join AND `.rebound` reconnect). Empty array is fine for fresh sessions. Including reactions in the snapshot keeps the badges intact across reconnects.

`SessionClient.swift` mirrors `StoredChatEntry`, handles `chatHistory` by replacing local `chatEntries` with the server snapshot. **Idempotent** — same messageId from history + live `peerChat` should not double-render. Key off `messageId`.

### 2.3 Mutation points

Every chat-related broadcast in `Application+build.swift` also writes to history:

- `sendChat` → append to history, then forward as `peerChat`.
- `setReaction` → mutate the matching `StoredChatEntry.reactions` entry, then forward as `peerReactionChanged`.

Cap history at, say, 500 entries with FIFO eviction. Long sessions with chatty peers shouldn't blow memory.

### 2.4 Protocol-change rule

New `chatHistory` message + new `StoredChatEntry` shape are wire-incompatible with current clients. Server redeploy + app rebuild in lockstep — same rule documented in CLAUDE.md. Don't ship the server change without the matching iOS rebuild ready.

### 2.5 Acceptance

- Two phones in a session, one chats while the other is force-quit.
- Force-quit phone reopens, taps the deep link, rejoins.
- Full transcript including the messages sent during their absence is visible in the chat panel.

---

## Phase 3 — APNs push notifications

Goal: when peer is `.away` and a chat arrives, recipient gets a real iOS push with sender name + message text. Tap routes into the active session's chat panel.

### 3.1 Apple Developer portal (one-time, ~1 hour)

- Create APNs Auth Key (`.p8`) under "Keys". Download the `.p8` once — it's not retrievable again. Note the Key ID (10 chars).
- Note the Team ID (visible in Membership section).
- Enable Push Notifications capability on `Ryan-Div.Forge` app ID.
- No cert rotation needed — auth keys don't expire.

Deposit `.p8` at `/Users/ryandiv/.config/forge/AuthKey_XXXXXXXXXX.p8`, mode 0600.

### 3.2 iOS work

**Entitlements / capabilities:**
- Push Notifications capability (Xcode → Signing & Capabilities → +).
- Background Modes: `remote-notification` (only if doing silent push later — for v1 alert push, not required).

**Token registration flow** (in `AppDelegate.swift` or a dedicated `PushManager`):

```swift
// In didFinishLaunching or after notification authorization:
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
    guard granted else { return }
    DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
    }
}

// New AppDelegate method:
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    SessionClient.shared.handleAPNsToken(token)
}
```

**Environment detection.** Sandbox endpoint for Debug + TestFlight (Apple uses sandbox for both unless you're stamped App Store), production for App Store. Send `env: "sandbox" | "production"` alongside the token — most reliable approach is to derive at compile time from build config, NOT runtime.

**SessionClient changes:**
- New protocol message: `registerPushToken(token: String, env: String)`.
- Send on every WS connect after `welcome`, alongside `participantId` (which is in the URL query).
- Cache token; resend if it rotates (Apple can rotate; rare but real).

**Foreground suppression.** Extend the existing `"workoutCategory"` suppression pattern in `AppDelegate.userNotificationCenter(_:willPresent:)` to also suppress a new `"chatCategory"` when the app is in the active session — otherwise the user sees a banner for messages they're already reading. The push payload should include `sessionId` so the AppDelegate can compare against `SessionClient.sessionId`.

**Tap deep link.** Extend the `forge://` URL scheme to `forge://session/<id>/chat`. `CompletedWorkoutsView.onOpenURL` routes to the active session and sets a flag `shouldOpenChatPanel` that `WorkoutInProgressView` / `PlanSuggestionView` consume on appear to expand the chat surface. AppDelegate's `userNotificationCenter(_:didReceive:)` handler synthesizes the URL from the payload and posts via the same path.

### 3.3 Server work

**Dependency.** Add APNSwift (or hand-roll using `AsyncHTTPClient` + JWT — APNSwift is ~250 lines of work to replicate, not worth it). `Package.swift`:

```swift
.package(url: "https://github.com/swift-server-community/APNSwift.git", from: "5.0.0")
```

**APNs client lifecycle.** One client instance per env (sandbox + production), held by `Application+build.swift` and passed into the `SessionManager` actor or a sibling `PushDispatcher`.

**Per-participant token map.** `Session.Participant` gains `pushToken: String?` + `pushEnv: APNSEnvironment?`. Updated by new `registerPushToken` handler. Token persists across reconnects (the `.away`/`.rebound` flow preserves it).

**Push trigger.** In the `sendChat` handler, after the live broadcast, iterate other participants:

```swift
for peer in session.participants where peer.id != myId {
    if peer.state.isAway, let token = peer.pushToken, let env = peer.pushEnv {
        await pushDispatcher.send(
            token: token,
            env: env,
            title: senderProfile.name,
            body: trimmed,
            sessionId: session.id,
            messageId: messageId
        )
    }
}
```

`peer.state.isAway` is the only condition. If they're `.connected` they got the live message; no push needed.

**Payload shape:**

```json
{
  "aps": {
    "alert": { "title": "Ryan", "body": "ready when you are" },
    "sound": "default",
    "badge": 1,
    "thread-id": "<sessionId>"
  },
  "sessionId": "<uuid>",
  "messageId": "<uuid>"
}
```

`thread-id` groups multiple messages from the same session in the lock screen stack — iOS handles the rest.

**Bundle topic** = `Ryan-Div.Forge`. Hardcode. APNSwift takes it as the topic field.

### 3.4 Failure modes

- **APNs is best-effort.** Don't treat failures as bugs. Log + move on. Source of truth stays the WS flow + chat-history snapshot on reconnect.
- **Bad token.** APNs returns `BadDeviceToken` or `Unregistered`. Server should clear that participant's `pushToken` so it stops trying. Client will re-register on next launch.
- **Wrong env.** Sending a sandbox token to production endpoint (or vice versa) silently no-ops or returns `BadDeviceToken`. The compile-time env detection on iOS prevents this; just don't trust runtime detection.

### 3.5 Acceptance

- Two phones paired. Phone A backgrounds. Phone B sends a chat.
- Phone A's lock screen shows a notification with B's name + message text within ~2 seconds.
- Tap → Forge opens, routes into the active session, chat panel is expanded with the new message visible.
- Foreground edge case: Phone A is in the chat panel actively. Phone B sends a chat. Phone A sees the message inline; no banner.

---

## Sequencing & dependencies

Recommended order — each phase is independently shippable, but stacking yields the operational story:

1. **Phase 1 (production server)** — independent. Ships a stable hostname + supervised process. Unblocks anyone who hits the Quick Tunnel rebuild-on-restart tax. Worth doing even if Phases 2/3 slip.
2. **Phase 2 (chat history)** — depends only on protocol-change discipline. Could be done before Phase 1 in theory, but bundling avoids a second redeploy.
3. **Phase 3 (push)** — depends on Phase 1's secrets baseline. Phase 2 isn't strictly required for push to work, but without it the user experience is degraded ("I got a notification but the message isn't in the app"). Don't ship Phase 3 without Phase 2.

Single redeploy at the end of all three minimizes the lockstep-rebuild dance for the wire protocol.

---

## Open questions / decisions to make later

- **Chat-history disk persistence?** Out of scope here. If the server crashes / Mac mini reboots mid-session, history is lost. Acceptable for now (sessions are short-lived, capacity 2). Revisit if usage grows.
- **Notification preferences UI?** Currently no in-app toggle for chat notifications. Ship without — iOS Settings is the escape hatch. Revisit if users complain.
- **Silent push for richer in-app state sync?** Could use `content-available: 1` to wake the app and refresh missed state without user-visible alert. Adds complexity, requires `remote-notification` background mode, has stricter Apple review scrutiny. Defer indefinitely unless there's a real need.
- **Reaction notifications?** Should "Ryan reacted ❤️ to your message" generate a push? Probably not — too noisy. Let reactions appear silently on next foreground.
- **Multi-device per user?** Not a concern at capacity 2 with stable participantId per device. If account-based identity ever lands, push tokens become a per-device list.

---

## Estimated effort

- Phase 1: ~1 day (Named Tunnel setup is the slow part; launchd plists are quick once you've done one).
- Phase 2: ~half day (tight protocol change, two new server fields, idempotent client merge).
- Phase 3: ~2 days (APNs client integration, deep-link wiring, env detection, real-device testing on 2 phones).
- Apple Developer portal: ~1 hour, parallelizable with iOS work.
- **Total: ~3.5–4 days** for the full bundle, assuming a clean run. Add a half-day buffer for the inevitable APNs sandbox-vs-prod debugging session.
