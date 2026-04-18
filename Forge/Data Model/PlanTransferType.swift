import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let forgePlan = UTType(exportedAs: "Ryan-Div.Forge.workoutPlan")
}

extension WorkoutPlan {
    // SF symbols handed to SharePreview as `Image(systemName:)` render blank in
    // the iOS share sheet — it expects a rasterized bitmap. Pre-render to a
    // UIImage at a generous point size so the preview thumbnail shows the icon.
    static let sharePreviewImage: Image = {
        let config = UIImage.SymbolConfiguration(pointSize: 160, weight: .semibold)
        let forgeRed = UIColor(red: 1.0, green: 67.0 / 255.0, blue: 107.0 / 255.0, alpha: 1.0)
        let rendered = UIImage(systemName: "dumbbell.fill", withConfiguration: config)?
            .withTintColor(forgeRed, renderingMode: .alwaysOriginal) ?? UIImage()
        return Image(uiImage: rendered)
    }()
}

extension WorkoutPlan: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .forgePlan) { plan in
            let data = try JSONEncoder().encode(plan)
            let safeName = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let fileBase = safeName.isEmpty ? "Workout Plan" : safeName
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileBase)
                .appendingPathExtension("forgeplan")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }

        FileRepresentation(importedContentType: .forgePlan) { received in
            let data = try Data(contentsOf: received.file)
            return try JSONDecoder().decode(WorkoutPlan.self, from: data)
        }
    }
}
