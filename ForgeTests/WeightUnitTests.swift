import Foundation
import Testing
@testable import Forge

/// Conversion + formatting helpers used by every weight surface in
/// the app. Kept separate from `BodyWeightViewModelTests` because
/// these are pure functions with no UserDefaults dependency.
struct WeightUnitTests {

    private let tolerance = 0.001

    // MARK: - lb ↔ kg

    @Test func lbsToKgZero() {
        #expect(WeightUnit.lbsToKg(0) == 0)
    }

    @Test func lbsToKgRoundTrip() {
        for lbs in [0.0, 1.0, 50.0, 100.0, 175.5, 220.46226218, 500.0] {
            let roundTripped = WeightUnit.kgToLbs(WeightUnit.lbsToKg(lbs))
            #expect(abs(roundTripped - lbs) < tolerance)
        }
    }

    @Test func lbsToKg220IsApprox100() {
        #expect(abs(WeightUnit.lbsToKg(220.46226218) - 100) < tolerance)
    }

    // MARK: - formatWeight(in:)

    @Test func formatWeightInLb() {
        #expect(WeightUnit.formatWeight(lbs: 175, in: .lb) == "175 lb")
        #expect(WeightUnit.formatWeight(lbs: 175.5, in: .lb) == "175.5 lb")
    }

    @Test func formatWeightInKg() {
        // 175 lb → 79.378 kg → "79.4 kg"
        #expect(WeightUnit.formatWeight(lbs: 175, in: .kg) == "79.4 kg")
    }

    // MARK: - formatDiffWeight

    @Test func formatDiffWeightLb() {
        #expect(WeightUnit.formatDiffWeight(deltaLbs: 2.5, in: .lb) == "2.5 lb")
        #expect(WeightUnit.formatDiffWeight(deltaLbs: -2.5, in: .lb) == "2.5 lb")
    }

    @Test func formatDiffWeightKg() {
        // 2.5 lb → 1.13 kg → "1.1 kg"
        #expect(WeightUnit.formatDiffWeight(deltaLbs: 2.5, in: .kg) == "1.1 kg")
    }

    // MARK: - BMI

    @Test func formatBmiNilWhenHeightMissing() {
        #expect(WeightUnit.formatBmi(weightLbs: 175, heightCm: nil) == nil)
    }

    @Test func formatBmiNilWhenHeightZero() {
        #expect(WeightUnit.formatBmi(weightLbs: 175, heightCm: 0) == nil)
    }

    @Test func formatBmiKnownValue() {
        // 175 lb @ 180 cm → 79.378 kg / (1.80 m)^2 = 24.499 → "BMI: 24.5"
        #expect(WeightUnit.formatBmi(weightLbs: 175, heightCm: 180) == "BMI: 24.5")
    }

    @Test func formatBmiOneDecimalPlace() {
        // Sanity: result always has exactly one decimal place.
        let result = WeightUnit.formatBmi(weightLbs: 150, heightCm: 175)!
        #expect(result.hasPrefix("BMI: "))
        let numPart = String(result.dropFirst("BMI: ".count))
        #expect(numPart.contains("."))
    }

    // MARK: - height conversion

    @Test func cmToFeetInches180() {
        // 180 cm = 70.866 in → 5 ft 10.866 in
        let result = WeightUnit.cmToFeetInches(180)
        #expect(result.feet == 5)
        #expect(abs(result.inches - 10.866) < 0.01)
    }

    @Test func feetInchesToCm5_11() {
        // 5 ft 11 in = 71 in × 2.54 = 180.34 cm
        #expect(abs(WeightUnit.feetInchesToCm(feet: 5, inches: 11) - 180.34) < 0.001)
    }

    @Test func heightRoundTripsViaCm() {
        let originalCm = 180.34
        let split = WeightUnit.cmToFeetInches(originalCm)
        let recombined = WeightUnit.feetInchesToCm(feet: split.feet, inches: split.inches)
        #expect(abs(recombined - originalCm) < tolerance)
    }

    // MARK: - shortLabel / pluralLabel / alternate

    @Test func shortLabel() {
        #expect(WeightUnit.lb.shortLabel == "lb")
        #expect(WeightUnit.kg.shortLabel == "kg")
    }

    @Test func pluralLabel() {
        #expect(WeightUnit.lb.pluralLabel == "lbs")
        #expect(WeightUnit.kg.pluralLabel == "kgs")
    }

    @Test func alternate() {
        #expect(WeightUnit.lb.alternate == .kg)
        #expect(WeightUnit.kg.alternate == .lb)
    }
}
