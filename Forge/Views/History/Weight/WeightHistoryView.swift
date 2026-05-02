import SwiftUI

struct WeightHistoryView: View {

    @EnvironmentObject var bodyWeight: BodyWeightViewModel
    @EnvironmentObject var settings: GlobalSettings

    @State private var showUpdateWeightSheet = false

    private let darkGray = GlobalSettings.shared.darkGray
    private let nodeSize: CGFloat = 14
    private let connectorWidth: CGFloat = 1
    private let connectorSegmentHeight: CGFloat = 18
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
        .safeAreaInset(edge: .bottom) {
            updateWeightButton
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.black)
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
                    entryRow(
                        entry: entry,
                        isFirst: index == 0,
                        isLast: index == bodyWeight.entries.count - 1
                    )
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
        HStack(spacing: 12) {
            Text(daysAgoLabel(for: entry.date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 90, alignment: .trailing)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : darkGray)
                    .frame(width: connectorWidth, height: connectorSegmentHeight)
                Circle()
                    .fill(settings.fgColor)
                    .frame(width: nodeSize, height: nodeSize)
                Rectangle()
                    .fill(isLast ? Color.clear : darkGray)
                    .frame(width: connectorWidth, height: connectorSegmentHeight)
            }
            .frame(width: timelineColumnWidth)

            HStack(spacing: 6) {
                Text(WeightUnit.formatLbs(entry.weightLbs))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(settings.fgColor)
                Text("(\(WeightUnit.formatKg(entry.weightLbs)))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(darkGray)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func netDiffRow(delta: Double) -> some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 90, height: 1)

            VStack(spacing: 0) {
                Rectangle().fill(darkGray).frame(width: connectorWidth, height: 12)
                Circle().fill(darkGray).frame(width: 6, height: 6).padding(.vertical, 6)
                Rectangle().fill(darkGray).frame(width: connectorWidth, height: 12)
            }
            .frame(width: timelineColumnWidth)
            .padding(.vertical, 4)

            HStack(spacing: 4) {
                Image(systemName: delta > 0 ? "arrow.up" : (delta < 0 ? "arrow.down" : "minus"))
                    .font(.system(size: 11, weight: .bold))
                Text(WeightUnit.formatDiffLbs(delta))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .foregroundColor(darkGray)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Update Weight button

    private var updateWeightButton: some View {
        Button {
            showUpdateWeightSheet = true
        } label: {
            HStack {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                Text("Update Weight")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(settings.fgColor)
            .cornerRadius(settings.cornerRadiusMedium)
        }
        .sheet(isPresented: $showUpdateWeightSheet) {
            UpdateWeightSheet()
                .environmentObject(bodyWeight)
                .environmentObject(settings)
                .environment(\.colorScheme, .dark)
        }
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

#Preview("Populated") {
    let now = Date()
    let day: TimeInterval = 86_400
    let vm = BodyWeightViewModel(mockEntries: [
        BodyWeightEntry(date: now, weightLbs: 175.5),
        BodyWeightEntry(date: now.addingTimeInterval(-3 * day), weightLbs: 174.0),
        BodyWeightEntry(date: now.addingTimeInterval(-9 * day), weightLbs: 172.5),
        BodyWeightEntry(date: now.addingTimeInterval(-21 * day), weightLbs: 170.0),
        BodyWeightEntry(date: now.addingTimeInterval(-45 * day), weightLbs: 168.0),
    ])
    return WeightHistoryView()
        .environmentObject(vm)
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
