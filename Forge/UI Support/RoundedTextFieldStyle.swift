import Foundation
import SwiftUI

// Used to create a rounded textfield style
struct RoundedTextFieldStyle: TextFieldStyle {
    var borderColor: Color
    var borderOpacity: Double
    var backgroundColor: Color

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(EdgeInsets(top: 30, leading: 10, bottom: 30, trailing: 10))
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(borderColor.opacity(borderOpacity), lineWidth: 1)
                    )
            )
    }
}
