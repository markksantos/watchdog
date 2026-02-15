import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var captureStore: CaptureStore
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager

    @State private var showDeleteAllAlert = false
    @State private var selectedCapture: CaptureRecord?
    @State private var selectedTab = 0
    @State private var showPaywall = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if selectedTab == 0 {
                    if captureStore.captures.isEmpty {
                        emptyState
                    } else {
                        captureGrid
                    }
                } else {
                    statsTab
                }
            }
            .navigationTitle("Watchdog")
            .navigationDestination(for: CaptureRecord.ID.self) { captureID in
                if let capture = captureStore.captures.first(where: { $0.id == captureID }) {
                    CaptureDetailView(capture: capture)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    Picker("View", selection: $selectedTab) {
                        Text("Captures").tag(0)
                        Text("Statistics").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }

                ToolbarItemGroup {
                    statsLabel

                    Spacer()

                    Button(action: exportPDF) {
                        Label("Export PDF", systemImage: "doc.richtext")
                    }
                    .disabled(captureStore.captures.isEmpty)

                    Button(role: .destructive, action: { showDeleteAllAlert = true }) {
                        Label("Delete All", systemImage: "trash")
                    }
                    .disabled(captureStore.captures.isEmpty)
                }
            }
            .alert("Delete All Captures", isPresented: $showDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    captureStore.deleteAllCaptures()
                }
            } message: {
                Text("Are you sure you want to delete all captures? This cannot be undone.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Stats Tab

    private var statsTab: some View {
        Group {
            if subscriptionManager.hasAccess(to: .statsDashboard) {
                StatsView()
            } else {
                statsUpgradeTeaser
            }
        }
    }

    private var statsUpgradeTeaser: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Stats Dashboard")
                .font(.title2)
                .fontWeight(.medium)
            Text("View capture trends, heatmaps, and weekly summaries with Watchdog Pro.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button(action: { showPaywall = true }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Upgrade to Pro")
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Stats Label

    private var statsLabel: some View {
        let todayCount = captureStore.captures.filter { Calendar.current.isDateInToday($0.timestamp) }.count
        return Text("\(todayCount) capture\(todayCount == 1 ? "" : "s") today")
            .font(.subheadline)
            .foregroundColor(.secondary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No captures yet")
                .font(.title2)
                .fontWeight(.medium)
            Text("Enable monitoring to start capturing.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Capture Grid

    private var captureGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedCaptures, id: \.key) { day, captures in
                    Section {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(captures) { capture in
                                NavigationLink(value: capture.id) {
                                    CaptureCell(capture: capture)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        captureStore.deleteCapture(capture)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(day)
                            .font(.headline)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.bar)
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Grouping

    private var groupedCaptures: [(key: String, value: [CaptureRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: captureStore.captures) { capture -> String in
            if calendar.isDateInToday(capture.timestamp) {
                return "Today"
            } else if calendar.isDateInYesterday(capture.timestamp) {
                return "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: capture.timestamp)
            }
        }

        return grouped.sorted { lhs, rhs in
            let lhsDate = lhs.value.first?.timestamp ?? Date.distantPast
            let rhsDate = rhs.value.first?.timestamp ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

    // MARK: - Export PDF

    private func exportPDF() {
        PDFExporter.exportPDF(captures: captureStore.captures)
    }
}

// MARK: - Capture Cell

struct CaptureCell: View {
    let capture: CaptureRecord

    var body: some View {
        ZStack(alignment: .bottom) {
            if let nsImage = NSImage(contentsOf: capture.imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 160, minHeight: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(minWidth: 160, minHeight: 120)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }

            // Video badge overlay
            if capture.hasVideo {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(6)
                    }
                    Spacer()
                }
            }

            // Overlay info bar
            HStack(spacing: 4) {
                Text(capture.shortTimestamp)
                    .font(.caption2)
                Spacer()
                Image(systemName: capture.detectionType.icon)
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .foregroundColor(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
    }
}
