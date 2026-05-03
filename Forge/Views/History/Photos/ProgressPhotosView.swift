import SwiftUI

struct ProgressPhotosView: View {

    @EnvironmentObject var photos: ProgressPhotosViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var showAddSheet = false
    @State private var entryPendingDelete: ProgressPhotoEntry?

    private let darkGray = GlobalSettings.shared.darkGray
    private let bgColor = GlobalSettings.shared.bgColor

    var body: some View {
        Group {
            if photos.entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .toolbar {
            // Native bottom bar — iOS renders this in Liquid Glass to
            // match the Start Workout button on the History root.
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    showAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .padding(.trailing, 3)
                        Text("Add Entry")
                    }
                }
                .padding(5)
                .padding(.horizontal, 10)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddProgressPhotosSheet()
                .environmentObject(photos)
                .environmentObject(settings)
                .environment(\.colorScheme, .dark)
        }
        .alert(
            "Delete this entry?",
            isPresented: Binding(
                get: { entryPendingDelete != nil },
                set: { if !$0 { entryPendingDelete = nil } }
            ),
            presenting: entryPendingDelete
        ) { entry in
            Button("Delete", role: .destructive) {
                photos.deleteEntry(id: entry.id)
                entryPendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                entryPendingDelete = nil
            }
        } message: { _ in
            Text("Photos will be permanently removed.")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(darkGray)
            Text("No progress photos yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Tap Add Entry to upload your first set.")
                .font(.system(size: 13))
                .foregroundColor(darkGray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entries list

    private var entriesList: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(photos.entries) { entry in
                    EntryCard(
                        entry: entry,
                        photos: photos,
                        onLongPress: { entryPendingDelete = entry }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
    }

}

// MARK: - Entry card

private struct EntryCard: View {

    let entry: ProgressPhotoEntry
    let photos: ProgressPhotosViewModel
    let onLongPress: () -> Void

    @EnvironmentObject var settings: GlobalSettings

    @State private var pageIndex: Int = 0

    private let darkGray = GlobalSettings.shared.darkGray
    private let bgColor = GlobalSettings.shared.bgColor

    private var poses: [ProgressPhotoPose] { photos.presentPoses(for: entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatDate(entry.date))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(relativeLabel(for: entry.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(darkGray)
            }

            ZStack(alignment: .bottom) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(poses.enumerated()), id: \.element) { index, pose in
                        photoPage(pose: pose)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: poses.count > 1 ? .always : .never))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .aspectRatio(4.0/5.0, contentMode: .fit)
                .background(bgColor)
                .cornerRadius(settings.cornerRadiusLarge)
            }

            if poses.indices.contains(pageIndex) {
                Text(poses[pageIndex].label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(darkGray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .background(bgColor.opacity(0.6))
        .cornerRadius(settings.cornerRadiusLarge)
        .onLongPressGesture(minimumDuration: 0.4) {
            onLongPress()
        }
        .onAppear {
            if pageIndex >= poses.count {
                pageIndex = 0
            }
        }
    }

    @ViewBuilder
    private func photoPage(pose: ProgressPhotoPose) -> some View {
        if let filename = photos.filename(for: entry, pose: pose),
           let image = photos.loadImage(filename: filename) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                Text("Image missing")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(darkGray)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        if let day = calendar.dateComponents([.day], from: startOfDate, to: startOfNow).day, day > 0 {
            return day < 30 ? "\(day) days ago" : ""
        }
        return ""
    }
}

#Preview("Populated") {
    ProgressPhotosView()
        .environmentObject(makeMockProgressPhotosVM())
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    ProgressPhotosView()
        .environmentObject(ProgressPhotosViewModel(mockEntries: []))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}
