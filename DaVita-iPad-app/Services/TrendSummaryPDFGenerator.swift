import Foundation
import UIKit

protocol TrendSummaryPDFGenerating {
    func makePDF(person: Person, trends: CheckInTrendsProvider.PersonTrends, windowDays: Int) throws -> URL
}

enum TrendSummaryPDFGeneratorError: Error, Equatable {
    case noData
    case writeFailed
}

/// Builds a lightweight PDF summary of mood/pain trends for sharing.
final class TrendSummaryPDFGenerator: TrendSummaryPDFGenerating {
    private let fileManager: FileManager
    private let exportDirectory: URL
    private let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72dpi

    private lazy var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private lazy var dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private lazy var fileNameTimestampFormatter: ISO8601DateFormatter = {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.exportDirectory = fileManager.temporaryDirectory.appendingPathComponent("trend_summaries", isDirectory: true)
    }

    func makePDF(person: Person, trends: CheckInTrendsProvider.PersonTrends, windowDays: Int) throws -> URL {
        guard trends.totalRecordsInWindow > 0 else {
            throw TrendSummaryPDFGeneratorError.noData
        }

        try prepareExportDirectory()
        let filename = "trend_summary_\(fileNameTimestampFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")).pdf"
        let url = exportDirectory.appendingPathComponent(filename)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                drawWatermark(text: "Private – Patient Summary", in: ctx, pageRect: pageRect)
                var y: CGFloat = 36

                y = drawHeader(person: person, trends: trends, windowDays: windowDays, at: y)
                y = drawPainSection(trends: trends, at: y)
                y = drawDistributionSection(title: "Mood distribution", counts: trends.moodDistribution, at: y, ctx: ctx)
                y = drawDistributionSection(title: "Energy distribution", counts: trends.energyDistribution, at: y, ctx: ctx)
                y = drawSymptomsSection(trends: trends, at: y, ctx: ctx)
            }
            try applyFileProtection(at: url)
            return url
        } catch {
            throw TrendSummaryPDFGeneratorError.writeFailed
        }
    }
}

private extension TrendSummaryPDFGenerator {
    func prepareExportDirectory() throws {
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try applyFileProtection(at: exportDirectory)
        cleanupOldExports()
    }

    func applyFileProtection(at url: URL) throws {
        try fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                      ofItemAtPath: url.path)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true

        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    func cleanupOldExports(maxAge: TimeInterval = 24 * 60 * 60) {
        guard let contents = try? fileManager.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }

        let cutoff = Date().addingTimeInterval(-maxAge)
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? Date.distantPast
            if modified < cutoff {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    func drawHeader(person: Person, trends: CheckInTrendsProvider.PersonTrends, windowDays: Int, at yStart: CGFloat) -> CGFloat {
        var y = yStart

        draw(text: "Monthly Mood & Pain Summary", at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 20))
        y += 26

        let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (person.name ?? "—") : "—"
        draw(text: "Person: \(name)", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
        y += 16

        draw(text: "Window: last \(windowDays) days (\(dateFormatter.string(from: trends.windowStart)) – \(dateFormatter.string(from: trends.windowEnd)))",
             at: CGPoint(x: 36, y: y),
             font: .systemFont(ofSize: 12),
             color: .darkGray)
        y += 16

        draw(text: "Records in window: \(trends.totalRecordsInWindow)", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
        y += 20

        drawLine(from: CGPoint(x: 36, y: y), to: CGPoint(x: pageRect.width - 36, y: y))
        return y + 14
    }

    func drawPainSection(trends: CheckInTrendsProvider.PersonTrends, at yStart: CGFloat) -> CGFloat {
        var y = yStart
        draw(text: "Pain trend", at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 16))
        y += 18

        let values = trends.painSeries.map { $0.value }
        let latest = values.last ?? 0
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0

        let summary = "Latest: \(Int(latest.rounded())) / 10   Avg: \(average.rounded(toPlaces: 1))   Min: \(Int(minValue))   Max: \(Int(maxValue))"
        draw(text: summary, at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12))
        y += 16

        drawLine(from: CGPoint(x: 36, y: y), to: CGPoint(x: pageRect.width - 36, y: y))
        return y + 18
    }

    func drawDistributionSection<T: CaseIterable & Hashable>(title: String,
                                                             counts: [T: Int],
                                                             at yStart: CGFloat,
                                                             ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = yStart
        draw(text: title, at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 16))
        y += 18

        let total = counts.values.reduce(0, +)
        for bucket in T.allCases {
            let count = counts[bucket, default: 0]
            let line = "\(bucketTitle(bucket)): \(count)\(total > 0 ? " (\(percentText(count, total: total)))" : "")"
            draw(text: line, at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 12))
            y += 16
            if y > pageRect.height - 72 {
                ctx.beginPage()
                drawWatermark(text: "Private – Patient Summary", in: ctx, pageRect: pageRect)
                y = 36
            }
        }

        drawLine(from: CGPoint(x: 36, y: y), to: CGPoint(x: pageRect.width - 36, y: y))
        return y + 18
    }

    func drawSymptomsSection(trends: CheckInTrendsProvider.PersonTrends, at yStart: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = yStart
        draw(text: "Top symptom mentions", at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 16))
        y += 18

        if trends.topSymptomCategories.isEmpty {
            draw(text: "No symptom text captured in this window.", at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
            return y + 18
        }

        for (category, count) in trends.topSymptomCategories.prefix(5) {
            let label = category.replacingOccurrences(of: "_", with: " ").capitalized
            let line = "\(label): \(count)"
            draw(text: line, at: CGPoint(x: 42, y: y), font: .systemFont(ofSize: 12))
            y += 16
            if y > pageRect.height - 72 {
                ctx.beginPage()
                drawWatermark(text: "Private – Patient Summary", in: ctx, pageRect: pageRect)
                y = 36
            }
        }

        drawLine(from: CGPoint(x: 36, y: y), to: CGPoint(x: pageRect.width - 36, y: y))
        return y + 18
    }

    func draw(text: String, at point: CGPoint, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    func drawLine(from: CGPoint, to: CGPoint) {
        let p = UIBezierPath()
        p.move(to: from)
        p.addLine(to: to)
        UIColor.lightGray.setStroke()
        p.lineWidth = 1
        p.stroke()
    }

    func drawWatermark(text: String, in ctx: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: UIColor.lightGray.withAlphaComponent(0.14)
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        ctx.cgContext.saveGState()
        ctx.cgContext.translateBy(x: pageRect.midX, y: pageRect.midY)
        ctx.cgContext.rotate(by: -.pi / 6)
        (text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        ctx.cgContext.restoreGState()
    }

    func bucketTitle<T>(_ bucket: T) -> String {
        if let energy = bucket as? EnergyBucket { return energy.displayText }
        if let mood = bucket as? MoodBucket { return mood.displayText }
        return String(describing: bucket)
    }

    func percentText(_ count: Int, total: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Int((Double(count) / Double(total) * 100).rounded())
        return "\(pct)%"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

