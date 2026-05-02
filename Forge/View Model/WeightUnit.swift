import Foundation

/// User-facing weight unit preference. The enum doubles as a namespace
/// for the unit-conversion + display helpers — every weight in the app
/// is stored in lb internally, so the helpers all take an lb-valued
/// `Double` and either format it in the user's preferred unit or convert
/// to the alternate.
enum WeightUnit: String, CaseIterable, Codable {
    case lb
    case kg

    /// Single-noun label used in compact displays — e.g. wheel suffix,
    /// chart axes, PR badges. Plural-form already; this app reads
    /// "175 lb" / "79.4 kg" naturally without case agreement.
    var shortLabel: String {
        switch self {
        case .lb: return "lb"
        case .kg: return "kg"
        }
    }

    /// Plural noun label for input field suffixes that read better with
    /// the trailing "s". Matches the existing "lbs" usage in pickers.
    var pluralLabel: String {
        switch self {
        case .lb: return "lbs"
        case .kg: return "kgs"
        }
    }

    /// The opposite unit, used for the WeightHistoryView parenthetical
    /// fallback when no height is set ("(79.4 kg)" alongside "175 lb").
    var alternate: WeightUnit {
        switch self {
        case .lb: return .kg
        case .kg: return .lb
        }
    }

    // MARK: - conversion

    static let lbsPerKg: Double = 2.2046226218

    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / lbsPerKg
    }

    static func kgToLbs(_ kg: Double) -> Double {
        kg * lbsPerKg
    }

    // MARK: - formatting

    /// Formats an lb-valued weight in the chosen display unit. Uses 1
    /// decimal place except for whole numbers in lb (matches the
    /// existing `formatLbs` style). kg always shows 1 decimal because
    /// integer kg values are rare for US-stored weights.
    static func formatWeight(lbs: Double, in unit: WeightUnit) -> String {
        switch unit {
        case .lb: return formatLbs(lbs)
        case .kg: return formatKg(lbs)
        }
    }

    /// Net-difference label in the chosen unit. Sign / arrow handled by
    /// caller; this returns the magnitude only ("2.5 lb" or "1.1 kg").
    static func formatDiffWeight(deltaLbs: Double, in unit: WeightUnit) -> String {
        let absLbs = Swift.abs(deltaLbs)
        switch unit {
        case .lb: return formatDiffLbs(absLbs)
        case .kg:
            let kg = lbsToKg(absLbs)
            let rounded = (kg * 10).rounded() / 10
            return String(format: "%.1f kg", rounded)
        }
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

    // MARK: - BMI

    /// Returns `"BMI: 23.7"` when both weight and height are usable;
    /// `nil` if `heightCm` is nil or non-positive (no UI fallback —
    /// callers handle the nil case by rendering an alternate string).
    static func formatBmi(weightLbs: Double, heightCm: Double?) -> String? {
        guard let heightCm, heightCm > 0 else { return nil }
        let weightKg = lbsToKg(weightLbs)
        let heightM = heightCm / 100
        let bmi = weightKg / (heightM * heightM)
        let rounded = (bmi * 10).rounded() / 10
        return String(format: "BMI: %.1f", rounded)
    }

    // MARK: - height conversion

    static let cmPerInch: Double = 2.54

    /// Splits a cm value into (wholeFeet, remainingInches) for the
    /// dual-field height input in lb mode.
    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / cmPerInch
        let feet = Int(totalInches / 12)
        let inches = totalInches - Double(feet * 12)
        return (feet, inches)
    }

    static func feetInchesToCm(feet: Int, inches: Double) -> Double {
        let totalInches = Double(feet * 12) + inches
        return totalInches * cmPerInch
    }
}
