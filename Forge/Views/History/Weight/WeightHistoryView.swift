import SwiftUI

struct WeightHistoryView: View {

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var sheetTarget: WeightSheetTarget?
    @State private var showHeightSheet = false

    /// Entry IDs whose row has played the on-appear cascade. Rows render
    /// at opacity 0 + .offset(y: 24) — sliding up from below — until the
    /// id lands here. Mirrors `SelectPlanView`'s plan-row cascade.
    @State private var appearedEntryIds: Swift.Set<UUID> = []
    @State private var entryCascadeTask: Task<Void, Never>?
    /// Set true when the cascade loop completes. Any entry added AFTER
    /// the cascade finishes (e.g. logged via the Update Weight sheet
    /// while we already animated the existing list) renders at final
    /// state via the `isAppeared` short-circuit. Reset to false on every
    /// new cascade.
    @State private var entryCascadeFinished = false

    /// Drives the "newly added entry bounces" animation. Same recipe as
    /// `PlanSuggestionView.bounceSuggestedPane()` — quick scale up, slow
    /// spring back. Only the row matching `bouncingEntryId` reads the
    /// scale; everything else stays at 1.0.
    @State private var bounceScale: CGFloat = 1.0
    @State private var bouncingEntryId: UUID?
    @State private var lastObservedEntryCount: Int = 0

    private let darkGray = GlobalSettings.shared.darkGray
    private let nodeSize: CGFloat = 8
    private let diffDotSize: CGFloat = 5
    private let connectorWidth: CGFloat = 1
    private let timelineColumnWidth: CGFloat = 28

