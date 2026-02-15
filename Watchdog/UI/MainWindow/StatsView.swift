import SwiftUI
import Charts  // Safe on macOS 13: weak-linked, all usage guarded by @available(macOS 14, *)

struct StatsView: View {
    @EnvironmentObject var captureStore: CaptureStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary Cards
                summaryCardsRow

                Divider()

                // Charts or text fallback
                if #available(macOS 14, *) {
                    ChartsStatsView(captures: captureStore.captures)
                } else {
                    textFallbackView
                }
            }
            .padding()
        }
    }

    // MARK: - Summary Cards

    private var summaryCardsRow: some View {
        HStack(spacing: 16) {
            StatCard(title: "Total Captures", value: "\(captureStore.captures.count)", icon: "photo.stack")
            StatCard(title: "Today", value: "\(todayCount)", icon: "calendar")
            StatCard(title: "Peak Hour", value: peakHourString, icon: "clock.arrow.circlepath")
            StatCard(title: "Avg / Day", value: averagePerDayString, icon: "chart.line.uptrend.xyaxis")
        }
    }

    // MARK: - Text Fallback (macOS 13)

    private var textFallbackView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Capture Statistics")
                .font(.headline)

            Group {
                statRow(label: "Total Captures", value: "\(captureStore.captures.count)")
                statRow(label: "Today's Captures", value: "\(todayCount)")
                statRow(label: "Peak Hour", value: peakHourString)
                statRow(label: "Average per Day", value: averagePerDayString)
            }

            Divider()

            Text("Detection Type Breakdown")
                .font(.headline)

            ForEach(detectionBreakdown, id: \.type) { item in
                statRow(label: item.type, value: "\(item.count) (\(item.percentage)%)")
            }

            Divider()

            Text("Hourly Distribution")
                .font(.headline)

            ForEach(hourlyDistribution.filter { $0.count > 0 }, id: \.hour) { item in
                statRow(label: formatHour(item.hour), value: "\(item.count)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    // MARK: - Computed Stats

    private var todayCount: Int {
        let calendar = Calendar.current
        return captureStore.captures.filter { calendar.isDateInToday($0.timestamp) }.count
    }

    private var peakHourString: String {
        guard !captureStore.captures.isEmpty else { return "—" }
        let calendar = Calendar.current
        let hours = captureStore.captures.map { calendar.component(.hour, from: $0.timestamp) }
        let counts = Dictionary(grouping: hours) { $0 }.mapValues(\.count)
        guard let peak = counts.max(by: { $0.value < $1.value }) else { return "—" }
        return formatHour(peak.key)
    }

    private var averagePerDayString: String {
        guard !captureStore.captures.isEmpty else { return "0" }
        let calendar = Calendar.current
        let days = Set(captureStore.captures.map { calendar.startOfDay(for: $0.timestamp) })
        let avg = Double(captureStore.captures.count) / Double(max(days.count, 1))
        return String(format: "%.1f", avg)
    }

    struct DetectionBreakdownItem {
        let type: String
        let count: Int
        let percentage: Int
    }

    var detectionBreakdown: [DetectionBreakdownItem] {
        let total = captureStore.captures.count
        guard total > 0 else { return [] }
        let grouped = Dictionary(grouping: captureStore.captures) { $0.detectionType.rawValue }
        return grouped.map { key, value in
            DetectionBreakdownItem(
                type: key,
                count: value.count,
                percentage: Int(round(Double(value.count) / Double(total) * 100))
            )
        }.sorted { $0.count > $1.count }
    }

    struct HourlyItem {
        let hour: Int
        let count: Int
    }

    var hourlyDistribution: [HourlyItem] {
        let calendar = Calendar.current
        let hours = captureStore.captures.map { calendar.component(.hour, from: $0.timestamp) }
        let counts = Dictionary(grouping: hours) { $0 }.mapValues(\.count)
        return (0..<24).map { HourlyItem(hour: $0, count: counts[$0] ?? 0) }
    }

    func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour) \(period)"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// MARK: - Charts View (macOS 14+)

@available(macOS 14, *)
struct ChartsStatsView: View {
    let captures: [CaptureRecord]

    var body: some View {
        VStack(spacing: 20) {
            capturesOverTimeChart
            HStack(spacing: 16) {
                detectionTypeChart
                hourlyChart
            }
        }
    }

    private var capturesOverTimeChart: some View {
        VStack(alignment: .leading) {
            Text("Captures Over Time")
                .font(.headline)
            chartContent(for: dailyCounts)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func chartContent(for data: [(date: Date, count: Int)]) -> some View {
        if #available(macOS 14, *) {
            Charts.Chart(data, id: \.date) { item in
                Charts.LineMark(
                    x: .value("Date", item.date),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(.blue)
                Charts.AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(.blue.opacity(0.1))
            }
            .frame(height: 200)
        }
    }

    private var detectionTypeChart: some View {
        VStack(alignment: .leading) {
            Text("Detection Types")
                .font(.headline)
            if #available(macOS 14, *) {
                Charts.Chart(typeBreakdown, id: \.type) { item in
                    Charts.BarMark(
                        x: .value("Type", item.type),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(by: .value("Type", item.type))
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading) {
            Text("Hourly Distribution")
                .font(.headline)
            if #available(macOS 14, *) {
                Charts.Chart(hourlyData, id: \.hour) { item in
                    Charts.BarMark(
                        x: .value("Hour", formatHour(item.hour)),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    // MARK: - Data

    private var dailyCounts: [(date: Date, count: Int)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: captures) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.map { (date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    private var typeBreakdown: [(type: String, count: Int)] {
        let grouped = Dictionary(grouping: captures) { $0.detectionType.rawValue }
        return grouped.map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var hourlyData: [(hour: Int, count: Int)] {
        let calendar = Calendar.current
        let hours = captures.map { calendar.component(.hour, from: $0.timestamp) }
        let counts = Dictionary(grouping: hours) { $0 }.mapValues(\.count)
        return (0..<24).map { (hour: $0, count: counts[$0] ?? 0) }
    }

    private func formatHour(_ hour: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(displayHour)\(period)"
    }
}
