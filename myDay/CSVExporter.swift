import Foundation
import SwiftData

struct CSVExporter {

    /// Writes a timestamped backup to the app's Documents folder (visible in Files app).
    /// Called automatically before every import so the pre-import state is always recoverable.
    @discardableResult
    static func backupTimeEntries(_ entries: [TimeEntry]) throws -> URL {
        let fileName = "myDay_backup_\(Int(Date().timeIntervalSince1970)).csv"
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(fileName)
        let csv = buildCSV(from: entries)
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func exportTimeEntries(_ entries: [TimeEntry]) throws -> URL {
        let fileName = "myDay_export_\(Int(Date().timeIntervalSince1970)).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try buildCSV(from: entries).write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private static func buildCSV(from entries: [TimeEntry]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var csv = "date,hour,activity\n"
        for entry in entries.sorted(by: { ($0.date, $0.hour) < ($1.date, $1.hour) }) {
            csv += "\(dateFormatter.string(from: entry.date)),\(entry.hour),\(entry.category.rawValue)\n"
        }
        return csv
    }
}
