import Foundation
import CoreData
import UIKit

/// Local-only exports (no network).
final class ExportService {
    enum ExportError: Error {
        case noRecords
        case writeFailed
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
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

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var lines: [String] = []
        lines.reserveCapacity(records.count + 1)

        lines.append([
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
        ].joined(separator: ","))

        for r in records {
            let personName = r.person?.name ?? ""
            let personId = r.person?.id?.uuidString ?? ""
            let recordId = r.id?.uuidString ?? ""
            let createdAt = r.createdAt.map { iso.string(from: $0) } ?? ""

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
            ].joined(separator: ",")

            lines.append(row)
        }

        let content = lines.joined(separator: "\r\n") + "\r\n"
        let data = content.data(using: .utf8) ?? Data()

        let url = try makeExportURL(ext: "csv")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw ExportError.writeFailed
        }
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

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        do {
            try renderer.writePDF(to: url, withActions: { ctx in
                var y: CGFloat = 36

                func newPage() {
                    ctx.beginPage()
                    y = 36
                }

                newPage()

                let title = "Check-in Export"
                draw(text: title, at: CGPoint(x: 36, y: y), font: .boldSystemFont(ofSize: 18))
                y += 26

                draw(text: "Records: \(records.count)", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
                y += 18

                draw(text: "Generated: \(df.string(from: Date()))", at: CGPoint(x: 36, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
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

                    let dateText = r.createdAt.map { df.string(from: $0) } ?? "—"
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
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "checkins_\(ts).\(ext)"
        return dir.appendingPathComponent(filename)
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
}
