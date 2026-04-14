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

    private var cancellable: AnyCancellable?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: "colorTheme"),
           let theme = ColorTheme(rawValue: raw) {
            _colorTheme = Published(initialValue: theme)
        }

        cancellable = $colorTheme
            .dropFirst()
            .sink { theme in
                UserDefaults.standard.set(theme.rawValue, forKey: "colorTheme")
            }
    }
}
