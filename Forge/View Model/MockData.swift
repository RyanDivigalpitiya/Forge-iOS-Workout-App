import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Mock data is used for Preview Structs to populate UI + before loading/saving persistant storage is implemented.
// This file contains only mock data used for these purposes and will be deleted when app is shipped.

let set1 = Set(weight: 25, reps: 12, tillFailure: false, completed: false)
let set2 = Set(weight: 30, reps: 10, tillFailure: false, completed: false)
let set3 = Set(weight: 35, reps: 8, tillFailure: false, completed: false)
let set3_f = Set(weight: 35, reps: 8, tillFailure: true, completed: false)

let mockSets1 = [set1,set2,set3,set3_f]

let set4 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
let set5 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)
let set6 = Set(weight: 100, reps: 12, tillFailure: false, completed: false)

let mockSets2 = [set4,set5,set6]

let exercise1 = Exercise(name: "Bicep Curls", sets: mockSets1)
let exercise2 = Exercise(name: "Loooonng Sentence Pull Ups", sets: mockSets2)
let exercise3 = Exercise(name: "Back Rows", sets: mockSets2)

let mockExercises1 = [exercise1,exercise2,exercise3]

let workoutPlan1 = WorkoutPlan(name: "Biceps + Back", exercises: mockExercises1, lastCompleted: Date().addingTimeInterval(-1 * 24 * 60 * 60))

let exercise4 = Exercise(name: "Bench Press", sets: mockSets2)
let exercise5 = Exercise(name: "Tricep Extensions", sets: mockSets2)
let exercise6 = Exercise(name: "Chest Flies", sets: mockSets2)

let mockExercises2 = [exercise4,exercise5,exercise6]

let workoutPlan2 = WorkoutPlan(name: "Chest + Triceps", exercises: mockExercises2, lastCompleted: Date().addingTimeInterval(-2 * 24 * 60 * 60))

let exercise7 = Exercise(name: "Elbow Chicken Flies", sets: mockSets1)
let exercise8 = Exercise(name: "Shoulder Flies", sets: mockSets1)
let exercise9 = Exercise(name: "Shoulder Press", sets: mockSets1)

let mockExercises3 = [exercise7,exercise8,exercise9]

let workoutPlan3 = WorkoutPlan(name: "Shoulders", exercises: mockExercises3, lastCompleted: Date().addingTimeInterval(-3 * 24 * 60 * 60))

let completedWorkout1 = CompletedWorkout(date: Date(), workout: workoutPlan1, elapsedTime: 1800, completion: "100%", caloriesBurned: 342)
let completedWorkout2 = CompletedWorkout(date: Date().addingTimeInterval(-1 * 24 * 60 * 60), workout: workoutPlan2, elapsedTime: 2500, completion: "87%", caloriesBurned: 278)
let completedWorkout3 = CompletedWorkout(date: Date().addingTimeInterval(-2 * 24 * 60 * 60), workout: workoutPlan3, elapsedTime: 500, completion: "50%")

let mockWorkoutPlans = [workoutPlan1,workoutPlan2,workoutPlan3]
let mockCompletedWorkouts = [completedWorkout1,completedWorkout2,completedWorkout3]

// MARK: - Long-form completed-workout history (preview canvas)
//
// `mockCompletedWorkouts` above stays at three entries because the test
// suite hard-codes that count. This separate, longer array layers ~36
// historical sessions on top — twelve per plan, set values trending
// upward over six months — so the Full History tab's per-exercise
// progress chart has enough signal to be visually meaningful when
// previewed in the Xcode canvas.
//
// Per-session exercises preserve the base plan's exercise UUIDs
// (struct copy keeps `id`); only `sets` are overridden with the
// progressed values. That stable id-lineage is exactly what
// `progressSeries(forExerciseId:)`, `weightPR`, and `repsPR` look up.

