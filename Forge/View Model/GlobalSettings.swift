import Foundation
import SwiftUI
import Combine

enum ColorTheme: String, CaseIterable, Codable {
    case red
    case blue
    case green
    case orange
    case purple
    case yellow

    var color: Color {
        switch self {
        case .red:    return Color(red: 255/255, green: 67/255, blue: 107/255)
        case .blue:   return Color(red: 74/255, green: 144/255, blue: 217/255)
        case .green:  return Color(red: 52/255, green: 199/255, blue: 89/255)
        case .orange: return Color(red: 255/255, green: 149/255, blue: 0/255)
        case .purple: return Color(red: 175/255, green: 82/255, blue: 222/255)
        case .yellow: return Color(red: 255/255, green: 214/255, blue: 10/255)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}

class GlobalSettings: ObservableObject {
    static let shared = GlobalSettings()

    // Accent color — persisted as ColorTheme in UserDefaults.
    // Persistence uses a Combine sink rather than didSet, because
    // didSet on @Published properties can break objectWillChange
    // delivery in some Swift versions.
    @Published var colorTheme: ColorTheme = .red
    var fgColor: Color { colorTheme.color }

    // Display unit for every weight in the app (body weight, lifted
    // weights, PRs, charts). Storage stays in lb regardless — this is a
    // pure display preference. Default lb (no Locale autodetect in v1).
    @Published var weightUnit: WeightUnit = .lb

    // User's height in cm — feeds the BMI parenthetical in WeightHistoryView.
    // Nil = unset → BMI falls back to opposite-unit weight string.
    // Local-only; never broadcast to collab peers.
    @Published var heightCm: Double? = nil

    // Background
    let bgColor = Color(red: 22/255, green: 22/255, blue: 22/255)

    // Grayscale palette
    let darkGray = Color(red: 0.25, green: 0.25, blue: 0.25)            // workout/history connectors & subtitles
    let editorDarkGray = Color(red: 0.33, green: 0.33, blue: 0.33)      // editor view labels & hints
    let buttonCircleBgColor = Color(red: 0.20, green: 0.20, blue: 0.20) // circular icon button bg

    // Layout dimensions
    let bottomToolbarHeight: CGFloat = 100
    let setButtonSize: CGFloat = 28
    let setsFontSize: CGFloat = 20
    let setsSpacing: CGFloat = 3

    // Corner radii. Migrate call sites whose literal matches one of these
    // exactly AND whose semantic bucket agrees — don't fold idiosyncratic
    // one-off radii (e.g. the animated topToolBarCornerRadius that sweeps
    // 0 → 30 as the break panel expands) into the shared scale.
    let cornerRadiusSmall: CGFloat = 5   // chips, pill-shaped buttons
    let cornerRadiusMedium: CGFloat = 8  // cards, carousel items, input fields
    let cornerRadiusLarge: CGFloat = 16  // full panels, exercise blocks, gradient-bg containers

    // Standard animation durations. Same discipline: only use when the
    // intent matches; leave bespoke durations (2s finish-workout fade,
    // 0.25s peerPosition anchor tween, 0.15s spring bounces) as literals.
    let animationQuick: Double = 0.2     // set-tap pop feedback, small UI state toggles
    let animationStandard: Double = 0.5  // scroll-view shrink/grow, break-timer transitions
    let animationSlow: Double = 1.0      // opacity fade-ins after the starting countdown

    // Timing
    var breakDuration: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: "breakDurationSeconds")
            return value > 0 ? value : 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "breakDurationSeconds")
        }
    }

    private var cancellables: [AnyCancellable] = []

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "colorTheme"),
           let theme = ColorTheme(rawValue: raw) {
            _colorTheme = Published(initialValue: theme)
        }
        if let raw = UserDefaults.standard.string(forKey: "weightUnit"),
           let unit = WeightUnit(rawValue: raw) {
            _weightUnit = Published(initialValue: unit)
        }
        // `object(forKey:)` returns nil if the key was removed — that's
        // the "unset" state we want to round-trip cleanly when the user
        // clears their height.
        if let cm = UserDefaults.standard.object(forKey: "heightCm") as? Double {
            _heightCm = Published(initialValue: cm)
        }
        cancellables.append($colorTheme
            .dropFirst()
            .sink { theme in
                UserDefaults.standard.set(theme.rawValue, forKey: "colorTheme")
            })
        cancellables.append($weightUnit
            .dropFirst()
            .sink { unit in
                UserDefaults.standard.set(unit.rawValue, forKey: "weightUnit")
            })
        cancellables.append($heightCm
            .dropFirst()
            .sink { cm in
                if let cm {
                    UserDefaults.standard.set(cm, forKey: "heightCm")
                } else {
                    UserDefaults.standard.removeObject(forKey: "heightCm")
                }
            })
    }
}
