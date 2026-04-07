import Foundation
import SwiftUI

class GlobalSettings {
    static let shared = GlobalSettings()

    // Brand colors
    let fgColor = Color(red: 255/255, green: 67/255, blue: 107/255) // accent
    let bgColor = Color(red: 22/255, green: 22/255, blue: 22/255)   // background

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
    let breakDuration: Int = 60

    private init() {}
}