private func progressedSession(
    daysAgo: Int,
    basePlan: WorkoutPlan,
    setsByExercise: [[Set]],
    elapsedTime: TimeInterval = 1800,
    completion: String = "100%",
    calories: Double? = 280
) -> CompletedWorkout {
    var newExercises: [Exercise] = []
    for (i, baseEx) in basePlan.exercises.enumerated() {
        var copy = baseEx
        if i < setsByExercise.count {
            copy.sets = setsByExercise[i]
        }
        newExercises.append(copy)
    }
    let date = Date().addingTimeInterval(-Double(daysAgo) * 86_400)
    let snapshot = WorkoutPlan(name: basePlan.name, exercises: newExercises, lastCompleted: date)
    return CompletedWorkout(
        date: date,
        workout: snapshot,
        elapsedTime: elapsedTime,
        completion: completion,
        caloriesBurned: calories
    )
}

private func uniformSets(weight: Float, reps: Int, count: Int, completed: Bool = true) -> [Set] {
    Array(
        repeating: Set(weight: weight, reps: reps, tillFailure: false, completed: completed),
        count: count
    )
}

// Twelve evenly-spaced sessions per plan: 180 → 15 days ago.
private let progressionDayOffsets: [Int] = Array(stride(from: 180, through: 15, by: -15))

private let plan1History: [CompletedWorkout] = progressionDayOffsets.enumerated().map { i, daysAgo in
    let w = Double(i)
    // Bicep Curls (4 sets): 25 → 44 lb, 12 → 9 reps
    let bicepWeight = Float(25 + Int(w * 1.8))
    let bicepReps   = max(9, 12 - Int(w / 3))
    // Pull Ups (3 sets): bodyweight, 5 → 10 reps
    let pullupReps  = 5 + Int(w * 0.5)
    // Back Rows (3 sets): 100 → 133 lb, 12 → 10 reps
    let rowWeight   = Float(100 + Int(w * 3.0))
    let rowReps     = max(10, 12 - Int(w / 6))
    return progressedSession(
        daysAgo: daysAgo,
        basePlan: workoutPlan1,
        setsByExercise: [
            uniformSets(weight: bicepWeight, reps: bicepReps,  count: 4),
            uniformSets(weight: 0,           reps: pullupReps, count: 3),
            uniformSets(weight: rowWeight,   reps: rowReps,    count: 3),
        ],
        elapsedTime: 1800 + TimeInterval(i * 30),
        completion: (i == 4 || i == 9) ? "85%" : "100%",
        calories: 270 + Double(i) * 4
    )
}

private let plan2History: [CompletedWorkout] = progressionDayOffsets.enumerated().map { i, daysAgo in
    let w = Double(i)
    // Bench Press (3 sets): 135 → 206 lb, 8 → 5 reps
    let benchWeight = Float(135 + Int(w * 6.5))
    let benchReps   = max(5, 8 - Int(w / 4))
    // Tricep Extensions (3 sets): 30 → 55 lb, 12 → 10 reps
    let triceWeight = Float(30 + Int(w * 2.3))
    let triceReps   = max(10, 12 - Int(w / 6))
    // Chest Flies (3 sets): 25 → 44 lb, 12 → 10 reps
    let flyWeight   = Float(25 + Int(w * 1.8))
    let flyReps     = max(10, 12 - Int(w / 6))
    return progressedSession(
        daysAgo: max(0, daysAgo - 5),
        basePlan: workoutPlan2,
        setsByExercise: [
            uniformSets(weight: benchWeight, reps: benchReps, count: 3),
            uniformSets(weight: triceWeight, reps: triceReps, count: 3),
            uniformSets(weight: flyWeight,   reps: flyReps,   count: 3),
        ],
        elapsedTime: 2000 + TimeInterval(i * 40),
        completion: (i == 2 || i == 8) ? "90%" : "100%",
        calories: 300 + Double(i) * 5
    )
}

