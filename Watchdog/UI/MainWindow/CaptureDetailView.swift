import SwiftUI
import AVKit

struct CaptureDetailView: View {
    @EnvironmentObject var captureStore: CaptureStore
    @Environment(\.dismiss) private var dismiss

    let capture: CaptureRecord

    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // Video player (if available)
            if capture.hasVideo, let videoURL = capture.videoURL {
                VideoPlayerView(url: videoURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .background(Color.black)

                Divider()
            }

            // Image display
            imageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Details bar
            detailsBar
                .padding(16)
        }
        .navigationTitle(capture.shortTimestamp)
        .toolbar {
            ToolbarItemGroup {
                ShareLink(item: capture.imageURL) {
                    Label("Share Image", systemImage: "square.and.arrow.up")
                }

                if capture.hasVideo, let videoURL = capture.videoURL {
                    ShareLink(item: videoURL) {
                        Label("Share Video", systemImage: "film")
                    }
                }

                Button(role: .destructive, action: { showDeleteAlert = true }) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Capture", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                captureStore.deleteCapture(capture)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this capture?")
        }
    }

    // MARK: - Image View

    private var imageView: some View {
        Group {
            if let nsImage = NSImage(contentsOf: capture.imageURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Image not found")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Details Bar

    private var detailsBar: some View {
        HStack(spacing: 24) {
            detailItem(
                icon: "clock",
                title: "Timestamp",
                value: capture.formattedTimestamp
            )

            Divider()
                .frame(height: 32)

            detailItem(
                icon: capture.detectionType.icon,
                title: "Detection Type",
                value: capture.detectionType.rawValue
            )

            Divider()
                .frame(height: 32)

            detailItem(
                icon: "gauge.medium",
                title: "Confidence",
                value: "\(Int(capture.confidence * 100))%"
            )

            if capture.hasVideo {
                Divider()
                    .frame(height: 32)

                detailItem(
                    icon: "video.fill",
                    title: "Video",
                    value: "Recorded"
                )
            }

            Spacer()
        }
    }

    private func detailItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.callout)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Video Player (NSViewRepresentable)

struct VideoPlayerView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        let player = AVPlayer(url: url)
        playerView.player = player
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        let currentURL = (nsView.player?.currentItem?.asset as? AVURLAsset)?.url
        if currentURL != url {
            nsView.player = AVPlayer(url: url)
        }
    }
}
