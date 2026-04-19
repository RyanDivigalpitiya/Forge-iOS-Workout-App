import SwiftUI
import UIKit

@ViewBuilder
func avatar(data: Data?, fallbackInitial: String, diameter: CGFloat) -> some View {
    if let data, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    } else {
        ZStack {
            Circle()
                .fill(Color(white: 0.2))
            Text(fallbackInitial)
                .font(.system(size: diameter * 0.45, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

func initial(from name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = trimmed.first else { return "?" }
    return String(first).uppercased()
}

func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let size = image.size
    let longestSide = max(size.width, size.height)
    guard longestSide > maxSide else { return image }
    let scale = maxSide / longestSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1.0
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
}

struct ShareableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