    var body: some View {
        Group {
            if bodyWeight.entries.isEmpty {
                emptyState
            } else {
                timeline
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .sheet(item: $sheetTarget) { target in
            Group {
                switch target {
                case .new:
                    UpdateWeightSheet()
                case .edit(let entry):
                    UpdateWeightSheet(editingEntry: entry)
                }
            }
            .environmentObject(bodyWeight)
            .environmentObject(settings)
            .environment(\.colorScheme, .dark)
        }
        .sheet(isPresented: $showHeightSheet) {
            EditHeightSheet()
                .environmentObject(settings)
                .environment(\.colorScheme, .dark)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHeightSheet = true
                } label: {
                    Image(systemName: "ruler")
                        .foregroundColor(settings.fgColor)
                }
            }
            // Native bottom bar — iOS renders this in Liquid Glass to
            // match the Start Workout button on the History root.
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    sheetTarget = .new
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .padding(.trailing, 3)
                        Text("Update Weight")
                    }
                }
                .padding(5)
                .padding(.horizontal, 10)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(settings.fgColor)
            }
        }
        .onAppear {
            triggerEntryCascade()
            lastObservedEntryCount = bodyWeight.entries.count
        }
        .onChange(of: bodyWeight.entries.count) { oldCount, newCount in
            // Only bounce on adds (not deletes). The added entry is at
            // index 0 (entries are stored newest-first), so we bounce
            // whichever id is now at the top. Small delay lets the
            // sheet finish dismissing before the bounce plays.
            if newCount > oldCount, let topId = bodyWeight.entries.first?.id {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    bounceEntry(id: topId)
                }
            }
            lastObservedEntryCount = newCount
        }
    }

    /// Replays the staggered fade + slide-up-from-below cascade across
    /// every visible weight entry. Same timing as `SelectPlanView`'s
    /// plan-row cascade (80ms initial settle, 0.7s easeOut per row,
    /// 80ms inter-row delay). The loop re-reads `bodyWeight.entries`
    /// each iteration so an entry added mid-cascade gets picked up.
    /// `entryCascadeFinished` covers the post-cascade case so late
    /// additions render visible instead of stuck blank.
    private func triggerEntryCascade() {
        entryCascadeTask?.cancel()
        appearedEntryIds = []
        entryCascadeFinished = false
        entryCascadeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            while !Task.isCancelled {
                let allIdsTopFirst = bodyWeight.entries.map(\.id)
                guard let nextId = allIdsTopFirst.first(where: {
                    !appearedEntryIds.contains($0)
                }) else { break }
                withAnimation(.easeOut(duration: 0.7)) {
                    _ = appearedEntryIds.insert(nextId)
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
            entryCascadeFinished = true
        }
    }

    private func diffSignPrefix(_ delta: Double) -> String {
        if delta > 0 { return "+" }
        if delta < 0 { return "-" }
        return ""
    }

    /// Bounces the newly added entry: quick scale up, slow spring back.
    /// Mirrors `PlanSuggestionView.bounceSuggestedPane()` exactly.
    private func bounceEntry(id: UUID) {
        bouncingEntryId = id
        bounceScale = 1.0
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            bounceScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                bounceScale = 1.0
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "scalemass")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(darkGray)
            Text("No weight logged yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            Text("Tap Update Weight to log your first entry.")
                .font(.system(size: 13))
                .foregroundColor(darkGray)
            if settings.heightCm == nil {
                Button {
                    showHeightSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "ruler")
                            .font(.system(size: 12, weight: .bold))
                        Text("Add height for BMI")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(settings.fgColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding(.top, 8)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Timeline

    private var timeline: some View {
        // GeometryReader lets us anchor the entries column vertically:
        // - When the column is shorter than the viewport, `frame(minHeight:
        //   proxy.size.height, alignment: .center)` centers it vertically.
        // - Once the column overflows the viewport, the inner VStack grows
        //   beyond minHeight and the ScrollView scrolls naturally with the
        //   newest (top) entry pinned to the top edge.
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    ForEach(Array(bodyWeight.entries.enumerated()), id: \.element.id) { index, entry in
                        let isAppeared = entryCascadeFinished || appearedEntryIds.contains(entry.id)
                        VStack(spacing: 0) {
                            if index == 0 {
                                // "Latest:" label aligned with the weight column
                                // — the leading spacers match the days-ago + timeline
                                // column widths used in entryRow.
                                HStack(spacing: 12) {
                                    Color.clear.frame(width: 90, height: 1)
                                    Color.clear.frame(width: timelineColumnWidth, height: 1)
                                    Text("Latest:")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.bottom, 2)
                            }

                            Button {
                                sheetTarget = .edit(entry)
                            } label: {
                                entryRow(
                                    entry: entry,
                                    isFirst: index == 0,
                                    isLast: index == bodyWeight.entries.count - 1
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if index < bodyWeight.entries.count - 1 {
                                let later = bodyWeight.entries[index]
                                let earlier = bodyWeight.entries[index + 1]
                                netDiffRow(
                                    delta: bodyWeight.netDifference(from: earlier, to: later)
                                )
                            }
                        }
                        .opacity(isAppeared ? 1 : 0)
                        .offset(y: isAppeared ? 0 : 24)
                        .scaleEffect(entry.id == bouncingEntryId ? bounceScale : 1.0)
                    }
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func entryRow(entry: BodyWeightEntry, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(daysAgoLabel(for: entry.date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFirst ? .white : darkGray)
                .frame(width: 90, alignment: .trailing)

            timelineColumn(
                isFirst: isFirst,
                isLast: isLast,
                node: Circle()
                    .fill(settings.fgColor)
                    .frame(width: nodeSize, height: nodeSize)
            )

            HStack(spacing: 6) {
                Text(WeightUnit.formatWeight(lbs: entry.weightLbs, in: settings.weightUnit))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(settings.fgColor)
                parentheticalView(for: entry)
                Spacer()
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func parentheticalView(for entry: BodyWeightEntry) -> some View {
        Text("(\(parentheticalLabel(for: entry)))")
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(darkGray)
    }

    /// BMI when height is set, otherwise the weight rendered in the
    /// opposite unit (e.g. "175 lb" → "(79.4 kg)" when no height).
    private func parentheticalLabel(for entry: BodyWeightEntry) -> String {
        if let bmi = WeightUnit.formatBmi(weightLbs: entry.weightLbs, heightCm: settings.heightCm) {
            return bmi
        }
        return WeightUnit.formatWeight(lbs: entry.weightLbs, in: settings.weightUnit.alternate)
    }

    @ViewBuilder
    private func netDiffRow(delta: Double) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Color.clear
                .frame(width: 90, height: 1)

            timelineColumn(
                isFirst: false,
                isLast: false,
                node: Circle()
                    .fill(darkGray)
                    .frame(width: diffDotSize, height: diffDotSize)
            )

            HStack(spacing: 4) {
                Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                    .font(.system(size: 11, weight: .bold))
                // Magnitude is unsigned (helper returns "2.5 lb"); prepend
                // the sign here so e.g. losses read "↓ -4 lb" and gains
                // read "↑ +5 lb".
                Text("\(diffSignPrefix(delta))\(WeightUnit.formatDiffWeight(deltaLbs: delta, in: settings.weightUnit))")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .foregroundColor(darkGray)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Connector column: vertical line above the node, the node itself,
    /// vertical line below. Each line segment uses `maxHeight: .infinity`
    /// so it stretches to fill the row's height — that's how adjacent
    /// rows' segments meet edge-to-edge with no gap, forming a single
    /// continuous line through the timeline.
    @ViewBuilder
    private func timelineColumn<Node: View>(
        isFirst: Bool,
        isLast: Bool,
        node: Node
    ) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : darkGray)
                .frame(width: connectorWidth)
                .frame(maxHeight: .infinity)
            node
                .padding(.vertical, 8)
            Rectangle()
                .fill(isLast ? Color.clear : darkGray)
                .frame(width: connectorWidth)
                .frame(maxHeight: .infinity)
        }
        .frame(width: timelineColumnWidth)
    }

    // MARK: - Date label

    private func daysAgoLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        if let day = components.day, day > 0 {
            if day < 30 {
                return "\(day) days ago"
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return ""
    }
}

/// Drives the Update Weight sheet. `.new` creates a fresh entry; `.edit`
/// targets a specific row for in-place edit + delete. Identifiable so it
/// can drive `.sheet(item:)` — SwiftUI rebuilds the sheet when the case
/// changes, which guarantees the wheel re-initialises to the right row.
enum WeightSheetTarget: Identifiable {
    case new
    case edit(BodyWeightEntry)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let entry): return entry.id.uuidString
        }
    }
}

#Preview("Populated") {
    WeightHistoryView()
        .environmentObject(BodyWeightViewModel(mockEntries: mockBodyWeightEntries))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Single entry") {
    let vm = BodyWeightViewModel(mockEntries: [
        BodyWeightEntry(date: Date(), weightLbs: 172.0)
    ])
    return WeightHistoryView()
        .environmentObject(vm)
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}

#Preview("Empty") {
    WeightHistoryView()
        .environmentObject(BodyWeightViewModel(mockEntries: []))
        .environmentObject(GlobalSettings.shared)
        .preferredColorScheme(.dark)
}
