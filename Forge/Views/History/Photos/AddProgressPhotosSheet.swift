import SwiftUI
import PhotosUI

struct AddProgressPhotosSheet: View {

    @EnvironmentObject var photos: ProgressPhotosViewModel
    @EnvironmentObject var settings: GlobalSettings
    @Environment(\.dismiss) private var dismiss

    @State private var entryDate: Date = Date()

    @State private var frontItem: PhotosPickerItem?
    @State private var sideItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?

    @State private var frontImage: UIImage?
    @State private var sideImage: UIImage?
    @State private var backImage: UIImage?

    private let darkGray = GlobalSettings.shared.editorDarkGray
    private let bgColor = GlobalSettings.shared.bgColor
    private let buttonCircleBgColor = GlobalSettings.shared.buttonCircleBgColor
    private let fontTitleSize: CGFloat = 26

    private var screenWidth: CGFloat { UIScreen.main.bounds.width }

    private var hasAnyImage: Bool {
        frontImage != nil || sideImage != nil || backImage != nil
    }

    var body: some View {
        VStack(spacing: 0) {

            // TOP TOOLBAR — X | title | up-arrow
            HStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .frame(width: 28, height: 28)
                                .foregroundColor(buttonCircleBgColor)
                            Image(systemName: "xmark")
                                .resizable()
                                .frame(width: 11, height: 11)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(width: 0.2 * screenWidth)

                HStack {
                    Text("Add Progress Photos")
                        .font(.system(size: fontTitleSize))
                        .foregroundColor(settings.fgColor)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 0.6 * screenWidth)

                HStack {
                    Button {
                        save()
                    } label: {
                        ZStack {
                            Circle()
                                .frame(width: 28, height: 28)
                                .foregroundColor(buttonCircleBgColor)
                            Image(systemName: "arrow.up")
                                .resizable()
                                .frame(width: 13, height: 13)
                                .fontWeight(.bold)
                                .foregroundColor(hasAnyImage ? settings.fgColor : .gray)
                        }
                    }
                    .disabled(!hasAnyImage)
                }
                .frame(width: 0.2 * screenWidth)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 16) {
                    DatePicker(
                        "Date",
                        selection: $entryDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bgColor)
                    .cornerRadius(settings.cornerRadiusMedium)

                    poseSlot(
                        label: "Front",
                        item: $frontItem,
                        image: $frontImage
                    )
                    poseSlot(
                        label: "Side",
                        item: $sideItem,
                        image: $sideImage
                    )
                    poseSlot(
                        label: "Back",
                        item: $backItem,
                        image: $backImage
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onChange(of: frontItem) { _, newItem in load(item: newItem, into: $frontImage) }
        .onChange(of: sideItem) { _, newItem in load(item: newItem, into: $sideImage) }
        .onChange(of: backItem) { _, newItem in load(item: newItem, into: $backImage) }
    }

    @ViewBuilder
    private func poseSlot(
        label: String,
        item: Binding<PhotosPickerItem?>,
        image: Binding<UIImage?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(darkGray)

            PhotosPicker(selection: item, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    RoundedRectangle(cornerRadius: settings.cornerRadiusMedium)
                        .fill(bgColor)
                        .aspectRatio(4.0/5.0, contentMode: .fit)

                    if let img = image.wrappedValue {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadiusMedium))
                    } else {
                        VStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 26, weight: .semibold))
                            Text("Choose photo")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(darkGray)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func load(item: PhotosPickerItem?, into binding: Binding<UIImage?>) {
        guard let item else {
            binding.wrappedValue = nil
            return
        }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data)
            else { return }
            await MainActor.run {
                binding.wrappedValue = uiImage
            }
        }
    }

    private func save() {
        guard hasAnyImage else { return }
        photos.addEntry(
            date: entryDate,
            front: frontImage,
            side: sideImage,
            back: backImage
        )
        dismiss()
    }
}

#Preview("Empty form") {
    AddProgressPhotosSheet()
        .environmentObject(ProgressPhotosViewModel(mockEntries: []))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}
