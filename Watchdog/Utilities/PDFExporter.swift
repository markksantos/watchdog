import Foundation
import AppKit
import PDFKit

struct PDFExporter {
    static func exportPDF(captures: [CaptureRecord]) {
        let panel = NSSavePanel()
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "Watchdog-Report-\(dateStr).pdf"
        panel.allowedContentTypes = [.pdf]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if SubscriptionManager.shared.hasAccess(to: .advancedPDFReports) {
            generateAdvancedPDF(captures: captures, url: url)
        } else {
            generatePDF(captures: captures, url: url)
        }
    }

    private static func generatePDF(captures: [CaptureRecord], url: URL) {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let columns = 2
        let rows = 3
        let imagesPerPage = columns * rows
        let cellWidth: CGFloat = (pageWidth - margin * 3) / CGFloat(columns)
        let imageHeight: CGFloat = 180
        let captionHeight: CGFloat = 40
        let cellHeight = imageHeight + captionHeight

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            print("[Watchdog] Failed to create PDF context")
            return
        }

        // MARK: - Title Page

        context.beginPDFPage(nil)

        let titleFont = NSFont.boldSystemFont(ofSize: 28)
        let subtitleFont = NSFont.systemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 12)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: NSColor.darkGray
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: NSColor.black
        ]

        let title = "Watchdog Security Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (pageWidth - titleSize.width) / 2
        title.draw(at: NSPoint(x: titleX, y: pageHeight - 200), withAttributes: titleAttributes)

        if let earliest = captures.last?.formattedTimestamp,
           let latest = captures.first?.formattedTimestamp {
            let dateRange = "Date Range: \(earliest) - \(latest)"
            let rangeSize = dateRange.size(withAttributes: subtitleAttributes)
            dateRange.draw(at: NSPoint(x: (pageWidth - rangeSize.width) / 2, y: pageHeight - 240), withAttributes: subtitleAttributes)
        }

        let totalLine = "Total Captures: \(captures.count)"
        let totalSize = totalLine.size(withAttributes: bodyAttributes)
        totalLine.draw(at: NSPoint(x: (pageWidth - totalSize.width) / 2, y: pageHeight - 280), withAttributes: bodyAttributes)

        let generatedDate = "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))"
        let genSize = generatedDate.size(withAttributes: bodyAttributes)
        generatedDate.draw(at: NSPoint(x: (pageWidth - genSize.width) / 2, y: pageHeight - 310), withAttributes: bodyAttributes)

        context.endPDFPage()

        // MARK: - Content Pages

        let totalContentPages = Int(ceil(Double(captures.count) / Double(imagesPerPage)))
        let pageNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.darkGray
        ]

        for pageIndex in 0..<totalContentPages {
            context.beginPDFPage(nil)

            let startIndex = pageIndex * imagesPerPage
            let endIndex = min(startIndex + imagesPerPage, captures.count)

            for i in startIndex..<endIndex {
                let capture = captures[i]
                let positionInPage = i - startIndex
                let col = positionInPage % columns
                let row = positionInPage / columns

                let x = margin + CGFloat(col) * (cellWidth + margin)
                // Top-down layout in PDF coordinates (origin at bottom-left)
                let y = pageHeight - margin - CGFloat(row + 1) * cellHeight

                // Draw image
                if let nsImage = NSImage(contentsOfFile: capture.imagePath) {
                    let imageRect = aspectFitRect(
                        imageSize: nsImage.size,
                        into: CGRect(x: x, y: y + captionHeight, width: cellWidth, height: imageHeight)
                    )
                    nsImage.draw(in: imageRect)
                }

                // Draw caption
                let caption = "\(capture.shortTimestamp) | \(capture.detectionType.rawValue) | \(String(format: "%.0f%%", capture.confidence * 100))"
                caption.draw(at: NSPoint(x: x, y: y + 10), withAttributes: captionAttributes)
            }

            // Page number
            let pageNum = "Page \(pageIndex + 2) of \(totalContentPages + 1)"
            let numSize = pageNum.size(withAttributes: pageNumberAttributes)
            pageNum.draw(at: NSPoint(x: (pageWidth - numSize.width) / 2, y: 20), withAttributes: pageNumberAttributes)

            context.endPDFPage()
        }

        context.closePDF()
        print("[Watchdog] PDF exported to \(url.path)")
    }

    // MARK: - Advanced PDF (Pro)

    private static func generateAdvancedPDF(captures: [CaptureRecord], url: URL) {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            print("[Watchdog] Failed to create PDF context")
            return
        }

        let titleFont = NSFont.boldSystemFont(ofSize: 28)
        let subtitleFont = NSFont.systemFont(ofSize: 14)
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let headingFont = NSFont.boldSystemFont(ofSize: 16)
        let smallFont = NSFont.systemFont(ofSize: 11)

        let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: NSColor.black]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: subtitleFont, .foregroundColor: NSColor.darkGray]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.black]
        let headingAttributes: [NSAttributedString.Key: Any] = [.font: headingFont, .foregroundColor: NSColor.black]
        let smallAttributes: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: NSColor.darkGray]

        // MARK: Title Page

        context.beginPDFPage(nil)

        let title = "Watchdog Security Report"
        let titleSize = title.size(withAttributes: titleAttributes)
        title.draw(at: NSPoint(x: (pageWidth - titleSize.width) / 2, y: pageHeight - 200), withAttributes: titleAttributes)

        let proLabel = "Pro Analytics Report"
        let proSize = proLabel.size(withAttributes: subtitleAttributes)
        proLabel.draw(at: NSPoint(x: (pageWidth - proSize.width) / 2, y: pageHeight - 230), withAttributes: subtitleAttributes)

        if let earliest = captures.last?.formattedTimestamp,
           let latest = captures.first?.formattedTimestamp {
            let dateRange = "Date Range: \(earliest) - \(latest)"
            let rangeSize = dateRange.size(withAttributes: subtitleAttributes)
            dateRange.draw(at: NSPoint(x: (pageWidth - rangeSize.width) / 2, y: pageHeight - 260), withAttributes: subtitleAttributes)
        }

        let totalLine = "Total Captures: \(captures.count)"
        let totalSize = totalLine.size(withAttributes: bodyAttributes)
        totalLine.draw(at: NSPoint(x: (pageWidth - totalSize.width) / 2, y: pageHeight - 300), withAttributes: bodyAttributes)

        let generatedDate = "Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))"
        let genSize = generatedDate.size(withAttributes: bodyAttributes)
        generatedDate.draw(at: NSPoint(x: (pageWidth - genSize.width) / 2, y: pageHeight - 330), withAttributes: bodyAttributes)

        context.endPDFPage()

        // MARK: Analytics Page

        context.beginPDFPage(nil)

        var yPos = pageHeight - margin - 30

        // Section: Capture Frequency
        "Capture Frequency (Per Day)".draw(at: NSPoint(x: margin, y: yPos), withAttributes: headingAttributes)
        yPos -= 30

        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: captures) { record -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: record.timestamp)
        }
        let sortedDays = groupedByDay.sorted { lhs, rhs in
            guard let ld = lhs.value.first?.timestamp, let rd = rhs.value.first?.timestamp else { return false }
            return ld > rd
        }

        for (day, records) in sortedDays.prefix(15) {
            let line = "\(day): \(records.count) capture\(records.count == 1 ? "" : "s")"
            line.draw(at: NSPoint(x: margin + 20, y: yPos), withAttributes: bodyAttributes)
            yPos -= 18
            if yPos < margin + 100 { break }
        }

        yPos -= 20

        // Section: Peak Hours
        "Peak Hours Analysis".draw(at: NSPoint(x: margin, y: yPos), withAttributes: headingAttributes)
        yPos -= 30

        let hourCounts = Dictionary(grouping: captures) { calendar.component(.hour, from: $0.timestamp) }
            .mapValues(\.count)
        let sortedHours = hourCounts.sorted { $0.value > $1.value }

        for (hour, count) in sortedHours.prefix(8) {
            let period = hour >= 12 ? "PM" : "AM"
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            let line = "\(displayHour) \(period): \(count) capture\(count == 1 ? "" : "s")"
            line.draw(at: NSPoint(x: margin + 20, y: yPos), withAttributes: bodyAttributes)
            yPos -= 18
            if yPos < margin + 100 { break }
        }

        yPos -= 20

        // Section: Detection Type Breakdown
        "Detection Type Breakdown".draw(at: NSPoint(x: margin, y: yPos), withAttributes: headingAttributes)
        yPos -= 30

        let typeGroups = Dictionary(grouping: captures) { $0.detectionType.rawValue }
        let total = captures.count

        for (type, records) in typeGroups.sorted(by: { $0.value.count > $1.value.count }) {
            let pct = total > 0 ? Int(round(Double(records.count) / Double(total) * 100)) : 0
            let line = "\(type): \(records.count) (\(pct)%)"
            line.draw(at: NSPoint(x: margin + 20, y: yPos), withAttributes: bodyAttributes)
            yPos -= 18
        }

        // Page number
        let pageNum = "Page 2"
        let numSize = pageNum.size(withAttributes: smallAttributes)
        pageNum.draw(at: NSPoint(x: (pageWidth - numSize.width) / 2, y: 20), withAttributes: smallAttributes)

        context.endPDFPage()

        // MARK: Image Pages (same as standard)

        let columns = 2
        let rows = 3
        let imagesPerPage = columns * rows
        let cellWidth: CGFloat = (pageWidth - margin * 3) / CGFloat(columns)
        let imageHeight: CGFloat = 180
        let captionHeight: CGFloat = 40
        let cellHeight = imageHeight + captionHeight

        let totalContentPages = Int(ceil(Double(captures.count) / Double(imagesPerPage)))
        let pageNumberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.gray
        ]
        let captionAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.darkGray
        ]

        for pageIndex in 0..<totalContentPages {
            context.beginPDFPage(nil)

            let startIndex = pageIndex * imagesPerPage
            let endIndex = min(startIndex + imagesPerPage, captures.count)

            for i in startIndex..<endIndex {
                let capture = captures[i]
                let positionInPage = i - startIndex
                let col = positionInPage % columns
                let row = positionInPage / columns

                let x = margin + CGFloat(col) * (cellWidth + margin)
                let y = pageHeight - margin - CGFloat(row + 1) * cellHeight

                if let nsImage = NSImage(contentsOfFile: capture.imagePath) {
                    let imageRect = aspectFitRect(
                        imageSize: nsImage.size,
                        into: CGRect(x: x, y: y + captionHeight, width: cellWidth, height: imageHeight)
                    )
                    nsImage.draw(in: imageRect)
                }

                let caption = "\(capture.shortTimestamp) | \(capture.detectionType.rawValue) | \(String(format: "%.0f%%", capture.confidence * 100))"
                caption.draw(at: NSPoint(x: x, y: y + 10), withAttributes: captionAttributes)
            }

            // +2 accounts for title page and analytics page
            let pageNumStr = "Page \(pageIndex + 3) of \(totalContentPages + 2)"
            let pnSize = pageNumStr.size(withAttributes: pageNumberAttributes)
            pageNumStr.draw(at: NSPoint(x: (pageWidth - pnSize.width) / 2, y: 20), withAttributes: pageNumberAttributes)

            context.endPDFPage()
        }

        context.closePDF()
        print("[Watchdog] Advanced PDF exported to \(url.path)")
    }

    private static func aspectFitRect(imageSize: CGSize, into rect: CGRect) -> CGRect {
        let widthRatio = rect.width / imageSize.width
        let heightRatio = rect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        return CGRect(
            x: rect.midX - scaledWidth / 2,
            y: rect.midY - scaledHeight / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }
}
