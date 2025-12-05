import Foundation
import CoreData
import UIKit

/// Local-only exports (no network).
protocol ExportServicing {
    func exportCheckInsCSV(filter: CheckInHistoryFilter) throws -> URL
    func exportCheckInsPDF(filter: CheckInHistoryFilter) throws -> URL
}

final class ExportService: ExportServicing {
    enum ExportError: Error {
        case noRecords
        case writeFailed
    }

    private let context: NSManagedObjectContext
    private lazy var isoFormatter: ISO8601DateFormatter = {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso
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

    /// Directory for exports. Kept in a dedicated temp subdirectory.
    private lazy var exportDirectory: URL = {
        FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
    }()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - CSV

    /// Exports check-in records to CSV and returns a file URL.
    ///
    /// - Note: Intended for admin-only local export + share sheet.
    func exportCheckInsCSV(filter: CheckInHistoryFilter = CheckInHistoryFilter()) throws -> URL {
        let repo = CheckInRepository(context: context)
        let records = try repo.fetchVisits(filter: filter)
        guard !records.isEmpty else { throw ExportError.noRecords }

        let url = try makeExportURL(ext: "csv")
        return try writeCSV(records: records, to: url)
    }

    // MARK: - PDF

    /// Exports a simple PDF report of check-in records and returns a file URL.
    func exportCheckInsPDF(filter: CheckInHistoryFilter = CheckInHistoryFilter()) throws -> URL {
        let repo = CheckInRepository(context: context)
        let records = try repo.fetchVisits(filter: filter)
        guard !records.isEmpty else { throw ExportError.noRecords }

        let url = try makeExportURL(ext: "pdf")

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @ 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        do {
            try renderer.writePDF(to: url, withActions: { ctx in
                var y: CGFloat = 36
                let watermark = "DaVita – Local Export Only"

                func newPage() {
                    ctx.beginPage()
                    drawWatermark(text: watermark, in: ctx, pageRect: pageRect)
                    y = 36
                }

                newPage()

                let title = "Check-in Export"
                draw(text: title, at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 18))
                y += 26

                draw(text: "Records: \(records.count)", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
                y += 18

                draw(text: "Generated: \(dateTimeFormatter.string(from: Date()))", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
                y += 24

                // Header row
                let header = "Date".padding(toLength: 22, withPad: " ", startingAt: 0) + "  " +
                    "Person".padding(toLength: 20, withPad: " ", startingAt: 0) + "  " +
                    "Pain".padding(toLength: 4, withPad: " ", startingAt: 0) + "  " +
                    "Energy".padding(toLength: 6, withPad: " ", startingAt: 0) + "  " +
                    "Mood".padding(toLength: 7, withPad: " ", startingAt: 0)

                draw(text: header, at: CGPoint(x: 36, y: y), font: .monospacedSystemFont(ofSize: 11, weight: .semibold))
                y += 16

                drawLine(from: CGPoint(x: 36, y: y), to: CGPoint(x: pageRect.width - 36, y: y))
                y += 10

                for r in records {
                    if y > pageRect.height - 54 {
                        newPage()
                    }

                    let dateText = r.createdAt.map { dateTimeFormatter.string(from: $0) } ?? "—"
                    let personText = r.person?.name ?? "—"
                    let painText = String(r.painLevel)

                    let energy = EnergyBucket.from(legacyText: r.energyLevel)?.displayText ?? (r.energyLevel ?? "—")
                    let mood = MoodBucket.from(legacyText: r.mood)?.displayText ?? (r.mood ?? "—")

                    let line = dateText.prefix(22).padding(toLength: 22, withPad: " ", startingAt: 0) + "  " +
                        personText.prefix(20).padding(toLength: 20, withPad: " ", startingAt: 0) + "  " +
                        painText.padding(toLength: 4, withPad: " ", startingAt: 0) + "  " +
                        energy.prefix(6).padding(toLength: 6, withPad: " ", startingAt: 0) + "  " +
                        mood.prefix(7).padding(toLength: 7, withPad: " ", startingAt: 0)

                    draw(text: line, at: CGPoint(x: 36, y: y), font: .monospacedSystemFont(ofSize: 10, weight: .regular))
                    y += 14
                }
            })
            return url
        } catch {
            throw ExportError.writeFailed
        }
    }

    // MARK: - Private

    private func makeExportURL(ext: String) throws -> URL {
        try prepareExportDirectory()

        let ts = fileNameTimestampFormatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "checkins_\(ts).\(ext)"
        return exportDirectory.appendingPathComponent(filename)
    }

    private func csv(_ value: String) -> String {
        // RFC4180-ish escaping
        let needsQuotes = value.contains(",") || value.contains("\n") || value.contains("\r") || value.contains("\"")
        if !needsQuotes { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func draw(text: String, at point: CGPoint, font: UIFont, color: UIColor = .black) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private func drawLine(from: CGPoint, to: CGPoint) {
        let p = UIBezierPath()
        p.move(to: from)
        p.addLine(to: to)
        UIColor.lightGray.setStroke()
        p.lineWidth = 1
        p.stroke()
    }

    private func drawWatermark(text: String, in ctx: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .semibold),
            .foregroundColor: UIColor.lightGray.withAlphaComponent(0.15)
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let center = CGPoint(x: pageRect.midX - size.width / 2, y: pageRect.midY - size.height / 2)
        ctx.cgContext.saveGState()
        ctx.cgContext.translateBy(x: pageRect.midX, y: pageRect.midY)
        ctx.cgContext.rotate(by: -.pi / 6) // slight angle
        (text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        ctx.cgContext.restoreGState()
    }

    private func prepareExportDirectory() throws {
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        cleanupOldExports()
    }

    /// Best-effort cleanup of temp export files older than 24 hours.
    private func cleanupOldExports(maxAge: TimeInterval = 24 * 60 * 60) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: exportDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }

        let cutoff = Date().addingTimeInterval(-maxAge)
        for url in contents {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? Date.distantPast
            if modified < cutoff {
                try? fm.removeItem(at: url)
            }
        }
    }

    private func writeCSV(records: [CheckInRecord], to url: URL) throws -> URL {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            throw ExportError.writeFailed
        }
        defer { try? handle.close() }

        let header = [
            "person_name",
            "person_id",
            "record_id",
            "created_at",
            "pain",
            "energy_bucket",
            "mood_bucket",
            "energy_text",
            "mood_text",
            "symptoms",
            "concerns",
            "team_note"
        ].joined(separator: ",") + "\r\n"

        guard let headerData = header.data(using: .utf8) else { throw ExportError.writeFailed }
        try handle.write(contentsOf: headerData)

        for r in records {
            autoreleasepool {
                let personName = r.person?.name ?? ""
                let personId = r.person?.id?.uuidString ?? ""
                let recordId = r.id?.uuidString ?? ""
                let createdAt = r.createdAt.map { isoFormatter.string(from: $0) } ?? ""

                let pain = String(r.painLevel)
                let energyBucket = (r.value(forKey: "energyBucket") as? NSNumber)?.stringValue ?? ""
                let moodBucket = (r.value(forKey: "moodBucket") as? NSNumber)?.stringValue ?? ""

                let energyText = r.energyLevel ?? ""
                let moodText = r.mood ?? ""
                let symptoms = r.symptoms ?? ""
                let concerns = r.concerns ?? ""
                let teamNote = r.teamNote ?? ""

                let row = [
                    csv(personName),
                    csv(personId),
                    csv(recordId),
                    csv(createdAt),
                    csv(pain),
                    csv(energyBucket),
                    csv(moodBucket),
                    csv(energyText),
                    csv(moodText),
                    csv(symptoms),
                    csv(concerns),
                    csv(teamNote)
                ].joined(separator: ",") + "\r\n"

                if let data = row.data(using: .utf8) {
                    try? handle.write(contentsOf: data)
                }
            }
        }

        return url
    }
}
