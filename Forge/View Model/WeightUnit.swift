import Foundation

enum WeightUnit {

    static let lbsPerKg: Double = 2.2046226218

    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / lbsPerKg
    }

    static func formatLbs(_ lbs: Double) -> String {
        let rounded = (lbs * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) lb"
        }
        return String(format: "%.1f lb", rounded)
    }

    static func formatKg(_ lbs: Double) -> String {
        let kg = lbsToKg(lbs)
        let rounded = (kg * 10).rounded() / 10
        return String(format: "%.1f kg", rounded)
    }

    /// Net difference label, e.g. "2.5 lb" — sign and arrow handled by caller.
    static func formatDiffLbs(_ deltaLbs: Double) -> String {
        let abs = Swift.abs(deltaLbs)
        let rounded = (abs * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) lb"
        }
        return String(format: "%.1f lb", rounded)
    }
}
