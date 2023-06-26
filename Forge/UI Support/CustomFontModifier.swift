import Foundation
import SwiftUI

// Used to add custom font styling to textfields
struct CustomFontModifier: ViewModifier {
    var size: CGFloat
    var weight: Font.Weight
    var color: Color
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: .default))
            .foregroundColor(color.opacity(opacity))
    }
}
