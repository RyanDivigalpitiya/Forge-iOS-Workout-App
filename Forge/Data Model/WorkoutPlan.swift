import Foundation
import CryptoKit

struct WorkoutPlan: Identifiable, Encodable, Decodable {
    var id: UUID
    var name: String
    var exercises: [Exercise] {
        didSet { refreshFingerprint() }
    }
    var lastCompleted: Date?

    // Stable identity preserved through imports (.forgeplan today, collab
    // auto-import in Phase C). Optional for backward-compat with existing
    // UserDefaults blobs and historical CompletedWorkout.workout snapshots;
    // PlanViewModel migration backfills live records.
    var lineageId: UUID?

    // SHA-256 over ordered (lowercased+trimmed exerciseName, setCount) pairs.
    // Auto-refreshed via `exercises.didSet`. Defines structural equality for
    // "same plan" matching. Optional for the same backward-compat reasons as
    // lineageId.
    var fingerprint: String?

    // empty initializer
    init() {
        self.id = UUID()
        self.name = ""
        self.exercises = []
        self.lineageId = UUID()
        self.fingerprint = Self.computeFingerprint(for: [])
    }

    // create new WorkoutPlan object with specified params
    init(name: String, exercises: [Exercise], lastCompleted: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.exercises = exercises
        self.lastCompleted = lastCompleted
        self.lineageId = UUID()
        self.fingerprint = Self.computeFingerprint(for: exercises)
    }

    // didSet does not fire during init or Codable decode — call this after
    // those paths (migration, import) to populate fingerprint.
    mutating func refreshFingerprint() {
        self.fingerprint = Self.computeFingerprint(for: exercises)
    }

    // Length-prefixed canonical encoding avoids collision bugs from unescaped
    // delimiters (newline / pipe in exercise names). Format per exercise:
    //   "<utf8ByteCount>:<lowercased trimmed name>|<setCount>;"
    static func computeFingerprint(for exercises: [Exercise]) -> String {
        let canonical = exercises.map { exercise -> String in
            let normalized = exercise.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let nameBytes = normalized.utf8.count
            return "\(nameBytes):\(normalized)|\(exercise.sets.count);"
        }.joined()

        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