private let plan3History: [CompletedWorkout] = progressionDayOffsets.enumerated().map { i, daysAgo in
    let w = Double(i)
    // Elbow Chicken Flies (4 sets): 10 → 25 lb, 15 → 13 reps
    let chWeight = Float(10 + Int(w * 1.4))
    let chReps   = max(13, 15 - Int(w / 4))
    // Shoulder Flies (4 sets): 12 → 26 lb, 12 → 10 reps
    let sfWeight = Float(12 + Int(w * 1.4))
    let sfReps   = max(10, 12 - Int(w / 6))
    // Shoulder Press (4 sets): 75 → 124 lb, 10 → 8 reps
    let spWeight = Float(75 + Int(w * 4.5))
    let spReps   = max(8, 10 - Int(w / 6))
    return progressedSession(
        daysAgo: max(0, daysAgo - 10),
        basePlan: workoutPlan3,
        setsByExercise: [
            uniformSets(weight: chWeight, reps: chReps, count: 4),
            uniformSets(weight: sfWeight, reps: sfReps, count: 4),
            uniformSets(weight: spWeight, reps: spReps, count: 4),
        ],
        elapsedTime: 1700 + TimeInterval(i * 25),
        completion: (i == 1 || i == 7 || i == 10) ? "80%" : "100%",
        calories: 260 + Double(i) * 4
    )
}

let mockCompletedWorkoutsLong: [CompletedWorkout] =
    mockCompletedWorkouts + plan1History + plan2History + plan3History

// MARK: - Body weight mock data

private let dayInSeconds: TimeInterval = 86_400
private let bwNow = Date()

let mockBodyWeightEntries: [BodyWeightEntry] = [
    BodyWeightEntry(date: bwNow,                                          weightLbs: 178.5),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-2 * dayInSeconds),    weightLbs: 178.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-7 * dayInSeconds),    weightLbs: 177.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-14 * dayInSeconds),   weightLbs: 175.5),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-25 * dayInSeconds),   weightLbs: 173.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-45 * dayInSeconds),   weightLbs: 170.0),
    BodyWeightEntry(date: bwNow.addingTimeInterval(-75 * dayInSeconds),   weightLbs: 168.5),
]

// MARK: - Collab session mocks (Xcode Canvas only)
//
// `SessionClient.init()` is non-networking — it just loads any cached
// profile and wires a Combine sink — so setting `@Published` properties
// directly produces a fully-rendered preview state without opening a
// WebSocket. Use these factories in `#Preview` blocks; switch device
// sizes from Canvas's device picker to sweep SE → Pro Max layouts.

@MainActor
enum MockSessionClient {

    private static let myId      = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static let peerId    = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private static let sessionId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    private static func basePaired(
        myName: String = "Ryan",
        peerName: String? = "Alex"
    ) -> SessionClient {
        let c = SessionClient()
        c.myId = myId
        c.sessionId = sessionId
        c.myProfile = Profile(name: myName, photoData: nil)
        c.hasSubmittedProfile = true
        c.state = .paired(peerIds: [peerId])
        if let peerName {
            c.peerProfiles = [peerId: Profile(name: peerName, photoData: nil)]
        }
        return c
    }

    /// Both peers paired, no chat, no suggested plan.
    static func paired(peerName: String? = "Alex") -> SessionClient {
        basePaired(peerName: peerName)
    }

    /// Paired + a sample back-and-forth chat (peer + mine, multi-line,
    /// reaction badges).
    static func pairedWithChat() -> SessionClient {
        let c = basePaired()
        c.chatEntries = sampleChatEntries()
        return c
    }

    /// Paired + a `suggestedPlan` set — drives `PlanSuggestionView`'s
    /// "Plan Suggested" branch.
    static func pairedWithSuggestion() -> SessionClient {
        let c = basePaired()
        if let firstPlan = mockWorkoutPlans.first {
            c.suggestedPlan = PlanSnapshot(from: firstPlan)
        }
        return c
    }

    /// Socket up, no peer yet — `CollabStatusBanner` surfaces the
    /// "Re-invite" affordance in this state.
    static func waitingForPeer() -> SessionClient {
        let c = SessionClient()
        c.myId = myId
        c.sessionId = sessionId
        c.myProfile = Profile(name: "Ryan", photoData: nil)
        c.hasSubmittedProfile = true
        c.state = .waitingForPeer
        return c
    }

    /// Local socket dropped — `CollabStatusBanner` shows the generic
    /// disconnect message.
    static func disconnected(reason: String = "Lost connection") -> SessionClient {
        let c = SessionClient()
        c.myId = myId
        c.state = .disconnected(reason: reason)
        return c
    }

