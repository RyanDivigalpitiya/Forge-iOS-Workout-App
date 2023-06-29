import Foundation
import SwiftUI

class GlobalSettings {
    static let shared = GlobalSettings()
    
    // Colour Theme
    let fgColor = Color(red: 255/255, green: 67/255, blue: 107/255) // Default Foreground colour
    let bgColor = Color.gray.opacity(0.15) // Default Background colour
    let listItemBgColor = Color(red: 0.08, green: 0.08, blue: 0.08) // Secondary Default Background colour
    
    // Common UI component dimensions
    let bottomToolbarHeight: CGFloat = 100

    private init() {}
}

