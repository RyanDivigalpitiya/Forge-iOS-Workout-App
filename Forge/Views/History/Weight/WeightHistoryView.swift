import SwiftUI

struct WeightHistoryView: View {

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var sheetTarget: WeightSheetTarget?
    @State private var showHeightSheet = false

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
        ScrollView {
            LazyVStack(spacing: 0) {
                Spacer().frame(height: 20)
                ForEach(Array(bodyWeight.entries.enumerated()), id: \.element.id) { index, entry in
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
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 20)
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

    /// Wraps the parenthetical (BMI: XX.X) / (alt-unit) in a button when
    /// no height is set — tapping any row's parenthetical doubles as a
    /// shortcut to add height. When height is set the parenthetical is a
    /// plain Text (the row's tap area still opens edit-weight, so we don't
    /// want to compete with that gesture).
    @ViewBuilder
    private func parentheticalView(for entry: BodyWeightEntry) -> some View {
        let label = "(\(parentheticalLabel(for: entry)))"
        if settings.heightCm == nil {
            Button {
                showHeightSheet = true
            } label: {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(darkGray)
            }
            .buttonStyle(.plain)
        } else {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(darkGray)
        }
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
                Text(WeightUnit.formatDiffWeight(deltaLbs: delta, in: settings.weightUnit))
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