    /// Peer broadcast a clean exit before closing — banner shows the
    /// labeled "Friend finished" / "Friend left session" copy. Pass
    /// `.finished` or `.cancelled`.
    static func peerExited(reason: PeerExitInfo.Reason = .finished) -> SessionClient {
        let c = basePaired()
        c.peerExitInfo = PeerExitInfo(peerId: peerId, reason: reason)
        return c
    }

    /// `ConnectingView` initial frame — pulsing icon, session id assigned
    /// but no peer yet.
    static func connecting() -> SessionClient {
        let c = SessionClient()
        c.myId = myId
        c.sessionId = sessionId
        c.state = .connecting
        return c
    }

    /// Joint-mode `WorkoutInProgressView` state — paired, peer parked at
    /// the first set of the first exercise, one set already completed.
    /// Pair with `mockWorkoutPlans.first` set as `planViewModel.activePlan`.
    static func midWorkout() -> SessionClient {
        let c = basePaired()
        c.peerPositions = [peerId: UserPosition(exerciseIndex: 0, setIndex: 0, isResting: false)]
        c.peerCompletedSets = [PeerSetKey(exerciseIndex: 0, setIndex: 0)]
        if let firstPlan = mockWorkoutPlans.first {
            c.workoutInProgress = PlanSnapshot(from: firstPlan)
        }
        return c
    }

    /// Sample chat history — covers peer-sent, mine-sent, multi-line text,
    /// and reactions on both sides.
    static func sampleChatEntries() -> [ChatEntry] {
        let now = Date()
        return [
            ChatEntry(
                id: UUID(), text: "Hey, ready to lift?",
                timestamp: now.addingTimeInterval(-300),
                isMine: false,
                myReaction: "❤️", peerReaction: nil
            ),
            ChatEntry(
                id: UUID(), text: "Yeah, just warming up. Pull day?",
                timestamp: now.addingTimeInterval(-240),
                isMine: true,
                myReaction: nil, peerReaction: nil
            ),
            ChatEntry(
                id: UUID(), text: "Yep, hitting back + biceps. I'll suggest the plan.",
                timestamp: now.addingTimeInterval(-180),
                isMine: false,
                myReaction: nil, peerReaction: nil
            ),
            ChatEntry(
                id: UUID(), text: "Sounds good 💪",
                timestamp: now.addingTimeInterval(-30),
                isMine: true,
                myReaction: nil, peerReaction: "🔥"
            ),
        ]
    }
}

// MARK: - Progress photos mock data

#if canImport(UIKit) && DEBUG

private func makeMockProgressImage(_ color: UIColor, label: String) -> UIImage {
    let size = CGSize(width: 400, height: 500)
    return UIGraphicsImageRenderer(size: size).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ]
        let textSize = label.size(withAttributes: attrs)
        let origin = CGPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        label.draw(at: origin, withAttributes: attrs)
    }
}

/// Builds a `ProgressPhotosViewModel` seeded with three entries (1, 2, and 3
/// poses respectively) backed by synthesized UIImages on a per-call temp
/// directory. The directory is unique per call so previews don't clobber
/// each other.
@MainActor
func makeMockProgressPhotosVM() -> ProgressPhotosViewModel {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ForgePreviewPhotos.\(UUID().uuidString)", isDirectory: true)
    let suite = UserDefaults(suiteName: "ForgePreview.\(UUID().uuidString)")!
    let vm = ProgressPhotosViewModel(userDefaults: suite, photosDirectory: dir)
    let day: TimeInterval = 86_400
    let now = Date()
    vm.addEntry(
        date: now,
        front: makeMockProgressImage(.systemRed, label: "F"),
        side: makeMockProgressImage(.systemBlue, label: "S"),
        back: makeMockProgressImage(.systemGreen, label: "B")
    )
    vm.addEntry(
        date: now.addingTimeInterval(-14 * day),
        front: makeMockProgressImage(.systemOrange, label: "F"),
        side: nil,
        back: makeMockProgressImage(.systemPurple, label: "B")
    )
    vm.addEntry(
        date: now.addingTimeInterval(-45 * day),
        front: makeMockProgressImage(.systemTeal, label: "F"),
        side: nil,
        back: nil
    )
    return vm
}

#endif
