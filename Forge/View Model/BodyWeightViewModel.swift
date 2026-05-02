import Foundation

class BodyWeightViewModel: ObservableObject {

    @Published var entries: [BodyWeightEntry]

    private let userDefaults: UserDefaults
    private let storageKey = "bodyWeightEntries"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.entries = []
        self.entries = loadEntries()
    }

    init(mockEntries entries: [BodyWeightEntry], userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.entries = entries.sorted(by: { $0.date > $1.date })
    }

    @discardableResult
    func addEntry(weightLbs: Double, date: Date = Date()) -> BodyWeightEntry {
        let entry = BodyWeightEntry(date: date, weightLbs: weightLbs)
        entries.append(entry)
        entries.sort(by: { $0.date > $1.date })
        saveEntries()
        return entry
    }

    func deleteEntry(id: UUID) {
        entries.removeAll(where: { $0.id == id })
        saveEntries()
    }

    /// Difference (in lbs) from `earlier` to `later`. Positive = gained weight.
    func netDifference(from earlier: BodyWeightEntry, to later: BodyWeightEntry) -> Double {
        later.weightLbs - earlier.weightLbs
    }
}

extension BodyWeightViewModel {

    func loadEntries() -> [BodyWeightEntry] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        guard let decoded = try? JSONDecoder().decode([BodyWeightEntry].self, from: data) else { return [] }
        return decoded.sorted(by: { $0.date > $1.date })
    }

    func saveEntries() {
        if let encoded = try? JSONEncoder().encode(entries) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
}
