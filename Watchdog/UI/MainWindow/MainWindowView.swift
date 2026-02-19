import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var captureStore: CaptureStore
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var detectionEngine: DetectionEngine

    @State private var showDeleteAllAlert = false
    @State private var selectedCapture: CaptureRecord?
    @State private var selectedTab = 0
    @State private var showPaywall = false
    @State private var searchText = ""
    @State private var filterDetectionType: DetectionMode?

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if selectedTab == 0 {
                    if captureStore.captures.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            filterBar
                            if filteredCaptures.isEmpty {
                                noResultsState
                            } else {
                                captureGrid
                            }
                        }
                    }
                } else if selectedTab == 1 {
                    livePreviewTab
                } else {
                    statsTab
                }
            }
            .searchable(text: $searchText, prompt: "Search by date or time...")
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
                        Text("Live").tag(1)
                        Text("Statistics").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
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
                    .environmentObject(subscriptionManager)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Live Preview Tab

    private var livePreviewTab: some View {
        Group {
            if detectionEngine.isMonitoring {
                VStack(spacing: 0) {
                    CameraPreviewView(session: detectionEngine.cameraManager.currentSession)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)

                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Live — \(settingsManager.detectionMode.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { detectionEngine.manualCapture() }) {
                            Label("Capture Now", systemImage: "camera.shutter.button")
                        }
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(.bar)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Camera Inactive")
                        .font(.title2)
                        .fontWeight(.medium)
                    Text("Enable monitoring to see the live camera feed.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            filterChip(label: "All", type: nil)
            ForEach(DetectionMode.allCases, id: \.self) { mode in
                filterChip(label: mode.rawValue, icon: mode.icon, type: mode)
            }
            Spacer()
            Text("\(filteredCaptures.count) capture\(filteredCaptures.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func filterChip(label: String, icon: String? = nil, type: DetectionMode?) -> some View {
        let isActive = filterDetectionType == type
        return Button {
            filterDetectionType = type
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
            .foregroundColor(isActive ? .accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("No matching captures")
                .font(.title3)
                .fontWeight(.medium)
            Text("Try adjusting your search or filter.")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Filtering & Grouping

    private var filteredCaptures: [CaptureRecord] {
        var results = captureStore.captures

        if let filter = filterDetectionType {
            results = results.filter { $0.detectionType == filter }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            results = results.filter {
                $0.formattedTimestamp.lowercased().contains(query) ||
                $0.detectionType.rawValue.lowercased().contains(query)
            }
        }

        return results
    }

    private var groupedCaptures: [(key: String, value: [CaptureRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredCaptures) { capture -> String in
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
