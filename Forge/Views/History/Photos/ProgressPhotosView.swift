import SwiftUI

struct ProgressPhotosView: View {

    @EnvironmentObject var photos: ProgressPhotosViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var showAddSheet = false
    @State private var entryPendingDelete: ProgressPhotoEntry?
    @State private var currentEntryIndex: Int = 0

    private let darkGray = GlobalSettings.shared.darkGray
    private let bgColor = GlobalSettings.shared.bgColor

    init() {
        // Bump the native PageTabViewStyle dot size globally. Default is
        // ~7pt; the bold 13pt circle is large enough to be a comfortable
        // touch target while still feeling like the standard iOS dots.
        // Safe to set globally — only one other PageTabViewStyle exists
        // in the app (HistoryView) and it uses indexDisplayMode: .never,
        // so this appearance never renders there.
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        UIPageControl.appearance().preferredIndicatorImage =
            UIImage(systemName: "circle.fill", withConfiguration: config)
    }

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
                        Text("Add Photos")
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
            Text("Tap Add Photos to upload your first set.")
                .font(.system(size: 13))
                .foregroundColor(darkGray)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Entries list

    private var entriesList: some View {
        // Cards as a horizontal carousel — swipe sideways to move between
        // entries. Each page vertically centers its card inside the
        // available area (overflowing into a scroll view if the card is
        // taller than the viewport). Per-pose navigation lives inside the
        // card via chevron buttons (no swipe conflict).
        //
        // Uses the native PageTabViewStyle indicator (UIPageControl under
        // the hood) so the press-and-drag-to-scrub interaction works. Dot
        // size is bumped to ~13pt via UIPageControl.appearance() in init.
        TabView(selection: $currentEntryIndex) {
            ForEach(Array(photos.entries.enumerated()), id: \.element.id) { index, entry in
                GeometryReader { proxy in
                    ScrollView {
                        EntryCard(
                            entry: entry,
                            photos: photos,
                            onLongPress: { entryPendingDelete = entry }
                        )
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height, alignment: .center)
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: photos.entries.count > 1 ? .always : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .onChange(of: photos.entries.count) { _, newCount in
            if currentEntryIndex >= newCount {
                currentEntryIndex = max(0, newCount - 1)
            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(formatDate(entry.date))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(relativeLabel(for: entry.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(darkGray)
            }

            // Single photo at a time — chevrons below cycle through poses.
            // No TabView here so the parent carousel's horizontal swipe
            // owns gesture handling exclusively.
            Group {
                if poses.indices.contains(pageIndex) {
                    photoPage(pose: poses[pageIndex])
                } else {
                    Color.clear
                }
            }
            .aspectRatio(4.0/5.0, contentMode: .fit)
            .background(bgColor)
            .cornerRadius(settings.cornerRadiusLarge)

            // Segmented capsule indicator — same style as the plan
            // suggestion carousel. Sits above the pose label.
            if poses.count > 1 {
                HStack(spacing: 5) {
                    ForEach(poses.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == pageIndex ? settings.fgColor : Color(white: 0.25))
                            .frame(width: 14, height: 3)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            poseNavRow
                // Fixed height keeps the card the same size whether the
                // chevron buttons are present (multi-pose) or absent
                // (single-pose, label-only fallback).
                .frame(height: poseNavRowHeight)
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

    private let poseNavRowHeight: CGFloat = 32

    /// `‹  pose label  ›` row. With only one pose, falls back to a
    /// centered label (no buttons). Boundaries don't wrap — chevrons
    /// disable + dim at index 0 (left) and last index (right).
    @ViewBuilder
    private var poseNavRow: some View {
        if poses.count > 1 {
            let atFirst = pageIndex == 0
            let atLast = pageIndex == poses.count - 1
            HStack {
                navButton(systemName: "chevron.left", disabled: atFirst, action: goPrev)
                Spacer()
                if poses.indices.contains(pageIndex) {
                    Text(poses[pageIndex].label)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                navButton(systemName: "chevron.right", disabled: atLast, action: goNext)
            }
        } else if poses.indices.contains(pageIndex) {
            Text(poses[pageIndex].label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(darkGray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func navButton(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(settings.fgColor)
                .frame(width: 44, height: 32)
                .background(bgColor.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
    }

    private func goPrev() {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
    }

    private func goNext() {
        guard pageIndex < poses.count - 1 else { return }
        pageIndex += 1
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
