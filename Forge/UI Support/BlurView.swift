import Foundation
import SwiftUI

// creates a transparent blur background for the makeshift bottom toolbar
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: UIViewRepresentableContext<BlurView>) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: style))
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<BlurView>) { }
}

